import AppKit

/// 扫描所有运行中的 App 和所有浏览器窗口（不只是前台），命中黑名单时按会话的严格程度处理。
@MainActor
final class Enforcer {
    static let shared = Enforcer()

    private enum Target {
        case app(NSRunningApplication, name: String)
        case web(Browser, windowID: Int, domain: String)

        var key: String {
            switch self {
            case .app(let app, _): app.bundleIdentifier ?? ""
            case .web(_, _, let domain): domain
            }
        }

        var name: String {
            switch self {
            case .app(_, let name): name
            case .web(_, _, let domain): domain
            }
        }
    }

    private let store = Store.shared
    private let shield = ShieldController()
    private let ownBundleID = Bundle.main.bundleIdentifier
    /// 提醒模式下用户写了理由后的临时放行，key 为 bundleID 或域名。
    private var allowedUntil: [String: Date] = [:]
    private var timer: Timer?

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // 轮询用于：切换标签页、后台窗口里打开网页、放行到期、会话开始时已打开的 App。
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func tick() {
        if store.session != nil, store.activeSession == nil {
            store.session = nil
            allowedUntil.removeAll()
        }
        guard let session = store.activeSession, !shield.isShowing,
              let target = findViolation(strictness: session.strictness) else { return }
        intercept(target, strictness: session.strictness)
    }

    private func isAllowed(_ key: String) -> Bool {
        if let until = allowedUntil[key], until > Date() { return true }
        return false
    }

    /// 前台 App 优先检查，然后是其它运行中的 App。
    private func findViolation(strictness: Strictness) -> Target? {
        let frontmost = NSWorkspace.shared.frontmostApplication
        let others = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != ownBundleID && $0 != frontmost }
        let apps = (frontmost.map { [$0] } ?? []).filter { $0.bundleIdentifier != ownBundleID } + others

        let config = store.config
        for app in apps {
            guard let bundleID = app.bundleIdentifier, !isAllowed(bundleID) else { continue }
            if !config.isAppPermitted(bundleID) {
                // 已隐藏的 App 一般不打扰；黑名单 + 硬核模式下只要在运行就关闭（包括后台播放）。
                // 白名单模式只管看得见的 App，避免开始专注时把后台所有 App 一次性关掉。
                if !app.isHidden || (strictness == .hard && config.appListMode == .blacklist) {
                    let name = config.apps.first { $0.bundleID == bundleID }?.name ?? app.localizedName ?? bundleID
                    return .app(app, name: name)
                }
            } else if let browser = Browser(bundleID: bundleID), !app.isHidden {
                for tab in browser.visibleTabs() {
                    guard let domain = config.blockedDomain(for: tab.url), !isAllowed(domain) else { continue }
                    return .web(browser, windowID: tab.windowID, domain: domain)
                }
            }
        }
        return nil
    }

    private func intercept(_ target: Target, strictness: Strictness) {
        switch strictness {
        case .hard:
            switch target {
            case .app(let app, _):
                app.terminate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if !app.isTerminated { app.forceTerminate() }
                }
            case .web(let browser, let windowID, _):
                browser.closeTab(inWindow: windowID)
            }
            store.log(target: target.name, action: "已关闭")
            shield.showNotice(title: "已关闭 \(target.name)", subtitle: "专注中，回去工作吧")

        case .gentle:
            let frontmost = NSWorkspace.shared.frontmostApplication
            if case .app(let app, _) = target { app.hide() }
            let config = store.config
            shield.showPrompt(
                name: target.name,
                waitSeconds: config.gentleWaitSeconds,
                allowMinutes: config.allowMinutes,
                onBack: { [weak self] in
                    if case .web(let browser, let windowID, _) = target { browser.closeTab(inWindow: windowID) }
                    self?.store.log(target: target.name, action: "回去工作")
                },
                onAllow: { [weak self] reason in
                    guard let self else { return }
                    allowedUntil[target.key] = Date().addingTimeInterval(TimeInterval(config.allowMinutes * 60))
                    store.log(target: target.name, action: "放行 \(config.allowMinutes) 分钟", reason: reason)
                    if case .app(let app, _) = target { app.unhide() }
                    frontmost?.activate()
                }
            )
        }
    }
}
