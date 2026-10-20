import AppKit
import SwiftUI

struct MenuView: View {
    @State private var endingEarly = false
    @State private var endReason = ""
    @State private var minutes = Store.shared.config.defaultMinutes
    @State private var strictness = Store.shared.config.strictness
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var store: Store { Store.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let session = store.activeSession {
                activeSection(session)
            } else {
                startSection
            }

            Divider()
            Text("今天拦截 \(store.todayEvents.filter { $0.target != Store.earlyEndTarget }.count) 次").font(.callout).foregroundStyle(.secondary)

            HStack {
                Button("设置…") { WindowManager.shared.showSettings() }
                Spacer()
                if !store.isHardLocked {
                    Button("退出") { NSApp.terminate(nil) }
                }
            }
        }
        .padding()
        .frame(width: 320)
        .onReceive(timer) { now = $0 }
    }

    private func activeSection(_ session: FocusSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("专注中 · \(session.strictness.shortLabel)").font(.headline)
            Text(formatRemaining(session.endsAt.timeIntervalSince(now)))
                .font(.system(size: 40, weight: .semibold, design: .monospaced))
            switch session.strictness {
            case .gentle:
                if endingEarly {
                    TextField("为什么要提前结束？（至少 4 个字）", text: $endReason)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("继续专注") { resetEnding() }
                        Spacer()
                        Button("确认结束") {
                            store.endSessionEarly(reason: trimmedReason)
                            resetEnding()
                        }
                        .disabled(trimmedReason.count < 4)
                    }
                } else {
                    Button("提前结束…") { endingEarly = true }
                }
            case .hard:
                if !store.hardBreakAvailableToday {
                    Text("今天的提前结束机会已用完").font(.caption).foregroundStyle(.secondary)
                } else if endingEarly {
                    Text("每天只有一次机会，用掉后今天的硬核会话都不能提前结束。").font(.caption)
                    HStack {
                        Button("继续专注") { resetEnding() }
                        Spacer()
                        Button("确认结束", role: .destructive) {
                            store.endSessionEarly(reason: nil)
                            resetEnding()
                        }
                    }
                } else {
                    Button("提前结束（今天还剩 1 次）…") { endingEarly = true }
                }
            }
        }
    }

    static let minuteRange = 1...480

    private func clampMinutes() {
        minutes = min(max(minutes, Self.minuteRange.lowerBound), Self.minuteRange.upperBound)
    }

    private var trimmedReason: String { endReason.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func resetEnding() {
        endingEarly = false
        endReason = ""
    }

    private var startSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("开始专注").font(.headline)
            HStack(spacing: 6) {
                TextField("分钟", value: $minutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 56)
                    .onSubmit(clampMinutes)
                Text("分钟")
                Stepper("", value: $minutes, in: Self.minuteRange, step: 5)
                    .labelsHidden()
                Spacer()
                ForEach([25, 45, 60, 90], id: \.self) { preset in
                    Button("\(preset)") { minutes = preset }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            Picker("模式", selection: $strictness) {
                ForEach(Strictness.allCases) { Text($0.shortLabel).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text(strictness.label).font(.caption).foregroundStyle(.secondary)
            Button {
                clampMinutes()
                store.startSession(minutes: minutes, strictness: strictness)
                store.config.defaultMinutes = minutes
                store.config.strictness = strictness
                Enforcer.shared.tick()
            } label: {
                Text("开始").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.config.hasNoRules)
        }
    }
}
