import SwiftUI

@main
struct ShellBuddyApp: App {
    @NSApplicationDelegateAdaptor(CombinedApplicationDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}


import Cocoa
import AXSwift

class CombinedApplicationDelegate: NSObject, NSApplicationDelegate {
    let terminalContentDelegate = ApplicationDelegate()
    let windowPositionDelegate = WindowManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        terminalContentDelegate.applicationDidFinishLaunching(notification)
        windowPositionDelegate.applicationDidFinishLaunching(notification)
    }
}


