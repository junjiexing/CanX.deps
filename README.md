# CanX.deps

[CanX](https://github.com/junjiexing/CanX) 的预编译原生依赖仓库。这里承载全部 C/C++
依赖（mpv、FFmpeg、Skia、aria2、QuickJS 等）的锁定源码、补丁与构建脚本，CI 将各
平台产物打包发布为 Release 资产；CanX 仓库构建时按 `native-deps.lock` 中固定的
Release tag 下载解包后直接链接，不再重复编译依赖。

## 产物

每次 `main` 推送更新滚动 Release `dev`；推送 `v*` tag 发布同名的不可变 Release
（CanX 侧应固定到 `v*` tag）。每个 Release 包含：

| 资产 | 内容 | CanX 侧解压目标 |
|---|---|---|
| `canx-deps-linux-<arch>.tar.gz` | 静态库 `prefix/`、shim 静态库 `shims/`、许可证与锁文件 `metadata/` | `.cache/static-native-ubuntu22.04/linux-<arch>/` |
| `canx-deps-windows-<arch>.tar.gz` | `prefix/`、shim `build/`、`vcpkg-installed/` | `.cache/windows-msvc[-<arch>]/` |
| `canx-deps-android-<abi>.tar.gz` | NDK 静态/共享库 `prefix/` | `.cache/android-native/<abi>/` |
| `canx-deps-macos-arm64.tar.gz` | libmpv frameworks 与 shim dylib，按 `.cache/` 相对布局 | `.cache/` |
| `canx-deps-source.tar.gz` | 全部锁定上游源码（GPL 对应源码包组成） | 由 CanX 源码打包脚本合并 |
| `SHA256SUMS` | 全部资产的校验和 | 下载脚本据此校验 |

Linux 产物在 Ubuntu 22.04（glibc 2.35）容器内构建，与 CanX 的发行基线一致；
Windows 产物使用 MSVC 静态运行时（`/MT`）与 vcpkg overlay triplet；
macOS 产物以 `MACOSX_DEPLOYMENT_TARGET=13.0` 构建。

## 何时需要在这里工作

- 升级依赖版本：修改 `native/sources-*.lock` 中的固定提交或 `native/patches/` 补丁。
- 修改 shim（`native/aria2-shim`、`native/quickjs-shim`）：CanX 与原生库之间的
  C ABI 胶水代码。
- 调整依赖编译选项：各 `scripts/build-static-native-*`、`scripts/build-macos-*`。

合并到 `main` 后等待 `Build native dependencies` 工作流完成，确认各平台包构建
成功，然后创建并推送新的 tag（如 `v2`），tag 流水线会发布对应 Release。最后在
CanX 仓库把 `native-deps.lock` 中的 tag 更新为新版本。

## 目录

- `native/`：源码锁（`sources-linux-x64.lock`、`sources-windows-x64.lock`、
  `quickjs-source.lock`）、补丁、shim 源码、Windows vcpkg 清单与 overlay
  triplet、Ubuntu 22.04 构建镜像 Dockerfile。
- `scripts/`：各平台依赖构建与打包脚本；`run-ubuntu-22.04-linux-x64.sh` 是
  Linux 构建的 Docker 入口。
- `spikes/CanX.Spikes.Mobile.Android`：仅用于 provisioning Android SDK/NDK 的
  最小工程（`prepare-android-workload.sh` 使用）。
