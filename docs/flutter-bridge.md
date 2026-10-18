# Flutter 前端与 Rust 核心桥接方案

## 决策：进程内 FFI（当前为手写 C ABI）

iOS 禁止应用派生子进程，因此"Rust 侧车进程 + JSON-RPC"在移动端不可行；
唯一全平台可行的形态是**进程内 FFI**。当前阶段用最小 C ABI + `dart:ffi`
直连，便于逐条审计、不引入代码生成与重复异步栈；API 面稳定后再评估
[flutter_rust_bridge](https://pub.dev/packages/flutter_rust_bridge) 生成类型绑定。

## 布局

```
apps/xeterm/            # Flutter 应用（flutter create 生成，名字见下）
  lib/                  # Dart 侧；api/ 由 flutter_rust_bridge 生成
  native/               # 该应用专属的 bridge crate（frb_codegen 的输入）
crates/xenterm/         # 服务核心（已存在，无 Flutter 依赖）
```

桥接 crate `apps/xenterm/native/` 只做"翻译"：把 `crates/xenterm` 的
模型（Session、TermBuffer、ResourceSample、Transfer…）映射为 FRB 友好的
DTO 与 Stream；核心 crate 保持零前端依赖，`arch_guards` 守卫继续生效。

## API 面（按 docs/features.md 的模块顺序逐步暴露）

优先级从高到低：
1. 会话 CRUD + 列表/分组（ConfigStore）
2. 连接生命周期（session_runtime/ConnectCtx）+ 终端流（TermBuffer 快照）
3. SFTP 列表/传输 + 进度流
4. 资源采样流（本机 + 远端）
5. 触发器/快捷命令/隧道/壁纸等长尾

## UI 复刻约束（docs/termius/design-tokens.md）

- 组件库优先 [shadcn_flutter](https://pub.dev/packages/shadcn_flutter)，
  其主题系统直接灌入逆向所得的 Termius 令牌（色板/圆角/字号）。
- 布局、交互、动画按 design-tokens.md 的 MUI 刻度实现（150–375ms、
  cubic-bezier(0,0,0.2,1)）。
- 截图比对验证阶段：**无视觉能力的模型须暂停并请用户接管**。

## 已落地（第一步，C ABI 直连）

- `apps/xenterm/native/` 暴露三个 C 符号：`xenterm_core_version`、
  `xenterm_sessions_json`、`xenterm_string_free`；字符串由调用方通过
  `xenterm_string_free` 释放。会话投影只含列表字段（id/label/address/port/
  username/group/kind/last_used），密码与私钥不出核心。
- Dart 侧 `apps/xenterm/lib/bridge/native_bridge.dart` 用 `dart:ffi` 加载
  `xenterm_bridge.dll`（macOS/Linux 对应 `.dylib`/`.so`，可用
  `XENTERM_BRIDGE_PATH` 覆盖）。`ConfigStore::load` 会触达系统钥匙串与
  SQLite，因此读取放在 `Isolate.run`，UI 线程不阻塞。
- 主机屏通过 `loadHostsFromCore()` 读取真实会话：空列表显示空状态，加载失败
  显示错误与重试；widget 测试注入 `kSampleHosts` 作为夹具，不伪装生产数据。
- 会话 CRUD 已打通：New host 调用 `xenterm_session_upsert` 在核心创建会话，
  抽屉字段（Address / Label / Parent Group / Port / Username）经头部 ✓ 保存，
  ⋯ → Remove host 通过 `xenterm_session_delete` 删除；全部为真实 `sessions.db`
  写入，已实测创建→重命名→删除。
- shadcn 的文字输入默认没有 Ctrl+A/C/V 快捷键，应用根部已包
  `DefaultTextEditingShortcuts`。
- 构建与放置：`apps/xenterm/tool/build_native.ps1`（Windows）或
  `build_native.sh`，产物需与 Flutter 可执行文件同目录。
- 终端流已打通（第二步）：`crates/xenterm/src/frontend.rs` 是唯一公开的
  会话门面——按会话 id 启动真实传输（SSH/Serial/Telnet/Local），泵线程把
  `SessionEvent::Output` 喂给 rio-vt，并用版本计数器让前端廉价轮询。
  C ABI 新增 `xenterm_session_start/version/snapshot/input/resize/close/
  answer_prompt`；快照为紧凑 JSON（`rows[].runs[{t,c,s}]`、cursor、模式位、
  status、closed、prompt）。输入按 xterm 约定编码后以原始字节送入 PTY；
  缩放同时调整 rio-vt 屏幕与传输端；主机密钥/账号/MFA 提示通过 responder
  回传，不经过 UI 线程阻塞。
- Dart 侧 `TerminalView` 每 50ms 比较版本号、仅在变化时取快照，用
  Consolas/Menlo 等真实等宽字体（`monospace` 在 Windows 会回退到 Segoe UI）
  按 run 绘制并叠加块状光标；工具面板提供可见缓冲搜索（高亮+计数）、
  复制、清屏（Ctrl+L）、字号与重连，全部作用于真实会话。
- 侧栏不再是空壳（第三步，全部走核心真实数据）：
  - Snippets：`xenterm_quick_commands_json/upsert/delete`，搜索、新建/编辑/
    删除抽屉；卡片点击经 `TerminalCommandBus` 定向发送到活动 PTY。
  - Known Hosts：core 公开 `known_hosts::entries/forget`，bridge 提供
    `xenterm_known_hosts_json/delete`，宿主键指纹由 russh 解析。
  - Port Forwarding：`xenterm_forwards_json/upsert/delete`，复用核心的
    `core::tunnel::validate`，规则随宿主连接生效。
  - Keychain：`xenterm_keys_json` 只投影会话引用的密钥元数据（算法/指纹/
    状态），主机抽屉新增私钥路径并自动切到 `AuthMethod::Key`。
  - Logs：`session_logs` 开关（默认关）开启后，泵线程把转录写成 JSONL
    （meta/output/end+关闭原因）；`xenterm_logs_json/read/delete` 提供列表、
    查看（读取时剥离 ANSI）与删除。
  - Settings：`xenterm_settings_json/set` 持久化光标样式、行距、内边距、
    粗体、日志开关与 SFTP 下载目录；终端渲染实时读取。
- SFTP（第四步）：`xenterm_sftp_start/version/snapshot/list/refresh/
  download/upload/mkdir/delete/close/answer_prompt`；`SftpView` 轮询快照，
  真实目录导航、选择、上传、下载（冲突时保留两份）、新建目录与删除，传输
  进度显示在底部。连接失败会停止 loading 并给出错误与 Retry。SFTP 自己的
  主机密钥/密码/MFA 提示同样进入快照并通过 `answer_prompt` 回答（与终端
  共用同一个提示横幅）。
- 测试：`cargo test -p xenterm-bridge`（quick commands/known hosts/forwards/
  keys/logs/sftp 失败路径）、`flutter test`（终端/侧栏/SFTP/设置/logs/提示
  横幅的 widget 契约）。SFTP 成功路径用 `apps/xenterm/tool/sftp_test_server.py`
  （paramiko 手工验收工具）实测：主机密钥提示 → 密码提示 → 目录列表 →
  进入子目录 → 新建目录；上传与下载也做了字节级验收：源文件、服务端
  文件、下载后的文件三者 SHA-256 完全一致（下载使用核心配置的
  download_dir，界面显示 uploaded/downloaded 进度条）。同一工具还提供
  direct-tcpip 转发与本地回显端口：实测保存的 Local 规则在宿主连接后监听
  127.0.0.1:18080，经隧道回显 127.0.0.1:18081，收发字节一致。
- SFTP 远端目录树：`xenterm_sftp_toggle_tree` + 快照 `tree`，左树只显示
  目录、按层缩进、可展开/收起并跳转；根节点 `/` 在连接后自动展开。
- 分组（文件夹）管理：`xenterm_groups_json/create/rename/delete/collapse`
  与 `xenterm_session_move_group` 全部落在 ConfigStore 的 groups /
  collapsed_session_groups 上。Hosts 屏按分组渲染可折叠的段落，新建分组
  走 New host ▾ → New group，组头的 hover 动作提供新建主机/重命名/删除
  （删除前内联确认，组内主机退回 Hosts）；收起状态持久化。
- 导入：`xenterm_import_ssh_config`（`{"text": "…"}`，空文本读取
  `~/.ssh/config`）复用核心 `core::ssh_import` 的去重规则，只新增未保存的
  alias / user@host；结果进入 Hosts 顶部横幅。
- 资源采样：终端泵线程转发 `SessionEvent::ResourceStats` /
  `ResourceMonitorStatus`，快照新增 `resource`（CPU/内存/swap/网卡/磁盘/
  GPU/进程）与 `resourceState`（waiting/available/unavailable/stale/
  paused/unsupported）。SSH 会话连接后自动开启核心已有的辅助监控通道；
  Flutter 右侧工具面板的 SYSTEM 区域绘制实时 CPU/内存/磁盘/网络/GPU 条，
  不可用状态会明确写出而不是隐藏。`apps/xenterm/tool/sftp_test_server.py`
  同时应答资源/进程 exec 通道，提供固定样本供端到端验收。
- 测试补充：`cargo test -p xenterm-bridge` 覆盖分组往返与 SSH 配置导入；
  `flutter test` 覆盖分组折叠/新建/重命名/删除、导入横幅与资源面板渲染。
