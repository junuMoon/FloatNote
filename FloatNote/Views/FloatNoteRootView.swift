import SwiftUI

struct FloatNoteRootView: View {
    @ObservedObject var model: FloatNoteModel
    let onClose: () -> Void

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                topBar

                Divider()
                    .overlay(Color.floatLine.opacity(0.75))

                editorSection

                Divider()
                    .overlay(Color.floatLine.opacity(0.75))

                footer
            }
        }
        .frame(minWidth: 640, minHeight: 460)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.floatPulse.opacity(model.isLeftBoundaryPulsing ? 0.92 : 0),
                            Color.floatPulse.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6)
                .animation(.easeOut(duration: 0.18), value: model.isLeftBoundaryPulsing)
        }
    }

    private var backgroundLayer: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.floatPaperTop, Color.floatPaperBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.floatLineStrong, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(Color.white.opacity(0.26))
                    .frame(width: 180, height: 180)
                    .blur(radius: 30)
                    .offset(x: 60, y: -70)
            }
            .shadow(color: .black.opacity(0.12), radius: 22, y: 16)
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("FloatNote")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .tracking(-0.6)

                Text("resume, write, move, close")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(Color.floatMuted)
                    .textCase(.uppercase)
            }

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                capsuleButton("Older", disabled: model.currentIndex == 0) {
                    model.goToPreviousNote()
                }

                Text(model.positionLabel)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Color.floatMuted)
                    .frame(minWidth: 72)

                capsuleButton("Newer") {
                    model.goToNextNote()
                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                Text(model.saveState.label.uppercased())
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Color.floatMuted)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.55))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.floatLine, lineWidth: 1)
                    )

                capsuleButton("Settings") {
                    model.isSettingsPresented = true
                }

                capsuleButton("Close") {
                    onClose()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var editorSection: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Last viewed note")
                    Spacer()
                    Text("live markdown styling")
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(Color.floatMuted)
                .textCase(.uppercase)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)

                Divider()
                    .overlay(Color.floatLine.opacity(0.6))

                ZStack(alignment: .topLeading) {
                    if let note = model.currentNote, note.body.isEmpty {
                        Text("제목 없이 바로 입력 시작")
                            .font(.system(size: 20, weight: .regular, design: .serif))
                            .foregroundStyle(Color.floatMuted.opacity(0.8))
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                    }

                    MarkdownTextEditor(
                        text: Binding(
                            get: { model.currentNote?.body ?? "" },
                            set: { model.updateCurrentBody($0) }
                        ),
                        focusToken: model.focusNonce
                    )
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                }
                .background(Color.clear)
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.42))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.floatLine.opacity(0.65), lineWidth: 1)
                    )
            )
            .padding(18)

            if model.isOnboardingPresented {
                overlayBackdrop(
                    card: AnyView(onboardingCard)
                )
            }

            if model.isSettingsPresented {
                overlayBackdrop(
                    dimmed: true,
                    card: AnyView(settingsCard)
                )
            }
        }
    }

    private var onboardingCard: some View {
        overlayCard(width: 430) {
            VStack(alignment: .leading, spacing: 14) {
                eyebrow("First run")

                Text("FloatNote 시작하기")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .tracking(-0.8)

                VStack(alignment: .leading, spacing: 10) {
                    Text("1. \(model.preferences.toggleShortcut.label) 로 창 열기")
                    Text("2. 마지막으로 본 노트에서 바로 입력")
                    Text("3. \(model.preferences.nextShortcut.label) / \(model.preferences.previousShortcut.label) 로 이동")
                }
                .font(.system(size: 16))
                .foregroundStyle(Color.floatMuted)

                Text("기본 단축키는 설정에서 바꿀 수 있습니다.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.floatMuted)

                Button("시작하기") {
                    model.dismissOnboarding()
                }
                .buttonStyle(FilledPillButtonStyle())
            }
        }
    }

    private var settingsCard: some View {
        overlayCard(width: 470) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        eyebrow("Preferences")

                        Text("Settings")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .tracking(-0.8)
                    }

                    Spacer()

                    capsuleButton("Done") {
                        model.dismissSettings()
                    }
                }

                settingsGroup(
                    title: "Global toggle",
                    value: model.preferences.toggleShortcut.label,
                    isRecording: model.recordingField == .toggle,
                    actionTitle: model.recordingField == .toggle ? "Press shortcut" : "Capture"
                ) {
                    model.setRecordingField(.toggle)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Note navigation")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(Color.floatMuted)
                        .textCase(.uppercase)

                    settingsRow(
                        value: model.preferences.previousShortcut.label,
                        isRecording: model.recordingField == .previous,
                        actionTitle: model.recordingField == .previous ? "Press shortcut" : "Capture older"
                    ) {
                        model.setRecordingField(.previous)
                    }

                    settingsRow(
                        value: model.preferences.nextShortcut.label,
                        isRecording: model.recordingField == .next,
                        actionTitle: model.recordingField == .next ? "Press shortcut" : "Capture newer"
                    ) {
                        model.setRecordingField(.next)
                    }

                    Text("Toggle hotkey is global. Older / newer shortcuts apply only while the window is open.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.floatMuted)
                }
                .padding(16)
                .background(settingsCardBackground)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Window size")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(Color.floatMuted)
                        .textCase(.uppercase)

                    Picker("Window size", selection: Binding(
                        get: { model.preferences.windowSize },
                        set: { model.updateWindowSize($0) }
                    )) {
                        ForEach(WindowSizePreset.allCases) { preset in
                            Text(preset.label).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(16)
                .background(settingsCardBackground)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("Created \(formatted(date: model.currentNote?.createdAt))")
            Spacer()
            Text("Updated \(formatted(date: model.currentNote?.updatedAt))")
        }
        .font(.system(size: 13, weight: .regular, design: .rounded))
        .foregroundStyle(Color.floatMuted)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func overlayBackdrop(dimmed: Bool = false, card: AnyView) -> some View {
        ZStack {
            if dimmed {
                Color.black.opacity(0.08)
                    .ignoresSafeArea()
            }

            card
        }
        .padding(24)
    }

    private func overlayCard<Content: View>(width: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(24)
            .frame(maxWidth: width, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.floatCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.floatLineStrong, lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.14), radius: 18, y: 12)
    }

    private func settingsGroup(
        title: String,
        value: String,
        isRecording: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(Color.floatMuted)
                .textCase(.uppercase)

            settingsRow(value: value, isRecording: isRecording, actionTitle: actionTitle, action: action)
        }
        .padding(16)
        .background(settingsCardBackground)
    }

    private func settingsRow(
        value: String,
        isRecording: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.floatInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.75))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.floatLine, lineWidth: 1)
                        )
                )

            Button(actionTitle, action: action)
                .buttonStyle(CapsuleOutlineButtonStyle(active: isRecording))
        }
    }

    private var settingsCardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.floatPanel)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.floatLine.opacity(0.85), lineWidth: 1)
            )
    }

    private func capsuleButton(
        _ title: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .buttonStyle(CapsuleOutlineButtonStyle())
            .disabled(disabled)
            .opacity(disabled ? 0.42 : 1)
    }

    private func eyebrow(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .tracking(1.1)
            .foregroundStyle(Color.floatMuted)
            .textCase(.uppercase)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.floatPanel)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.floatLine, lineWidth: 1)
                    )
            )
    }

    private func formatted(date: Date?) -> String {
        guard let date else { return "-" }
        return Self.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

private struct CapsuleOutlineButtonStyle: ButtonStyle {
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(active ? Color.white : Color.floatInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(active ? Color.floatInk : Color.white.opacity(configuration.isPressed ? 0.94 : 0.72))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.floatLineStrong, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct FilledPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.floatInk.opacity(configuration.isPressed ? 0.88 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private extension Color {
    static let floatPaperTop = Color(red: 0.97, green: 0.95, blue: 0.91)
    static let floatPaperBottom = Color(red: 0.93, green: 0.90, blue: 0.84)
    static let floatCard = Color(red: 0.98, green: 0.97, blue: 0.94)
    static let floatPanel = Color(red: 0.96, green: 0.94, blue: 0.89)
    static let floatLine = Color(red: 0.53, green: 0.46, blue: 0.36).opacity(0.18)
    static let floatLineStrong = Color(red: 0.49, green: 0.41, blue: 0.31).opacity(0.28)
    static let floatMuted = Color(red: 0.46, green: 0.41, blue: 0.35)
    static let floatInk = Color(red: 0.14, green: 0.12, blue: 0.10)
    static let floatPulse = Color(red: 0.34, green: 0.28, blue: 0.22)
}
