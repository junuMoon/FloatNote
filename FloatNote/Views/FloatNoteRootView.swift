import SwiftUI

struct FloatNoteRootView: View {
    @ObservedObject var model: FloatNoteModel
    let onClose: () -> Void

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                documentSurface
                footer
            }
            .padding(.top, 8)
        }
        .frame(minWidth: 640, minHeight: 460)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.floatPulse.opacity(model.isLeftBoundaryPulsing ? 0.9 : 0),
                            Color.floatPulse.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 5)
                .animation(.easeOut(duration: 0.16), value: model.isLeftBoundaryPulsing)
        }
    }

    private var backgroundLayer: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.floatCanvasTop, Color.floatCanvasBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.floatLineStrong, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 20, y: 14)
    }

    private var topBar: some View {
        ZStack {
            Text(model.currentTitle)
                .font(.system(size: 12.5, weight: .medium))
                .tracking(0.4)
                .foregroundStyle(Color.floatMuted)
                .lineLimit(1)
                .padding(.horizontal, 120)

            HStack(spacing: 0) {
                Color.clear
                    .frame(width: 86, height: 30)

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    toolbarIcon("chevron.left", disabled: model.currentIndex == 0) {
                        model.goToPreviousNote()
                    }

                    Text(model.positionLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.floatMuted)
                        .frame(minWidth: 46)

                    toolbarIcon("chevron.right") {
                        model.goToNextNote()
                    }

                    toolbarDivider

                    toolbarIcon("slider.horizontal.3") {
                        model.isSettingsPresented = true
                    }

                    toolbarIcon("plus") {
                        model.createFreshNote()
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 2)
        .padding(.bottom, 6)
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color.floatLineStrong.opacity(0.8))
            .frame(width: 1, height: 16)
            .padding(.horizontal, 4)
    }

    private var documentSurface: some View {
        ZStack(alignment: .topLeading) {
            HStack(alignment: .top, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if let note = model.currentNote, note.body.isEmpty, !model.isEditorFocused {
                        Text("제목 없이 바로 입력 시작")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(Color.floatMuted.opacity(0.78))
                            .padding(.leading, 4)
                            .padding(.top, 14)
                    }

                    MarkdownTextEditor(
                        text: Binding(
                            get: { model.currentNote?.body ?? "" },
                            set: { model.updateCurrentBody($0) }
                        ),
                        focusToken: model.focusNonce,
                        onFocusChange: { isFocused in
                            model.setEditorFocused(isFocused)
                        }
                    )
                }
                .frame(maxWidth: 620, maxHeight: .infinity, alignment: .topLeading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
            .padding(.bottom, 14)

            if model.isOnboardingPresented {
                floatingPanel {
                    onboardingCard
                }
            }

            if model.isSettingsPresented {
                floatingPanel(dimmed: true) {
                    settingsCard
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var onboardingCard: some View {
        overlayCard(width: 250) {
            VStack(alignment: .leading, spacing: 12) {
                Text("첫 시작")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.floatMuted)
                    .textCase(.uppercase)

                VStack(alignment: .leading, spacing: 7) {
                    Text("\(model.preferences.toggleShortcut.label) 로 열기")
                    Text("바로 입력")
                    Text("앞뒤 노트 이동")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.floatInk)

                Button("확인") {
                    model.dismissOnboarding()
                }
                .buttonStyle(PopoverActionButtonStyle())
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var settingsCard: some View {
        overlayCard(width: 340) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Shortcuts")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.floatInk)

                    Spacer()

                    Button("Done") {
                        model.dismissSettings()
                    }
                    .buttonStyle(PopoverActionButtonStyle())
                }

                compactSettingRow(
                    title: "Toggle",
                    value: model.preferences.toggleShortcut.label,
                    isRecording: model.recordingField == .toggle,
                    actionTitle: model.recordingField == .toggle ? "Press" : "Set"
                ) {
                    model.setRecordingField(.toggle)
                }

                compactSettingRow(
                    title: "Older",
                    value: model.preferences.previousShortcut.label,
                    isRecording: model.recordingField == .previous,
                    actionTitle: model.recordingField == .previous ? "Press" : "Set"
                ) {
                    model.setRecordingField(.previous)
                }

                compactSettingRow(
                    title: "Newer",
                    value: model.preferences.nextShortcut.label,
                    isRecording: model.recordingField == .next,
                    actionTitle: model.recordingField == .next ? "Press" : "Set"
                ) {
                    model.setRecordingField(.next)
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("Window")
                        .font(.system(size: 11, weight: .semibold))
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
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("Created \(formatted(date: model.currentNote?.createdAt))")

            Spacer(minLength: 0)

            Text("Updated \(formatted(date: model.currentNote?.updatedAt))")
        }
        .font(.system(size: 10.5, weight: .regular))
        .foregroundStyle(Color.floatMeta)
        .padding(.horizontal, 28)
        .padding(.bottom, 14)
        .padding(.top, 4)
    }

    private func floatingPanel<Content: View>(
        dimmed: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            if dimmed {
                Color.black.opacity(0.04)
                    .ignoresSafeArea()
                    .onTapGesture {
                        model.dismissSettings()
                    }
            }

            content()
                .padding(.top, 2)
                .padding(.trailing, 24)
        }
    }

    private func overlayCard<Content: View>(width: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(width: width, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.floatCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.floatLineStrong, lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.09), radius: 16, y: 10)
    }

    private func compactSettingRow(
        title: String,
        value: String,
        isRecording: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.floatMuted)
                .frame(width: 54, alignment: .leading)

            Text(value)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.floatInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.82))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.floatLine, lineWidth: 1)
                        )
                )

            Button(actionTitle, action: action)
                .buttonStyle(InlineActionButtonStyle(active: isRecording))
        }
    }

    private func toolbarIcon(
        _ systemName: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(ToolbarIconButtonStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.32 : 1)
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

private struct ToolbarIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.floatToolbar)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.floatToolbarFill.opacity(configuration.isPressed ? 1 : 0.001))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

private struct InlineActionButtonStyle: ButtonStyle {
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(active ? Color.white : Color.floatInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(active ? Color.floatInk : Color.white.opacity(configuration.isPressed ? 0.92 : 0.74))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.floatLineStrong, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct PopoverActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.floatInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.9 : 0.74))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.floatLineStrong, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private extension Color {
    static let floatCanvasTop = Color(red: 0.95, green: 0.95, blue: 0.94)
    static let floatCanvasBottom = Color(red: 0.93, green: 0.93, blue: 0.92)
    static let floatCard = Color(red: 0.97, green: 0.97, blue: 0.96)
    static let floatToolbarFill = Color.black.opacity(0.06)
    static let floatLine = Color.black.opacity(0.08)
    static let floatLineStrong = Color.black.opacity(0.12)
    static let floatMuted = Color(red: 0.43, green: 0.41, blue: 0.38)
    static let floatMeta = Color.black.opacity(0.28)
    static let floatToolbar = Color.black.opacity(0.56)
    static let floatInk = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let floatPulse = Color(red: 0.22, green: 0.22, blue: 0.22)
}
