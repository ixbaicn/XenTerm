# 发版 / Release

**简体中文** | [English](#english)

使用发布脚本，让 Git tag 指向的提交本身就已经包含匹配的 Cargo 版本号。

```powershell
.\scripts\release.ps1 v0.5.7 -Push
```

脚本会：

- 要求已跟踪文件没有未提交改动
- 更新 `Cargo.toml` 和 `Cargo.lock` 里的 `xenterm` 版本号
- 运行 `cargo check --locked`
- 以 `XT_VERSION=xt-vX.Y.Z` 运行构建，验证 `xenterm --version` 输出 `xenterm xt-vX.Y.Z`
- 提交版本号变更
- 创建 annotated tag
- 传入 `-Push` 时推送当前分支和 tag

应用的完整版本号遵循 [版本号规范](versioning.md)：稳定版是 `xt-vX.Y.Z`，
由 `scripts/version.sh` 唯一拼接。`Cargo.toml` 里的 semver 只作打包元数据
（deb / MSI / Info.plist）。

如果想先在本地创建提交和 tag，不立即推送：

```powershell
.\scripts\release.ps1 v0.5.7
git push origin HEAD
git push origin v0.5.7
```

Release workflow 也会检查推送上来的 tag。比如 tag 名是 `v0.5.7` 时，
`Cargo.toml`、`Cargo.lock` 和构建出的 `xenterm --version` 都必须是
`0.5.7`，否则 workflow 会在发布前失败。

<a name="english"></a>

## English

Use the release helper so the tag points at a commit whose Cargo package version
matches the tag.

```powershell
.\scripts\release.ps1 v0.5.7 -Push
```

The script:

- requires no uncommitted tracked-file changes
- updates `Cargo.toml` and the `xenterm` entry in `Cargo.lock`
- runs `cargo check --locked`
- builds with `XT_VERSION=xt-vX.Y.Z` and verifies `xenterm --version` prints
  `xenterm xt-vX.Y.Z`
- commits the version bump
- creates an annotated tag
- pushes the current branch and tag when `-Push` is passed

The application version string follows the [versioning spec](versioning.md):
stable builds report `xt-vX.Y.Z`, assembled only by `scripts/version.sh`. The
semver in `Cargo.toml` remains packaging metadata (deb / MSI / Info.plist).

To prepare the commit and tag without pushing:

```powershell
.\scripts\release.ps1 v0.5.7
git push origin HEAD
git push origin v0.5.7
```

The release workflow also checks pushed tags. A tag named `v0.5.7` must match
`Cargo.toml`, `Cargo.lock`, and the built `xenterm --version` output,
otherwise the workflow fails before publishing.
