import AppKit
import Combine
import SwiftUI

@MainActor
final class FloatNoteController: NSObject, NSWindowDelegate {
    private let model = FloatNoteModel()
    private let hotKeyMonitor = HotKeyMonitor()
    private let window: NSWindow
    private var localMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

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
        registerToggleHotKey()
    }

    func showWindow() {
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
        model.requestEditorFocus()
    }

    private func hideWindow() {
        model.persistImmediately()
        window.orderOut(nil)
    }

    private func toggleWindow() {
        if window.isVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }

    private func configureWindow() {
        let rootView = FloatNoteRootView(
            model: model,
            onClose: { [weak self] in
                self?.hideWindow()
            }
        )

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

    private func registerToggleHotKey() {
        hotKeyMonitor.register(shortcut: model.preferences.toggleShortcut) { [weak self] in
            Task { @MainActor in
                self?.toggleWindow()
            }
        }
    }

    private func resizeWindow(to size: NSSize) {
        let referenceFrame = window.isVisible ? window.frame : (activeScreen()?.visibleFrame ?? window.frame)
        let newOrigin = NSPoint(
            x: referenceFrame.midX - size.width / 2,
            y: referenceFrame.midY - size.height / 2
        )
        let newFrame = NSRect(origin: newOrigin, size: size)
        window.setFrame(newFrame, display: true, animate: true)
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
}
