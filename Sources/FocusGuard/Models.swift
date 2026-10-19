import Foundation

enum Strictness: String, Codable, CaseIterable, Identifiable {
    case gentle, hard

    var id: String { rawValue }
    var label: String {
        switch self {
        case .gentle: "提醒（等待 + 写理由可放行）"
        case .hard: "硬核（直接关闭，每天限一次提前结束）"
        }
    }
    var shortLabel: String { self == .gentle ? "提醒模式" : "硬核模式" }
}

enum ListMode: String, Codable, CaseIterable, Identifiable {
    case blacklist, whitelist

    var id: String { rawValue }
    var label: String { self == .blacklist ? "黑名单" : "白名单" }
}

struct AppEntry: Codable, Hashable, Identifiable {
    var bundleID: String
    var name: String
    var id: String { bundleID }
}

/// App 和网站各自有黑名单、白名单两份数据，切换模式只改变生效（和显示）的那份，另一份保留不动。
struct Config: Codable {
    var appListMode: ListMode = .blacklist
    var blockedApps: [AppEntry] = []
    var allowedApps: [AppEntry] = []
    var domainListMode: ListMode = .blacklist
    var blockedDomains: [String] = ["bilibili.com", "weibo.com", "douyin.com", "xiaohongshu.com", "youtube.com"]
    var allowedDomains: [String] = []
    var strictness: Strictness = .gentle
    var defaultMinutes: Int = 25
    var gentleWaitSeconds: Int = 10
    var allowMinutes: Int = 5

    /// 白名单模式下也始终允许的 App，避免把访达和系统设置关掉。
    static let alwaysAllowedApps: Set<String> = ["com.apple.finder", "com.apple.systempreferences"]
    /// 白名单模式下始终允许的主机（本地开发服务器）。
    private static let alwaysAllowedHosts: Set<String> = ["localhost", "127.0.0.1", "::1", "[::1]"]

    /// 当前模式下生效的 App 名单。
    var apps: [AppEntry] {
        get { appListMode == .blacklist ? blockedApps : allowedApps }
        set { if appListMode == .blacklist { blockedApps = newValue } else { allowedApps = newValue } }
    }

    /// 当前模式下生效的网站名单。
    var domains: [String] {
        get { domainListMode == .blacklist ? blockedDomains : allowedDomains }
        set { if domainListMode == .blacklist { blockedDomains = newValue } else { allowedDomains = newValue } }
    }

    /// 是否没有任何会生效的拦截规则（两边都是空黑名单）。
    var hasNoRules: Bool {
        appListMode == .blacklist && blockedApps.isEmpty && domainListMode == .blacklist && blockedDomains.isEmpty
    }

    func isAppPermitted(_ bundleID: String) -> Bool {
        let listed = apps.contains { $0.bundleID == bundleID }
        switch appListMode {
        case .blacklist: return !listed
        case .whitelist: return listed || Self.alwaysAllowedApps.contains(bundleID)
        }
    }

    /// 网址被拦截时返回用于显示和临时放行的名字（黑名单命中的域名，或白名单外的主机名），放行返回 nil。
    /// 只检查 http/https，新标签页、本地文件等页面不受影响。
    func blockedDomain(for url: URL) -> String? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host?.lowercased() else { return nil }
        switch domainListMode {
        case .blacklist:
            return blockedDomains.first { domainMatches(host: host, domain: $0) }
        case .whitelist:
            if Self.alwaysAllowedHosts.contains(host) || allowedDomains.contains(where: { domainMatches(host: host, domain: $0) }) {
                return nil
            }
            return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        }
    }
}

extension Config {
    /// 逐个字段解码，缺失的字段用默认值，保证旧版本的配置文件升级后不丢数据。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Config()
        appListMode = try c.decodeIfPresent(ListMode.self, forKey: .appListMode) ?? d.appListMode
        blockedApps = try c.decodeIfPresent([AppEntry].self, forKey: .blockedApps) ?? d.blockedApps
        allowedApps = try c.decodeIfPresent([AppEntry].self, forKey: .allowedApps) ?? d.allowedApps
        domainListMode = try c.decodeIfPresent(ListMode.self, forKey: .domainListMode) ?? d.domainListMode
        blockedDomains = try c.decodeIfPresent([String].self, forKey: .blockedDomains) ?? d.blockedDomains
        allowedDomains = try c.decodeIfPresent([String].self, forKey: .allowedDomains) ?? d.allowedDomains
        strictness = try c.decodeIfPresent(Strictness.self, forKey: .strictness) ?? d.strictness
        defaultMinutes = try c.decodeIfPresent(Int.self, forKey: .defaultMinutes) ?? d.defaultMinutes
        gentleWaitSeconds = try c.decodeIfPresent(Int.self, forKey: .gentleWaitSeconds) ?? d.gentleWaitSeconds
        allowMinutes = try c.decodeIfPresent(Int.self, forKey: .allowMinutes) ?? d.allowMinutes
    }
}

struct FocusSession: Codable {
    var startedAt: Date
    var endsAt: Date
    var strictness: Strictness
}

struct InterceptEvent: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var target: String
    var action: String
    var reason: String?
}

/// 规范化用户输入的域名：去掉协议、www.、路径和端口。
func normalizeDomain(_ input: String) -> String? {
    var s = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if let r = s.range(of: "://") { s = String(s[r.upperBound...]) }
    s = String(s.split(separator: "/").first ?? "")
    s = String(s.split(separator: ":").first ?? "")
    if s.hasPrefix("www.") { s.removeFirst(4) }
    return s.contains(".") ? s : nil
}

func domainMatches(host: String, domain: String) -> Bool {
    host == domain || host.hasSuffix("." + domain)
}
