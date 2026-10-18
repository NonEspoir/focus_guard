import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        TabView {
            AppsTab().tabItem { Label("黑名单", systemImage: "app.badge") }
            DomainsTab().tabItem { Label("网站", systemImage: "globe") }
            OptionsTab().tabItem { Label("选项", systemImage: "slider.horizontal.3") }
            HistoryTab().tabItem { Label("记录", systemImage: "list.bullet.rectangle") }
        }
        .frame(width: 480, height: 420)
        .padding()
    }
}

/// 硬核会话期间只能加规则、不能删规则或放宽选项。
@MainActor private var locked: Bool { Store.shared.isHardLocked }

private struct LockedHint: View {
    var body: some View {
        if locked {
            Label("硬核专注中：只能添加，不能删除或放宽", systemImage: "lock.fill")
                .font(.caption).foregroundStyle(.orange)
        }
    }
}

private struct AppsTab: View {
    private var store: Store { Store.shared }

    var body: some View {
        VStack(alignment: .leading) {
            LockedHint()
            List {
                ForEach(store.config.blockedApps) { app in
                    HStack {
                        Image(nsImage: icon(for: app.bundleID)).resizable().frame(width: 20, height: 20)
                        Text(app.name)
                        Spacer()
                        Text(app.bundleID).font(.caption).foregroundStyle(.secondary)
                        if !locked {
                            Button(role: .destructive) {
                                store.config.blockedApps.removeAll { $0 == app }
                            } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            HStack {
                Button("从「应用程序」添加…", action: pickApps)
                Menu("从运行中的 App 添加") {
                    ForEach(runningApps, id: \.bundleIdentifier) { app in
                        Button(app.localizedName ?? app.bundleIdentifier ?? "") {
                            add(bundleID: app.bundleIdentifier, name: app.localizedName)
                        }
                    }
                }
                .fixedSize()
            }
        }
    }

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func icon(for bundleID: String) -> NSImage {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private func pickApps() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            let bundle = Bundle(url: url)
            let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            add(bundleID: bundle?.bundleIdentifier, name: name)
        }
    }

    private func add(bundleID: String?, name: String?) {
        guard let bundleID, bundleID != Bundle.main.bundleIdentifier,
              !store.config.blockedApps.contains(where: { $0.bundleID == bundleID }) else { return }
        store.config.blockedApps.append(BlockedApp(bundleID: bundleID, name: name ?? bundleID))
    }
}

private struct DomainsTab: View {
    @State private var input = ""
    private var store: Store { Store.shared }

    var body: some View {
        VStack(alignment: .leading) {
            LockedHint()
            List {
                ForEach(store.config.blockedDomains, id: \.self) { domain in
                    HStack {
                        Text(domain)
                        Spacer()
                        if !locked {
                            Button(role: .destructive) {
                                store.config.blockedDomains.removeAll { $0 == domain }
                            } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            HStack {
                TextField("例如 bilibili.com（会同时匹配子域名）", text: $input)
                    .onSubmit(add)
                Button("添加", action: add)
            }
            Text("支持 Safari、Chrome、Edge、Brave、Arc。首次拦截时系统会询问是否允许控制浏览器，请点「允许」。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func add() {
        guard let domain = normalizeDomain(input) else { return }
        if !store.config.blockedDomains.contains(domain) {
            store.config.blockedDomains.append(domain)
        }
        input = ""
    }
}

private struct OptionsTab: View {
    private var store: Store { Store.shared }

    var body: some View {
        @Bindable var store = store
        Form {
            LockedHint()
            Section("提醒模式") {
                Stepper("放行前需等待 \(store.config.gentleWaitSeconds) 秒",
                        value: $store.config.gentleWaitSeconds, in: (locked ? store.config.gentleWaitSeconds : 0)...120, step: 5)
                Stepper("每次放行 \(store.config.allowMinutes) 分钟",
                        value: $store.config.allowMinutes, in: 1...(locked ? store.config.allowMinutes : 60))
            }
            Section("开机启动") {
                Text("系统设置 → 通用 → 登录项 → 添加 FocusGuard.app")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct HistoryTab: View {
    private var store: Store { Store.shared }

    var body: some View {
        let events = store.events.reversed().prefix(200)
        if events.isEmpty {
            Text("还没有拦截记录").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(Array(events)) { event in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(event.target).bold()
                        Text(event.action).foregroundStyle(.secondary)
                        Spacer()
                        Text(event.date, format: .dateTime.month().day().hour().minute())
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let reason = event.reason {
                        Text("理由：\(reason)").font(.caption)
                    }
                }
            }
        }
    }
}
