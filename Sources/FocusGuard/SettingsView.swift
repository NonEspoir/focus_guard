import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        TabView {
            AppsTab().tabItem { Label("App", systemImage: "app.badge") }
            DomainsTab().tabItem { Label("网站", systemImage: "globe") }
            OptionsTab().tabItem { Label("选项", systemImage: "slider.horizontal.3") }
            HistoryTab().tabItem { Label("记录", systemImage: "list.bullet.rectangle") }
        }
        .frame(width: 480, height: 420)
        .padding()
    }
}

/// 硬核会话期间只能收紧规则：黑名单只能加，白名单只能删，不能放宽选项。
@MainActor private var locked: Bool { Store.shared.isHardLocked }
@MainActor private func canAdd(_ mode: ListMode) -> Bool { !locked || mode == .blacklist }
@MainActor private func canRemove(_ mode: ListMode) -> Bool { !locked || mode == .whitelist }

private struct LockedHint: View {
    var mode: ListMode?

    var body: some View {
        if locked {
            Label(text, systemImage: "lock.fill").font(.caption).foregroundStyle(.orange)
        }
    }

    private var text: String {
        switch mode {
        case .blacklist: "硬核专注中：黑名单只能添加，不能删除"
        case .whitelist: "硬核专注中：白名单只能删除，不能添加"
        case nil: "硬核专注中：不能放宽选项"
        }
    }
}

/// 名单模式切换。切换后另一份名单的数据保留，只是隐藏且不生效。专注期间（任何模式）都不能切换。
private struct ModePicker: View {
    @Binding var mode: ListMode
    let blacklistHint: String
    let whitelistHint: String

    private var inSession: Bool { Store.shared.activeSession != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("模式", selection: $mode) {
                ForEach(ListMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 160)
            .disabled(inSession)
            .frame(maxWidth: .infinity)
            if inSession {
                Label("专注中不能切换黑名单 / 白名单", systemImage: "lock.fill")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(mode == .blacklist ? blacklistHint : whitelistHint)
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct AppsTab: View {
    private var store: Store { Store.shared }

    var body: some View {
        @Bindable var store = store
        let mode = store.config.appListMode
        VStack(alignment: .leading) {
            ModePicker(mode: $store.config.appListMode,
                       blacklistHint: "专注时只拦截下面列出的 App。",
                       whitelistHint: "专注时只允许下面列出的 App，其它一律拦截（访达、系统设置始终允许）。用白名单时记得把浏览器也加进来。")
            LockedHint(mode: mode)
            List {
                ForEach(store.config.apps) { app in
                    HStack {
                        Image(nsImage: icon(for: app.bundleID)).resizable().frame(width: 20, height: 20)
                        Text(app.name)
                        Spacer()
                        Text(app.bundleID).font(.caption).foregroundStyle(.secondary)
                        if canRemove(mode) {
                            Button(role: .destructive) {
                                store.config.apps.removeAll { $0 == app }
                            } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            HStack {
                Button("从「应用程序」添加…", action: pickApps)
                    .disabled(!canAdd(mode))
                Menu("从运行中的 App 添加") {
                    ForEach(runningApps, id: \.bundleIdentifier) { app in
                        Button(app.localizedName ?? app.bundleIdentifier ?? "") {
                            add(bundleID: app.bundleIdentifier, name: app.localizedName)
                        }
                    }
                }
                .fixedSize()
                .disabled(!canAdd(mode))
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
              !store.config.apps.contains(where: { $0.bundleID == bundleID }) else { return }
        store.config.apps.append(AppEntry(bundleID: bundleID, name: name ?? bundleID))
    }
}

private struct DomainsTab: View {
    @State private var input = ""
    private var store: Store { Store.shared }

    var body: some View {
        @Bindable var store = store
        let mode = store.config.domainListMode
        VStack(alignment: .leading) {
            ModePicker(mode: $store.config.domainListMode,
                       blacklistHint: "专注时只拦截下面列出的网站。",
                       whitelistHint: "专注时只允许下面列出的网站，其它网页一律拦截（localhost 始终允许）。")
            LockedHint(mode: mode)
            List {
                ForEach(store.config.domains, id: \.self) { domain in
                    HStack {
                        Text(domain)
                        Spacer()
                        if canRemove(mode) {
                            Button(role: .destructive) {
                                store.config.domains.removeAll { $0 == domain }
                            } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            HStack {
                TextField(mode == .blacklist ? "例如 bilibili.com（会同时匹配子域名）" : "例如 github.com（会同时匹配子域名）",
                          text: $input)
                    .onSubmit(add)
                    .disabled(!canAdd(mode))
                Button("添加", action: add)
                    .disabled(!canAdd(mode))
            }
            Text("支持 Safari、Chrome、Edge、Brave、Arc。首次拦截时系统会询问是否允许控制浏览器，请点「允许」。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func add() {
        guard canAdd(store.config.domainListMode), let domain = normalizeDomain(input) else { return }
        if !store.config.domains.contains(domain) {
            store.config.domains.append(domain)
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
            Section("外观") {
                Toggle("在程序坞中显示图标", isOn: $store.config.showInDock)
                    .onChange(of: store.config.showInDock) { WindowManager.shared.applyDockVisibility() }
                Text("关闭时只在菜单栏显示。打开后可以点程序坞图标呼出主面板。")
                    .font(.caption).foregroundStyle(.secondary)
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
