import AppKit
import SwiftUI

#if !SCREENSHOTS
@main
#endif
struct FocusGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuView()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        MainActor.assumeIsolated {
            Enforcer.shared.start()
            WindowManager.shared.showMain()
        }
    }

    /// 已在运行时再从启动台/Spotlight/Finder 打开，弹出主面板（菜单栏图标被挤掉时的入口）。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainActor.assumeIsolated { WindowManager.shared.showMain() }
        return false
    }

    /// 硬核会话期间拒绝正常退出（强制退出仍然可以，但会在下次启动时恢复会话）。
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated { Store.shared.isHardLocked } ? .terminateCancel : .terminateNow
    }
}

struct MenuBarLabel: View {
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let session = Store.shared.activeSession {
                Text("🎯 \(formatRemaining(session.endsAt.timeIntervalSince(now)))")
            } else {
                Image(systemName: "scope")
            }
        }
        .onReceive(timer) { now = $0 }
    }
}

func formatRemaining(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval.rounded(.up)))
    return String(format: "%02d:%02d", total / 60, total % 60)
}
