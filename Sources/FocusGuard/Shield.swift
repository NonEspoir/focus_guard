import AppKit
import SwiftUI

/// 全屏遮罩窗口。
@MainActor
final class ShieldController {
    private var window: NSWindow?

    var isShowing: Bool { window != nil }

    func showPrompt(name: String, waitSeconds: Int, allowMinutes: Int,
                    onBack: @escaping () -> Void, onAllow: @escaping (String) -> Void) {
        present(PromptView(
            name: name, waitSeconds: waitSeconds, allowMinutes: allowMinutes,
            onBack: { [weak self] in self?.dismiss(); onBack() },
            onAllow: { [weak self] reason in self?.dismiss(); onAllow(reason) }
        ))
    }

    func showNotice(title: String, subtitle: String) {
        present(NoticeView(title: title, subtitle: subtitle))
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.dismiss() }
    }

    private func present(_ view: some View) {
        dismiss()
        guard let screen = NSScreen.main else { return }
        let panel = KeyablePanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentView = NSHostingView(rootView: view.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThickMaterial))
        panel.setFrame(screen.frame, display: true)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        window = panel
    }

    private func dismiss() {
        window?.orderOut(nil)
        window = nil
    }
}

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private struct NoticeView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "xmark.octagon.fill").font(.system(size: 64)).foregroundStyle(.red)
            Text(title).font(.largeTitle.bold())
            Text(subtitle).font(.title3).foregroundStyle(.secondary)
        }
    }
}

private struct PromptView: View {
    let name: String
    let waitSeconds: Int
    let allowMinutes: Int
    let onBack: () -> Void
    let onAllow: (String) -> Void

    @State private var remaining: Int
    @State private var reason = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(name: String, waitSeconds: Int, allowMinutes: Int,
         onBack: @escaping () -> Void, onAllow: @escaping (String) -> Void) {
        self.name = name
        self.waitSeconds = waitSeconds
        self.allowMinutes = allowMinutes
        self.onBack = onBack
        self.onAllow = onAllow
        _remaining = State(initialValue: waitSeconds)
    }

    private var canAllow: Bool {
        remaining == 0 && reason.trimmingCharacters(in: .whitespaces).count >= 4
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.fill").font(.system(size: 64)).foregroundStyle(.orange)
            Text("你正在专注中").font(.largeTitle.bold())
            Text("刚刚打开了「\(name)」，真的需要吗？").font(.title3).foregroundStyle(.secondary)

            Button("回去工作", action: onBack)
                .keyboardShortcut(.defaultAction)
                .controlSize(.extraLarge)
                .buttonStyle(.borderedProminent)

            VStack(spacing: 8) {
                TextField("写下需要打开它的理由（至少 4 个字）", text: $reason)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 360)
                Button(remaining > 0 ? "请等待 \(remaining) 秒" : "我确实需要（放行 \(allowMinutes) 分钟）") {
                    onAllow(reason.trimmingCharacters(in: .whitespaces))
                }
                .disabled(!canAllow)
            }
            .padding(.top, 24)
        }
        .onReceive(timer) { _ in
            if remaining > 0 { remaining -= 1 }
        }
    }
}
