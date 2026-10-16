# Termius 设计令牌（逆向提取，Flutter 复刻规格）

来源：Termius 10.2.1（Electron）`app.asar` 前端产物——`reconnectSaga-e37b5571.css`
的 `:root` 令牌定义与 `.termius-dark-theme` 语义映射、`ui-process-*.js` 中的
`createTheme({spacing:1,…})` 主题对象。**这些是原版真实值，不是目测。**

## 1. 原始调色板（`:root`）

### 深色阶 dark-grey
| 令牌 | 值 | 用途 |
|---|---|---|
| dark-grey-1 | `#141729` | surface-lowest / universal-black |
| dark-grey-2 | `#1d2033` | surface-base（窗口/侧栏底） |
| dark-grey-3 | `#282b3d` | surface-high（卡片/菜单） |
| dark-grey-4 | `#32364a` | surface-highest / 表单底 / 普通按钮 |
| dark-grey-5 | `#3e4257` | border-strong / 列表 hover |
| dark-grey-6 | `#5a5e73` | 禁用文字 / 滚动条 |
| dark-grey-7 | `#8d91a5` | text-secondary；其 alpha 派生全家桶：a05/a10/a15/a20/a25/a35/a45/a50/a60 |

### 浅色阶 light-grey
`light-grey-1 #798c94 · 3 #a4b3ba · 4 #d5dde0 · 5 #e6ebed · 6 #edf1f2 · 7 #f7f9fa`
（+ `light-grey-a05..a35` 派生）

### 强调色
`blue #2091f6 · blue-light #58adf8 · blue-dark #186cb5 · dark-blue #182542 ·
green #21b568 · green-medium #00cc74 · green-light #00d67a · red #f25e61 ·
orange #f8aa4b · teal #54d2d2 · purple #af5fff · yellow #f2c94c · blueberry #6666d2`

黑白 alpha 派生：`white-a03…a90`、`black-a03…a90`。

## 2. 语义映射（dark 主题）

```
text-primary:   white            text-secondary: dark-grey-7
text-disabled:  dark-grey-6      text-accent:    blue
surface-base:   dark-grey-2      surface-lowest: dark-grey-1
surface-high:   dark-grey-3      surface-highest: dark-grey-4
surface-hover-basic: dark-grey-7-a10    surface-hover-light: a05
border-basic:   dark-grey-7-a25  border-strong: dark-grey-5
button-accent:  blue             button-regular: dark-grey-4
input-border-focused: green-medium     main-form-bg: dark-grey-4
list-hover: dark-grey-5           list-select: dark-grey-4
sidebar-accent: blue              backdrop: black-a50
```

浅色主题对应：`surface-base: light-grey-6 · surface-high: light-grey-7 ·
surface-highest: white · text-primary: dark-grey-1 · text-secondary: light-grey-1 ·
border-basic: light-grey-a25`。

## 3. 排版（CircularXX，回退 sans-serif）

| 名 | 规格 | 用途 |
|---|---|---|
| b22w | 22/700 lh28 | 页标题 |
| r18w / r17w | 18·17/450 | 大节题 |
| b16p | 16/700 | |
| r14p / r14s / b14p | 14/450·700 lh18 | 正文/表单 |
| r12p…b12p | 12/450 lh15 | 次要文字 |
| b12wu | 12/700 **大写** letter-spacing 1px lh23 | 分节标题 |
| b11w / r10s / r9u | 11/700 · 10 · 9 大写 | 微标签 |

`--default-font-size: 14px`；图标字体 Material Design Icons 20px。

## 4. 度量

- **间距单位 = 1px**（`createTheme({spacing:1})`）；常用 gap 10/15/20/30。
- 圆角刻度：4 / 5 / 6(菜单) / **8(卡片·图标块)** / **10(输入框·按钮)** / 15 / 20 / 25 / 35 / full(胶囊)。
- 左导航 ≈ **190px**（图标+文字行）；主机列 ≈ **250px**（可拖宽）；
  主机行图标块 **36×36 圆角 8**；按钮高 **36**（小 30）；表单内边距 **15px**。
- 窗口圆角：mac 10px，win/linux 0。
- 滚动条宽 10px、圆角 6。

## 5. 动效（MUI 体系）

- 时长：`shortest 150 · shorter 200 · short 250 · standard 300 · complex 375 ·
  enteringScreen 225 · leavingScreen 195`（ms）。
- 缓动：easeOut `cubic-bezier(0,0,0.2,1)`（默认）、easeInOut `(0.4,0,0.2,1)`、
  sharp `(0.4,0,0.6,1)`。
- 微交互：输入框 color/border **200ms easeOut**；悬停显隐按钮 "all 0.1s ease"；
  进度条 shimmer 2.1s `(0.165,0.84,0.44,1)`。
- 折叠组件（Collapse，69 处）：展开 **300ms** / 收起 **200ms**，easeInOut。
- 行内悬停显隐：行 hover 时 opacity/display 切换显示"更多"按钮。

## 6. 结构与交互（Hosts 屏）

```
┌──────────┬────────────────┬───────────────────────────────┐
│ 左导航190 │ 主机列250(拖宽) │ 内容区                          │
│ 图标+文字 │ 搜索框(圆角10)  │ 大标题+幽灵图标工具栏+主按钮      │
│ 6项      │ 主机行/卡片列表  │ 主机卡片网格(2-3列) or 列表      │
│          │ 底部 SFTP/Vault │ 选中→详情浮层卡(左侧,~45%宽)     │
└──────────┴────────────────┴───────────────────────────────┘
```

- 导航项（自上而下）：Hosts / Keychain / Port Forwarding / Snippets /
  Known Hosts / Logs；进入终端视图后导航收窄为图标轨，宽度让给终端。
- 搜索框占位：`Find a host or ssh user@hostname...`；右侧 Connect 主按钮
  随选中启用。
- 主机行：36px 圆角图标块 + 名称(14) + 用户名(12 次)；hover 显现操作按钮。
- 详情浮层：覆盖在网格左侧的卡片（圆角、投影、关闭×），分节
  Address / Credentials / General + "Show more" 折叠 + autosave
  （"All changes saved"），底部 Connect / Add Telnet。
- 主机卡片：图标块+名称+用户名+标签 pill；选中蓝色描边；布局可切 网格/列表。

Flutter 映射：以上直接翻译为 `shadcn_flutter` 的主题色板与 `Theme` 数据；
动效用 Flutter `AnimatedContainer`/`ImplicitlyAnimatedWidget`（200/300ms +
Cubic(0,0,0.2,1)）。
