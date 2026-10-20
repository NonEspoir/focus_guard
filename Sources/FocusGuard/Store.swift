import Foundation
import Observation

/// 配置、专注会话和拦截记录，全部以 JSON 存在 ~/Library/Application Support/FocusGuard/。
@MainActor
@Observable
final class Store {
    static let shared = Store()

    var config: Config { didSet { save(config, to: "config.json") } }
    var session: FocusSession? { didSet { save(session, to: "session.json") } }
    private(set) var events: [InterceptEvent]

    private static let dir: URL = {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FocusGuard", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private init() {
        config = Self.load("config.json") ?? Config()
        session = Self.load("session.json")
        events = Self.load("events.json") ?? []
    }

    /// 尚未结束的会话（应用重启后会自动恢复）。
    var activeSession: FocusSession? {
        guard let s = session, s.endsAt > Date() else { return nil }
        return s
    }

    var isHardLocked: Bool { activeSession?.strictness == .hard }

    func startSession(minutes: Int, strictness: Strictness) {
        let now = Date()
        session = FocusSession(startedAt: now, endsAt: now.addingTimeInterval(TimeInterval(minutes * 60)), strictness: strictness)
    }

    static let earlyEndTarget = "专注会话"
    private static let hardBreakAction = "硬核模式提前结束"

    /// 硬核模式每天有一次无条件提前结束的机会（按拦截记录里的当天记录判断）。
    var hardBreakAvailableToday: Bool {
        !todayEvents.contains { $0.target == Self.earlyEndTarget && $0.action == Self.hardBreakAction }
    }

    /// 提前结束会话。提醒模式需要理由；硬核模式每天只能用一次。
    func endSessionEarly(reason: String?) {
        guard let s = activeSession else { return }
        switch s.strictness {
        case .gentle:
            guard let reason, !reason.isEmpty else { return }
            log(target: Self.earlyEndTarget, action: "提醒模式提前结束", reason: reason)
        case .hard:
            guard hardBreakAvailableToday else { return }
            log(target: Self.earlyEndTarget, action: Self.hardBreakAction)
        }
        session = nil
    }

    func log(target: String, action: String, reason: String? = nil) {
        events.append(InterceptEvent(date: Date(), target: target, action: action, reason: reason))
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        events.removeAll { $0.date < cutoff }
        save(events, to: "events.json")
    }

    var todayEvents: [InterceptEvent] {
        events.filter { Calendar.current.isDateInToday($0.date) }
    }

    private static func load<T: Decodable>(_ name: String) -> T? {
        guard let data = try? Data(contentsOf: dir.appendingPathComponent(name)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T?, to name: String) {
        let url = Self.dir.appendingPathComponent(name)
        guard let value else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? encoder.encode(value).write(to: url, options: .atomic)
    }
}
