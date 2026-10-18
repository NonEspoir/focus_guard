import Foundation

enum Strictness: String, Codable, CaseIterable, Identifiable {
    case gentle, hard

    var id: String { rawValue }
    var label: String {
        switch self {
        case .gentle: "提醒（等待 + 写理由可放行）"
        case .hard: "硬核（直接关闭，不能提前结束）"
        }
    }
    var shortLabel: String { self == .gentle ? "提醒模式" : "硬核模式" }
}

struct BlockedApp: Codable, Hashable, Identifiable {
    var bundleID: String
    var name: String
    var id: String { bundleID }
}

struct Config: Codable {
    var blockedApps: [BlockedApp] = []
    var blockedDomains: [String] = ["bilibili.com", "weibo.com", "douyin.com", "xiaohongshu.com", "youtube.com"]
    var strictness: Strictness = .gentle
    var defaultMinutes: Int = 25
    var gentleWaitSeconds: Int = 10
    var allowMinutes: Int = 5
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
