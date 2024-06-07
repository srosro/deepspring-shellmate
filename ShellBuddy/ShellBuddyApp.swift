//
//  ShellBuddyApp.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 15/05/24.
//

import SwiftUI

@main
struct ShellBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // This prevents SwiftUI from creating another window
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var viewModel: AppViewModel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered, defer: false)
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.title = "ShellBuddy" 

        viewModel = AppViewModel(appWindow: window)
        window.contentView = NSHostingView(rootView: ContentView(viewModel: viewModel))
        window.makeKeyAndOrderFront(nil)

        // Minimize the window immediately after launching
        //DispatchQueue.main.async {
        //    self.window.miniaturize(nil)
        //}
    }
}

