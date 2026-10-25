# 发版 / Release

**简体中文** | [English](#english)

使用发布脚本，让 Git tag 指向的提交本身就已经包含匹配的版本号。

```powershell
.\scripts\release.ps1 v0.8.0 -Push
```

脚本会：

- 要求已跟踪文件没有未提交改动
- 更新 `crates/xenterm/Cargo.toml`、`Cargo.lock` 里的 `xenterm` 版本号，以及
  `apps/xenterm/pubspec.yaml` 的 `version` 前缀（Flutter 打包元数据）
- 运行 `cargo check --locked`
- 以 `XT_VERSION=xt-vX.Y.Z` 运行构建，验证 `xenterm --version` 输出 `xenterm xt-vX.Y.Z`
- 提交版本号变更
- 创建 annotated tag
- 传入 `-Push` 时推送当前分支和 tag

应用的完整版本号遵循 [版本号规范](versioning.md)：稳定版是 `xt-vX.Y.Z`，
由 `scripts/version.sh` 唯一拼接。`crates/xenterm/Cargo.toml` 里的 semver 只作打包元数据
（Windows MSI、macOS Info.plist 与 AUR 包元数据需要使用 semver）。

如果想先在本地创建提交和 tag，不立即推送：

```powershell
.\scripts\release.ps1 v0.8.0
git push origin HEAD
git push origin v0.8.0
```

Release workflow 也会检查推送上来的 tag。比如 tag 名是 `v0.8.0` 时，
`crates/xenterm/Cargo.toml` 和 `Cargo.lock` 必须是 `0.8.0`，否则 workflow 会在构建前失败。

## 发布产物

`v*` 标签构建并发布桌面应用：Flutter UI 与完整 Rust 核心（`xenterm_bridge` 动态库）
打包在同一个压缩包里，解压即用。

| 平台 | 产物 |
| --- | --- |
| Windows x86_64 | `xenterm-<版本>-windows-x86_64-desktop.zip` 与 `xenterm-<版本>-windows-x86_64.msi` |
| macOS aarch64 / x86_64 | `xenterm-<版本>-macos-<arch>-desktop.zip`（含 `XenTerm.app`） |
| Linux x86_64 | `xenterm-<版本>-linux-x86_64-desktop.tar.gz` |

Windows 的 MSI 由 `packaging/windows/main.wxs` 定义、
`apps/xenterm/tool/package_windows_installer.ps1` 生成（使用固定版本的 WiX Toolset 3.14.1，
由 `scripts/install-wix.ps1` 安装）：按机器安装到 `Program Files`，带开始菜单与桌面快捷方式、
卸载入口；便携 zip 则保持配置写在程序旁边。MSI 使用固定 UpgradeCode，旧版 XenTerm MSI 会
原地升级。

CLI / MCP 服务核心不单独打包：它就在桌面包的 `xenterm_bridge` 动态库里，自动化场景
从源码构建。Flutter 未发布 Linux arm64 SDK，因此桌面包暂不含 aarch64。

桌面包由 `apps/xenterm/tool/bundle_native.sh`（把 bridge 放到 Flutter 产物旁）和
`apps/xenterm/tool/package_desktop.sh`（打包并重签 macOS bundle）生成。

推送 `main` 分支会以滚动 beta 的形式发布预览版；`workflow_dispatch` 可选择
beta、stable（对指定 tag 重试发布）或 dry-run（只构建产物）。

<a name="english"></a>

## English

Use the release helper so the tag points at a commit whose crate version
matches the tag.

```powershell
.\scripts\release.ps1 v0.8.0 -Push
```

The script:

- requires no uncommitted tracked-file changes
- updates the version in `crates/xenterm/Cargo.toml`, the `xenterm` entry in
  `Cargo.lock`, and the `version` prefix in `apps/xenterm/pubspec.yaml` (Flutter
  packaging metadata)
- runs `cargo check --locked`
- builds with `XT_VERSION=xt-vX.Y.Z` and verifies `xenterm --version` prints
  `xenterm xt-vX.Y.Z`
- commits the version bump
- creates an annotated tag
- pushes the current branch and tag when `-Push` is passed

The application version string follows the [versioning spec](versioning.md):
stable builds report `xt-vX.Y.Z`, assembled only by `scripts/version.sh`. The
semver in `crates/xenterm/Cargo.toml` remains packaging metadata (the Windows
MSI, the macOS Info.plist and AUR package metadata).

To prepare the commit and tag without pushing:

```powershell
.\scripts\release.ps1 v0.8.0
git push origin HEAD
git push origin v0.8.0
```

The release workflow also checks pushed tags. A tag named `v0.8.0` must match
`crates/xenterm/Cargo.toml` and `Cargo.lock` at `0.8.0`, otherwise the workflow
fails before building.

### Artifacts

A `v*` tag builds and publishes the desktop application: the Flutter UI and the
whole Rust core (the `xenterm_bridge` library) inside one archive per platform.

| Platform | Artifact |
| --- | --- |
| Windows x86_64 | `xenterm-<version>-windows-x86_64-desktop.zip` and `xenterm-<version>-windows-x86_64.msi` |
| macOS aarch64 / x86_64 | `xenterm-<version>-macos-<arch>-desktop.zip` with `XenTerm.app` |
| Linux x86_64 | `xenterm-<version>-linux-x86_64-desktop.tar.gz` |

The Windows MSI is defined by `packaging/windows/main.wxs` and built by
`apps/xenterm/tool/package_windows_installer.ps1` with the pinned WiX Toolset
3.14.1 installed by `scripts/install-wix.ps1`: per-machine under `Program Files`,
with Start-menu and desktop shortcuts, the real XenTerm icon, and an Add/Remove
Programs entry. The portable zip keeps its profile beside the executable. The MSI
uses a fixed UpgradeCode, so an older XenTerm MSI is upgraded in place.

The CLI/MCP service core is not packaged separately: it ships inside the desktop
archive's bridge library, and automation users build it from source. Flutter
publishes no Linux arm64 SDK, so there is no aarch64 desktop archive.

`apps/xenterm/tool/bundle_native.sh` stages the bridge next to the Flutter
output, and `apps/xenterm/tool/package_desktop.sh` archives it and re-signs the
macOS bundle.

Pushing to `main` publishes a rolling beta preview. `workflow_dispatch` offers
beta, stable (retry publishing a selected tag) and dry-run (build only) modes.
