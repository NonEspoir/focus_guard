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

## 构建

只需要 Command Line Tools，不需要 Xcode：

```bash
./scripts/build_app.sh             # 只打包到 build/
./scripts/build_app.sh --install   # 打包并安装到 /Applications（启动台可见）
```

安装后可以在「系统设置 → 通用 → 登录项」里添加 FocusGuard，实现开机启动。

## 权限

- 关闭和隐藏 App 不需要特殊权限。
- 网站拦截第一次触发时，系统会询问是否允许 FocusGuard 控制浏览器，请点「允许」。如果之前点了拒绝，可以到「系统设置 → 隐私与安全性 → 自动化」里重新打开。

## 待办

见 [TODO.md](TODO.md)。
