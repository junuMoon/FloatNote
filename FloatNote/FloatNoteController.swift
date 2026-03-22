import AppKit
import Combine
import SwiftUI

enum FloatNoteChromeMetrics {
    static let cornerRadius: CGFloat = 28
    static let topBarHeight: CGFloat = 32
    static let trafficLightLeadingInset: CGFloat = 18
    static let trafficLightSpacing: CGFloat = 6
    static let horizontalInset: CGFloat = 24
    static let leadingReservation: CGFloat = 92
    static let trailingToolbarInset: CGFloat = 22
    static let documentHorizontalInset: CGFloat = 28
    static let documentTopInset: CGFloat = 2
    static let footerHorizontalInset: CGFloat = 28
}

@MainActor
final class FloatNoteController: NSObject, NSWindowDelegate {
    private let model = FloatNoteModel()
    private let hotKeyMonitor = HotKeyMonitor()
    private let window: NSWindow
    private var localMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    private var appFocusRestorer = AppFocusRestorer()

    override init() {
        let initialSize = Preferences().windowSize.size
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.window = window
        super.init()

        configureWindow()
        bindModel()
        installLocalMonitor()
    }

    func showWindow() {
        rememberInterruptedApplication()

        let size = model.preferences.windowSize.size
        let screen = activeScreen()
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: size.width, height: size.height)
        let origin = NSPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2
        )
        let frame = NSRect(origin: origin, size: size)

        window.setFrame(frame, display: true)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        scheduleWindowChromeLayout()
        model.requestEditorFocus()
    }

    private func hideWindow() {
        model.persistImmediately()
        window.orderOut(nil)
        restoreInterruptedApplicationFocus()
    }

    private func toggleWindow() {
        if window.isVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }

    private func configureWindow() {
        let rootView = FloatNoteRootView(model: model)

        let hostingController = NSHostingController(rootView: rootView)

        window.contentViewController = hostingController
        window.title = "FloatNote"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.delegate = self
        scheduleWindowChromeLayout()
    }

    private func bindModel() {
        model.$preferences
            .map(\.toggleShortcut)
            .removeDuplicates()
            .sink { [weak self] shortcut in
                self?.hotKeyMonitor.register(shortcut: shortcut) { [weak self] in
                    Task { @MainActor in
                        self?.toggleWindow()
                    }
                }
            }
            .store(in: &cancellables)

        model.$preferences
            .map(\.windowSize)
            .removeDuplicates()
            .sink { [weak self] preset in
                self?.resizeWindow(to: preset.size)
            }
            .store(in: &cancellables)
    }

    private func resizeWindow(to size: NSSize) {
        let referenceFrame = window.isVisible ? window.frame : (activeScreen()?.visibleFrame ?? window.frame)
        let newOrigin = NSPoint(
            x: referenceFrame.midX - size.width / 2,
            y: referenceFrame.midY - size.height / 2
        )
        let newFrame = NSRect(origin: newOrigin, size: size)
        window.setFrame(newFrame, display: true, animate: true)
        scheduleWindowChromeLayout()
    }

    private func activeScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? window.screen ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func installLocalMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            return self.model.handleLocalKeyDown(event) {
                self.hideWindow()
            } ? nil : event
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hideWindow()
        return false
    }

    func windowDidResize(_ notification: Notification) {
        scheduleWindowChromeLayout()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        scheduleWindowChromeLayout()
    }

    private func scheduleWindowChromeLayout() {
        DispatchQueue.main.async { [weak self] in
            self?.layoutWindowChrome()
        }
    }

    private func layoutWindowChrome() {
        let buttonKinds: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        let buttons = buttonKinds.compactMap { window.standardWindowButton($0) }
        guard let firstButton = buttons.first else { return }

        let containerHeight = firstButton.superview?.bounds.height ?? firstButton.frame.height
        let y = max(8, round((containerHeight - firstButton.frame.height) / 2))
        var x = FloatNoteChromeMetrics.trafficLightLeadingInset

        for button in buttons {
            button.setFrameOrigin(NSPoint(x: x, y: y))
            x += button.frame.width + FloatNoteChromeMetrics.trafficLightSpacing
        }
    }

    private func rememberInterruptedApplication() {
        appFocusRestorer.remember(
            frontmostAppPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
            currentAppPID: NSRunningApplication.current.processIdentifier
        )
    }

    private func restoreInterruptedApplicationFocus() {
        guard let targetPID = appFocusRestorer.consumeTargetPID(currentAppPID: NSRunningApplication.current.processIdentifier),
              let application = NSRunningApplication(processIdentifier: targetPID),
              !application.isTerminated else {
            return
        }

        application.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }
}

struct AppFocusRestorer {
    private var previousAppPID: pid_t?

    mutating func remember(frontmostAppPID: pid_t?, currentAppPID: pid_t) {
        guard let frontmostAppPID, frontmostAppPID != currentAppPID else { return }
        previousAppPID = frontmostAppPID
    }

    mutating func consumeTargetPID(currentAppPID: pid_t) -> pid_t? {
        defer { previousAppPID = nil }

        guard let previousAppPID, previousAppPID != currentAppPID else {
            return nil
        }

        return previousAppPID
    }
}
