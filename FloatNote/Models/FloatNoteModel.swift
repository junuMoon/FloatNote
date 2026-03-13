import AppKit
import Carbon
import Foundation

struct NoteRecord: Codable, Equatable, Identifiable {
    let id: UUID
    var body: String
    let createdAt: Date
    var updatedAt: Date

    static func seedNotes() -> [NoteRecord] {
        let now = Date()

        return [
            NoteRecord(
                id: UUID(),
                body: [
                    "# FloatNote principles",
                    "",
                    "> 작업 위에 잠깐 뜨는 레이어",
                    "",
                    "- 마지막으로 본 노트부터 이어쓰기",
                    "- `Created / Updated` 는 하단 고정",
                    "- **Markdown** 이 입력 중에도 바로 살아난다",
                ].joined(separator: "\n"),
                createdAt: now.addingTimeInterval(-36 * 60 * 60),
                updatedAt: now.addingTimeInterval(-30 * 60 * 60)
            ),
            NoteRecord(
                id: UUID(),
                body: [
                    "# Native rewrite",
                    "",
                    "- SwiftUI + AppKit",
                    "- global toggle hotkey",
                    "- floating macOS window",
                    "- [project.yml](FloatNote.xcodeproj)",
                    "",
                    "```swift",
                    "let mode = \"native\"",
                    "print(mode)",
                    "```",
                ].joined(separator: "\n"),
                createdAt: now.addingTimeInterval(-24 * 60 * 60),
                updatedAt: now.addingTimeInterval(-16 * 60 * 60)
            ),
            NoteRecord(
                id: UUID(),
                body: [
                    "# Today",
                    "",
                    "- Glacier 같은 구조로 프로젝트 정리",
                    "- floating window shell 구현",
                    "- next note creates a fresh note",
                    "- *inline markdown styling* 추가",
                ].joined(separator: "\n"),
                createdAt: now.addingTimeInterval(-6 * 60 * 60),
                updatedAt: now.addingTimeInterval(-1 * 60 * 60)
            ),
        ]
    }
}

enum WindowSizePreset: String, Codable, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    var size: NSSize {
        switch self {
        case .small: NSSize(width: 640, height: 460)
        case .medium: NSSize(width: 720, height: 520)
        case .large: NSSize(width: 820, height: 600)
        }
    }
}

struct Preferences: Codable, Equatable {
    var toggleShortcut: KeyShortcut = .defaultToggle
    var previousShortcut: KeyShortcut = .defaultPrevious
    var nextShortcut: KeyShortcut = .defaultNext
    var windowSize: WindowSizePreset = .medium
}

enum ShortcutField: String, Codable {
    case toggle
    case previous
    case next
}

enum SaveState {
    case saving
    case saved

    var label: String {
        switch self {
        case .saving: "Saving"
        case .saved: "Saved"
        }
    }
}

struct PersistedSnapshot: Codable {
    var notes: [NoteRecord]
    var currentNoteID: UUID
    var hasSeenOnboarding: Bool
    var preferences: Preferences
}

@MainActor
final class FloatNoteModel: ObservableObject {
    @Published private(set) var notes: [NoteRecord]
    @Published private(set) var currentNoteID: UUID
    @Published var hasSeenOnboarding: Bool
    @Published var isOnboardingPresented: Bool
    @Published var isSettingsPresented = false
    @Published var recordingField: ShortcutField?
    @Published var preferences: Preferences
    @Published var saveState: SaveState = .saved
    @Published var isLeftBoundaryPulsing = false
    @Published var focusNonce = UUID()

    private let persistence = StatePersistence()
    private var saveTask: Task<Void, Never>?

    init() {
        if let snapshot = persistence.load() {
            let resolvedNotes = snapshot.notes.isEmpty ? NoteRecord.seedNotes() : snapshot.notes
            let resolvedCurrentID = resolvedNotes.contains(where: { $0.id == snapshot.currentNoteID })
                ? snapshot.currentNoteID
                : resolvedNotes.last!.id

            notes = resolvedNotes
            currentNoteID = resolvedCurrentID
            hasSeenOnboarding = snapshot.hasSeenOnboarding
            isOnboardingPresented = !snapshot.hasSeenOnboarding
            preferences = snapshot.preferences
        } else {
            let seed = NoteRecord.seedNotes()
            notes = seed
            currentNoteID = seed.last!.id
            hasSeenOnboarding = false
            isOnboardingPresented = true
            preferences = Preferences()
        }
    }

    var currentIndex: Int {
        notes.firstIndex(where: { $0.id == currentNoteID }) ?? 0
    }

    var currentNote: NoteRecord? {
        guard notes.indices.contains(currentIndex) else { return nil }
        return notes[currentIndex]
    }

    var positionLabel: String {
        "\(currentIndex + 1) / \(notes.count)"
    }

    var currentTitle: String {
        let fallback = "FloatNote"
        guard let body = currentNote?.body else { return fallback }

        for rawLine in body.split(whereSeparator: \.isNewline) {
            let line = rawLine
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(
                    of: #"^(#{1,6}\s*|[-*+]\s+|>\s*|\d+\.\s+|`+)"#,
                    with: "",
                    options: .regularExpression
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !line.isEmpty else { continue }
            return String(line.prefix(28))
        }

        return fallback
    }

    func updateCurrentBody(_ body: String) {
        guard notes.indices.contains(currentIndex) else { return }

        notes[currentIndex].body = body
        notes[currentIndex].updatedAt = Date()
        scheduleSave()
    }

    func goToPreviousNote() {
        guard currentIndex > 0 else {
            pulseLeftBoundary()
            return
        }

        currentNoteID = notes[currentIndex - 1].id
        requestEditorFocus()
        persistImmediately()
    }

    func goToNextNote() {
        if currentIndex == notes.count - 1 {
            createFreshNote()
            return
        }

        currentNoteID = notes[currentIndex + 1].id
        requestEditorFocus()
        persistImmediately()
    }

    func createFreshNote() {
        let timestamp = Date()
        let note = NoteRecord(
            id: UUID(),
            body: "",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        notes.append(note)
        currentNoteID = note.id
        requestEditorFocus()
        persistImmediately()
    }

    func dismissOnboarding() {
        hasSeenOnboarding = true
        isOnboardingPresented = false
        requestEditorFocus()
        persistImmediately()
    }

    func dismissSettings() {
        recordingField = nil
        isSettingsPresented = false
        requestEditorFocus()
        persistImmediately()
    }

    func setRecordingField(_ field: ShortcutField?) {
        recordingField = field
    }

    func updateWindowSize(_ preset: WindowSizePreset) {
        preferences.windowSize = preset
        persistImmediately()
    }

    func captureShortcut(from event: NSEvent) -> Bool {
        guard let field = recordingField else {
            return false
        }

        if event.keyCode == UInt16(kVK_Escape) {
            recordingField = nil
            return true
        }

        guard let shortcut = KeyShortcut.from(event: event) else {
            return true
        }

        switch field {
        case .toggle:
            preferences.toggleShortcut = shortcut
        case .previous:
            preferences.previousShortcut = shortcut
        case .next:
            preferences.nextShortcut = shortcut
        }

        recordingField = nil
        persistImmediately()
        return true
    }

    func handleLocalKeyDown(_ event: NSEvent, hideWindow: () -> Void) -> Bool {
        if recordingField != nil {
            return captureShortcut(from: event)
        }

        if event.keyCode == UInt16(kVK_Escape) {
            if isSettingsPresented {
                dismissSettings()
            } else if isOnboardingPresented {
                dismissOnboarding()
            } else {
                persistImmediately()
                hideWindow()
            }

            return true
        }

        if isSettingsPresented || isOnboardingPresented {
            return false
        }

        if preferences.previousShortcut.matches(event) {
            goToPreviousNote()
            return true
        }

        if preferences.nextShortcut.matches(event) {
            goToNextNote()
            return true
        }

        return false
    }

    func requestEditorFocus() {
        focusNonce = UUID()
    }

    func persistImmediately() {
        saveTask?.cancel()
        saveState = .saved
        persistence.save(makeSnapshot())
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveState = .saving

        let snapshot = makeSnapshot()

        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled else { return }
            self?.persistence.save(snapshot)
            self?.saveState = .saved
        }
    }

    private func makeSnapshot() -> PersistedSnapshot {
        PersistedSnapshot(
            notes: notes,
            currentNoteID: currentNoteID,
            hasSeenOnboarding: hasSeenOnboarding,
            preferences: preferences
        )
    }

    private func pulseLeftBoundary() {
        isLeftBoundaryPulsing = true

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            self?.isLeftBoundaryPulsing = false
        }
    }
}
