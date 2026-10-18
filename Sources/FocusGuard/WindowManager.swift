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
