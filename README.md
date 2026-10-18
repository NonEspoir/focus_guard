# FocusGuard

macOS 菜单栏自律工具：专注期间拦截摸鱼 App 和网站。

## 功能

- **专注会话**：在菜单栏设定时长后开始，菜单栏显示倒计时。
- **两种模式**
  - 提醒模式：命中黑名单时隐藏该 App 并弹出全屏遮罩，可以选择「回去工作」，或者等待 N 秒、写下理由后临时放行。提前结束专注需要写理由。
  - 硬核模式：直接关闭 App 或标签页；会话期间无法正常退出，也不能删除规则或放宽选项。每天只有一次无条件提前结束的机会。
- **入口**：启动时弹出主面板；菜单栏图标被挤掉时，从启动台或 Spotlight 再次打开 FocusGuard 也会弹出主面板。
- **网站拦截**：支持 Safari、Chrome、Edge、Brave、Arc，匹配域名及其子域名。
- **拦截记录**：保留最近 30 天的拦截时间、处理方式和放行理由。

数据保存在 `~/Library/Application Support/FocusGuard/`。

## 下载使用

到 [Releases](https://github.com/NonEspoir/focus_guard/releases) 下载最新的 `FocusGuard-x.y.z.zip`，解压后拖进「应用程序」。需要 macOS 14 及以上，支持 Apple 芯片和 Intel。

App 没有经过 Apple 公证，第一次打开会被系统拦截，需要到「系统设置 → 隐私与安全性」点「仍要打开」。完整步骤、黑名单设置和浏览器权限说明见 **[使用教程](docs/使用教程.md)**。

## 从源码构建

只需要 Command Line Tools，不需要 Xcode：

```bash
./scripts/build_app.sh             # 只打包到 build/
./scripts/build_app.sh --install   # 打包并安装到 /Applications（启动台可见）
./scripts/build_app.sh --release   # 打包通用二进制并压缩成 zip，用于发布
```

发布新版本时，先修改 `scripts/build_app.sh` 里的 `VERSION`。

## 待办

见 [TODO.md](TODO.md)。
