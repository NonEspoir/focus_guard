import AppKit
import SwiftUI

/// 用演示数据渲染 README 截图（不需要屏幕录制权限，也不会碰真实配置）。
/// 由 scripts/make_screenshots.sh 编译运行，FOCUSGUARD_DATA_DIR 指向临时目录。
@main
@MainActor
enum Screenshots {
    static let outDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "docs/images", isDirectory: true)

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.appearance = NSAppearance(named: .aqua)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        writeDemoEvents()
        let store = Store.shared
        store.session = nil
        store.config = demoConfig()

        render(menuBar, name: "menubar-idle")
        render(card(MenuView()), name: "panel-idle")
        render(card(SettingsView(tab: .apps)), name: "settings-apps")
        render(card(SettingsView(tab: .domains)), name: "settings-domains")
        render(card(SettingsView(tab: .history)), name: "settings-history")
        render(shield, name: "shield-prompt")  // make_screenshots.sh 会缩小并转成 jpg

        let now = Date()
        store.session = FocusSession(startedAt: now.addingTimeInterval(-26 * 60 - 28),
                                     endsAt: now.addingTimeInterval(18 * 60 + 32), strictness: .gentle)
        render(menuBar, name: "menubar-focus")
        render(card(MenuView()), name: "panel-focus")
        store.session = nil
    }

    // MARK: - 演示数据

    static func demoConfig() -> Config {
        var c = Config()
        c.blockedApps = [
            AppEntry(bundleID: "com.tencent.xinWeChat", name: "微信"),
            AppEntry(bundleID: "com.tencent.qq", name: "QQ"),
            AppEntry(bundleID: "com.netease.163music", name: "网易云音乐"),
            AppEntry(bundleID: "com.valvesoftware.steam", name: "Steam"),
        ]
        c.strictness = .gentle
        c.defaultMinutes = 45
        return c
    }

    /// 在 Store 加载前写入演示记录，时间分散在过去几小时。
    static func writeDemoEvents() {
        guard let dir = ProcessInfo.processInfo.environment["FOCUSGUARD_DATA_DIR"] else { return }
        let items: [(Double, String, String, String?)] = [
            (172, "bilibili.com", "回去工作", nil),
            (131, "微信", "放行 5 分钟", "导师发消息，需要回复"),
            (96, "weibo.com", "回去工作", nil),
            (58, "专注会话", "提醒模式提前结束", "临时要开组会"),
            (21, "Steam", "回去工作", nil),
        ]
        let events = items.map { InterceptEvent(date: Date().addingTimeInterval(-$0.0 * 60), target: $0.1, action: $0.2, reason: $0.3) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? encoder.encode(events).write(to: URL(fileURLWithPath: dir).appendingPathComponent("events.json"))
    }

    // MARK: - 场景

    /// 菜单栏示意：一段浅色菜单栏，右侧是 FocusGuard 图标和系统图标。
    static var menuBar: some View {
        HStack(spacing: 18) {
            MenuBarLabel()
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 5).fill(.black.opacity(0.08)))
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            Image(systemName: "magnifyingglass")
            Image(systemName: "switch.2")
            Text(Date(), format: .dateTime.month().day().weekday().hour().minute())
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.black.opacity(0.85))
        .padding(.horizontal, 16)
        .frame(height: 30)
        .background(Color(white: 0.93))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(12)
    }

    static var shield: some View {
        PromptView(name: "bilibili.com", waitSeconds: 10, allowMinutes: 5, onBack: {}, onAllow: { _ in })
            .frame(width: 880, height: 520)
            .background(LinearGradient(colors: [Color(white: 0.97), Color(white: 0.90)], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.12)))
            .padding(16)
    }

    /// 模拟窗口外观：圆角卡片 + 描边，透明背景。
    static func card(_ content: some View) -> some View {
        content
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.12)))
            .padding(16)
    }

    // MARK: - 渲染

    static func render(_ view: some View, name: String) {
        let host = NSHostingView(rootView: view)
        host.frame.size = host.fittingSize
        let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: -30000, y: -30000), size: host.frame.size),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = host
        window.orderFrontRegardless()
        // 等 SwiftUI 完成布局和异步加载（图标、列表）
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
        host.layoutSubtreeIfNeeded()

        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        window.orderOut(nil)
        let url = outDir.appendingPathComponent("\(name).png")
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        print("已生成 \(url.path)（\(rep.pixelsWide)×\(rep.pixelsHigh)）")
    }
}
