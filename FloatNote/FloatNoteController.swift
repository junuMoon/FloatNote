import AppKit
import ApplicationServices
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
        window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
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
        ScreenTargetResolver.resolve(
            focusedContextScreen: focusedApplicationScreen(),
            mainScreen: NSScreen.main,
            mouseScreen: mouseScreen(),
            windowScreen: window.isVisible ? window.screen : nil,
            allScreens: NSScreen.screens
        )
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

        application.activate(options: [.activateAllWindows])
    }

    private func focusedApplicationScreen() -> NSScreen? {
        guard let processIdentifier = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let frontmostWindowFrame = frontmostWindowFrame(for: processIdentifier) else {
            return nil
        }

        let center = CGPoint(x: frontmostWindowFrame.midX, y: frontmostWindowFrame.midY)
        return screen(containingQuartzPoint: center)
    }

    private func mouseScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
    }

    private func frontmostWindowFrame(for processIdentifier: pid_t) -> CGRect? {
        guard let windowInfoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        return FrontmostWindowResolver.frame(for: processIdentifier, in: windowInfoList)
    }

    private func screen(containingQuartzPoint point: CGPoint) -> NSScreen? {
        guard let displayID = DisplayScreenMatcher.displayID(containing: point) else {
            return nil
        }

        let screensByDisplayID: [(CGDirectDisplayID, NSScreen)] = NSScreen.screens.compactMap { screen in
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }

            return (screenNumber.uint32Value, screen)
        }

        return DisplayScreenMatcher.match(displayID: displayID, screens: screensByDisplayID)
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

struct ScreenTargetResolver {
    static func resolve<Screen>(
        focusedContextScreen: Screen?,
        mainScreen: Screen?,
        mouseScreen: Screen?,
        windowScreen: Screen?,
        allScreens: [Screen]
    ) -> Screen? {
        focusedContextScreen ?? mainScreen ?? mouseScreen ?? windowScreen ?? allScreens.first
    }
}

struct FrontmostWindowResolver {
    static func frame(for processIdentifier: pid_t, in windowInfoList: [[String: Any]]) -> CGRect? {
        for windowInfo in windowInfoList {
            guard matches(processIdentifier: processIdentifier, windowInfo: windowInfo),
                  let bounds = bounds(from: windowInfo) else {
                continue
            }

            return bounds
        }

        return nil
    }

    private static func matches(processIdentifier: pid_t, windowInfo: [String: Any]) -> Bool {
        guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int,
              ownerPID == Int(processIdentifier),
              let layer = windowInfo[kCGWindowLayer as String] as? Int,
              layer == 0 else {
            return false
        }

        if let isOnscreen = windowInfo[kCGWindowIsOnscreen as String] as? Bool, !isOnscreen {
            return false
        }

        if let alpha = windowInfo[kCGWindowAlpha as String] as? Double, alpha <= 0 {
            return false
        }

        return true
    }

    private static func bounds(from windowInfo: [String: Any]) -> CGRect? {
        guard let rawBounds = windowInfo[kCGWindowBounds as String] else {
            return nil
        }

        let boundsReference = rawBounds as CFTypeRef
        guard CFGetTypeID(boundsReference) == CFDictionaryGetTypeID(),
              let bounds = CGRect(dictionaryRepresentation: boundsReference as! CFDictionary),
              bounds.width > 0,
              bounds.height > 0 else {
            return nil
        }

        return bounds
    }
}

struct DisplayScreenMatcher {
    static func displayID(containing point: CGPoint) -> CGDirectDisplayID? {
        var displayID = CGDirectDisplayID()
        var displayCount: UInt32 = 0
        let status = CGGetDisplaysWithPoint(point, 1, &displayID, &displayCount)

        guard status == .success, displayCount > 0 else {
            return nil
        }

        return displayID
    }

    static func match<Screen>(displayID: CGDirectDisplayID, screens: [(CGDirectDisplayID, Screen)]) -> Screen? {
        screens.first(where: { $0.0 == displayID })?.1
    }
}
