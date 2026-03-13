import SwiftUI

@main
struct FloatNoteApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: FloatNoteController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = FloatNoteController()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller?.showWindow()
        return true
    }
}
