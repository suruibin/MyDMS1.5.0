# DankMaterialShell

<div align="center">
  <a href="https://danklinux.com">
    <img src="assets/danklogo.svg" alt="DankMaterialShell" width="200">
  </a>

### A modern desktop shell for Wayland

Built with [Quickshell](https://quickshell.org/) and [Go](https://go.dev/)

[![Documentation](https://img.shields.io/badge/docs-danklinux.com-9ccbfb?style=for-the-badge&labelColor=101418)](https://danklinux.com/docs)
[![GitHub stars](https://img.shields.io/github/stars/AvengeMedia/DankMaterialShell?style=for-the-badge&labelColor=101418&color=ffd700)](https://github.com/AvengeMedia/DankMaterialShell/stargazers)
[![GitHub License](https://img.shields.io/github/license/AvengeMedia/DankMaterialShell?style=for-the-badge&labelColor=101418&color=b9c8da)](https://github.com/AvengeMedia/DankMaterialShell/blob/master/LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/AvengeMedia/DankMaterialShell?style=for-the-badge&labelColor=101418&color=9ccbfb)](https://github.com/AvengeMedia/DankMaterialShell/releases)
[![Arch version](https://img.shields.io/archlinux/v/extra/x86_64/dms-shell?style=for-the-badge&labelColor=101418&color=9ccbfb)](https://archlinux.org/packages/extra/x86_64/dms-shell/)
[![AUR version (git)](<https://img.shields.io/aur/version/dms-shell-git?style=for-the-badge&labelColor=101418&color=9ccbfb&label=AUR%20(git)>)](https://aur.archlinux.org/packages/dms-shell-git)
[![Ko-Fi donate](https://img.shields.io/badge/donate-kofi?style=for-the-badge&logo=ko-fi&logoColor=ffffff&label=ko-fi&labelColor=101418&color=f16061&link=https%3A%2F%2Fko-fi.com%2Fdanklinux)](https://ko-fi.com/danklinux)

</div>

DankMaterialShell is a complete desktop shell for [niri](https://github.com/YaLTeR/niri), [Hyprland](https://hyprland.org/), [MangoWC](https://github.com/DreamMaoMao/mangowc), [Sway](https://swaywm.org), [labwc](https://labwc.github.io/), [Scroll](https://github.com/dawsers/scroll), [Miracle WM](https://github.com/miracle-wm-org/miracle-wm), and other Wayland compositors. It replaces waybar, swaylock, swayidle, mako, fuzzel, polkit, and everything else you'd normally stitch together to make a desktop.

## Repository Structure

This is a monorepo containing both the shell interface and the core backend services:

```
DankMaterialShell/
├── quickshell/         # QML-based shell interface
│   ├── Modules/        # UI components (panels, widgets, overlays)
│   ├── Services/       # System integration (audio, network, bluetooth)
│   ├── Widgets/        # Reusable UI controls
│   └── Common/         # Shared resources and themes
├── core/               # Go backend and CLI
│   ├── cmd/            # dms CLI and dankinstall binaries
│   ├── internal/       # System integration, IPC, distro support
│   └── pkg/            # Shared packages
├── distro/             # Distribution packaging
│   ├── fedora/         # Fedora RPM specs
│   ├── debian/         # Debian packaging
│   └── nix/            # NixOS/home-manager modules
└── flake.nix           # Nix flake for declarative installation
```

## 功能截图

<div align="center">

![Screenshot](https://raw.githubusercontent.com/suruibin/MyDMS1.5.0/main/screenshots.png)
</div>

## 自定义增强功能

> 以下功能为 [MyDMS1.5.0](https://github.com/suruibin/MyDMS1.5.0) 在原始 DMS v1.6-beta 基础上移植的自定义增强。

### 📱 程序面板 (AppDrawer)

DankDash 新增「程序」Tab，集中管理 AppImage 和桌面应用：

- **AppImage 管理**: 自动扫描 `~/Software/*.AppImage`，网格展示，点击启动
- **桌面应用管理**: 点 `+` 按钮从系统 `.desktop` 文件中选取添加，支持删除
- **智能图标匹配**: 自动从 AppImage 中提取图标（递归搜索 `*.png`/`*.svg`/`.DirIcon`），缓存在 `~/Software/AppIcon/`
- **健壮的名称解析**: 智能剥离版本号/架构后缀（`-x86_64`、`_amd64`、`-linux-amd64` 等），首字母大写显示
- **容错图标匹配**: 支持前缀匹配、归一化匹配（忽略 `.`/`-_` 分隔符），优先使用图标文件名作为显示名

**修改文件：**
| 文件 | 改动 |
|---|---|
| `quickshell/Modules/DankDash/AppDrawer.qml` | **新增** — 核心组件，应用扫描/图标提取/名称解析/图标大小调节全部逻辑 |
| `quickshell/Modules/DankDash/DankDashPopout.qml` | 注册 programs tab、Loader、键盘导航 |
| `quickshell/Common/SettingsData.qml` | `_dashTabIds` 和 `_dashTabsDefault` 添加 programs |
| `quickshell/Common/settings/SettingsSpec.js` | `dashTabs` 默认配置添加 programs |
| `quickshell/Modules/Settings/DankDashTab.qml` | 设置面板中 programs 的展示定义 |
| `quickshell/translations/en.json` | Programs 英文翻译 |
| `quickshell/translations/poexports/zh_CN.json` | Programs 中文翻译 |

### 🎵 cnmplayer 快捷入口

Media 面板右上角新增 cnmplayer 一键启动按钮（kitty 终端），点击即开。

**修改文件：** `quickshell/Modules/DankDash/MediaPlayerTab.qml` — 新增 `launchCnmplayer()` 函数和圆形按钮

### 🖼️ 壁纸滚轮翻页

壁纸选择面板支持鼠标滚轮翻页，带累积阈值（200px）防误触。

**修改文件：** `quickshell/Modules/DankDash/WallpaperTab.qml` — 新增 `accumulatedWheelDelta` 属性和滚轮事件处理

---

## Supported Compositors

Works best with [niri](https://github.com/YaLTeR/niri), [Hyprland](https://hyprland.org/), [Sway](https://swaywm.org/), [MangoWC](https://github.com/DreamMaoMao/mangowc), [labwc](https://labwc.github.io/), [Scroll](https://github.com/dawsers/scroll), and [Miracle WM](https://github.com/miracle-wm-org/miracle-wm) with full workspace switching, overview integration, and monitor management. Other Wayland compositors work with reduced features.

[Compositor configuration guide](https://danklinux.com/docs/dankmaterialshell/compositors)

## Command Line Interface

Control the shell from the command line or keybinds:

```bash
dms run              # Start the shell
dms ipc call spotlight toggle
dms ipc call audio setvolume 50
dms ipc call wallpaper set /path/to/image.jpg
dms brightness list  # List available displays
dms plugins search   # Browse plugin registry
```

[Full CLI and IPC documentation](https://danklinux.com/docs/dankmaterialshell/keybinds-ipc)

## Documentation

- **Website:** [danklinux.com](https://danklinux.com)
- **Docs:** [danklinux.com/docs](https://danklinux.com/docs/)
- **Theming:** [Application themes](https://danklinux.com/docs/dankmaterialshell/application-themes) | [Custom themes](https://danklinux.com/docs/dankmaterialshell/custom-themes)
- **Plugins:** [Development guide](https://danklinux.com/docs/dankmaterialshell/plugins-overview)
- **Support:** [Ko-fi](https://ko-fi.com/avengemediallc)

## Development

See component-specific documentation:

- **[quickshell/](quickshell/)** - QML shell development, widgets, and modules
- **[core/](core/)** - Go backend, CLI tools, and system integration
- **[distro/](distro/)** - Distribution packaging (Fedora, Debian, NixOS)

### Building from Source

**Core + Dankinstall:**

```bash
cd core
make              # Build dms CLI
make dankinstall  # Build installer
```

**Shell:**

```bash
quickshell -p quickshell/
```

**NixOS:**

```nix
{
  inputs.dms.url = "github:AvengeMedia/DankMaterialShell";

  # Use in home-manager or NixOS configuration
  imports = [ inputs.dms.homeModules.dank-material-shell ];
}
```

## Contributing

Contributions welcome. Bug fixes, widgets, features, documentation, and plugins all help.

1. Fork the repository
2. Make your changes
3. Test thoroughly
4. Open a pull request

For documentation contributions, see [DankLinux-Docs](https://github.com/AvengeMedia/DankLinux-Docs).

## Credits

- [quickshell](https://quickshell.org/) - Shell framework
- [niri](https://github.com/YaLTeR/niri) - Scrolling window manager
- [Ly-sec](http://github.com/ly-sec) - Wallpaper effects from [Noctalia](https://github.com/noctalia-dev/noctalia-shell)
- [soramanew](https://github.com/soramanew) - [Caelestia](https://github.com/caelestia-dots/shell) inspiration
- [end-4](https://github.com/end-4) - [dots-hyprland](https://github.com/end-4/dots-hyprland) inspiration

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=AvengeMedia/DankMaterialShell&type=date&legend=top-left)](https://www.star-history.com/#AvengeMedia/DankMaterialShell&type=date&legend=top-left)

## License

MIT License - See [LICENSE](LICENSE) for details.
