import Foundation

/// 通过 AppleScript 读取/关闭浏览器标签页。首次使用时系统会请求「自动化」权限。
/// Firefox 不支持 AppleScript 读取 URL，因此不在列表中。
enum Browser {
    case safari(String)
    case chromium(String)

    struct VisibleTab {
        var windowID: Int
        var url: URL
    }

    init?(bundleID: String) {
        switch bundleID {
        case "com.apple.Safari": self = .safari("Safari")
        case "com.apple.SafariTechnologyPreview": self = .safari("Safari Technology Preview")
        case "com.google.Chrome": self = .chromium("Google Chrome")
        case "com.microsoft.edgemac": self = .chromium("Microsoft Edge")
        case "com.brave.Browser": self = .chromium("Brave Browser")
        case "company.thebrowser.Browser": self = .chromium("Arc")
        default: return nil
        }
    }

    var appName: String {
        switch self {
        case .safari(let name), .chromium(let name): name
        }
    }

    private var tabProperty: String {
        switch self {
        case .safari: "current tab"
        case .chromium: "active tab"
        }
    }

    private var minimizedProperty: String {
        switch self {
        case .safari: "miniaturized"
        case .chromium: "minimized"
        }
    }

    /// 所有未最小化窗口当前显示的标签页（每个窗口一个）。
    func visibleTabs() -> [VisibleTab] {
        let script = """
        set out to ""
        tell application "\(appName)"
            repeat with w in windows
                set m to false
                try
                    set m to \(minimizedProperty) of w
                end try
                if not m then
                    try
                        set out to out & (id of w) & "\t" & (URL of \(tabProperty) of w) & "\n"
                    end try
                end if
            end repeat
        end tell
        return out
        """
        guard let output = run(script) else { return [] }
        return output.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2, let id = Int(parts[0]), let url = URL(string: String(parts[1])) else { return nil }
            return VisibleTab(windowID: id, url: url)
        }
    }

    func closeTab(inWindow windowID: Int) {
        let script = """
        tell application "\(appName)"
            try
                close \(tabProperty) of window id \(windowID)
            end try
        end tell
        """
        _ = run(script)
    }

    private func run(_ source: String) -> String? {
        var error: NSDictionary?
        return NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue
    }
}
