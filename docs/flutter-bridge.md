# Flutter 前端与 Rust 核心桥接方案

## 决策：进程内 FFI（flutter_rust_bridge）

iOS 禁止应用派生子进程，因此"Rust 侧车进程 + JSON-RPC"在移动端不可行；
唯一全平台可行的形态是**进程内 FFI**。选 [flutter_rust_bridge](https://pub.dev/packages/flutter_rust_bridge)
（v2）作为代码生成器：Rust 侧写一次 API，Dart 侧得到类型安全的绑定，
流（终端输出、资源采样、传输进度）以 `Stream` 暴露。

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
- 未实现：连接生命周期、终端输出流、SFTP 与资源采样（下一步）。
