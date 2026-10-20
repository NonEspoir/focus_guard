import AppKit
import SwiftUI

/// 主面板和设置窗口。用 AppKit 管理，这样从启动台/Spotlight 再次打开时也能弹出。
@MainActor
final class WindowManager {
    static let shared = WindowManager()

    private var main: NSWindow?
    private var settings: NSWindow?

    func showMain() {
        main = show(main, title: "FocusGuard", view: MenuView())
    }

    func showSettings() {
        settings = show(settings, title: "FocusGuard 设置", view: SettingsView())
    }

    /// 按设置决定是否在程序坞显示图标。切换后把当前窗口重新带到前台，避免设置窗口被藏到后面。
    func applyDockVisibility() {
        let policy: NSApplication.ActivationPolicy = Store.shared.config.showInDock ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        let key = NSApp.keyWindow
        NSApp.setActivationPolicy(policy)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            key?.makeKeyAndOrderFront(nil)
        }
    }

    private func show(_ existing: NSWindow?, title: String, view: some View) -> NSWindow {
        let window = existing ?? {
            let w = NSWindow(contentViewController: NSHostingController(rootView: view))
            w.title = title
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.center()
            return w
        }()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return window
    }
}
