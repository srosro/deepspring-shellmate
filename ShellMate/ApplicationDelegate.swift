//
//  ApplicationDelegate.swift
//  ShellMate
//
//  Created by Daniel Delattre on 23/06/24.
//

import Cocoa
import AXSwift
import Mixpanel


class ApplicationDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let terminalContentDelegate = TerminalContentManager()
    let windowPositionDelegate = WindowPositionManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        trackFirstLaunchAfterInstall()
        MixpanelHelper.shared.trackEvent(name: "applicationLaunch")
        
        resizeWindow(width: 400, height: 600)
        checkAccessibilityPermissions()
    }
    
    func resizeWindow(width: CGFloat, height: CGFloat) {
        if let window = NSApplication.shared.windows.first {
            window.setContentSize(NSSize(width: width, height: height))
            window.center() // Optional: to center the window
            self.window = window
        }
    }
    
    func checkAccessibilityPermissions() {
        let isAppTrusted = AccessibilityChecker.isAppTrusted()
        
        if isAppTrusted {
            print("Application is trusted for accessibility.")
        } else {
            print("Application is not trusted for accessibility.")
        }
        
        if isAppTrusted {
            initializeApp()
        } else {
            showSettingsView()
        }
    }

    func initializeApp() {
        showContentView()
        observeTerminalLifecycle()
        terminalContentDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("AppDidFinishLaunching")))
        windowPositionDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("AppDidFinishLaunching")))
        windowPositionDelegate.initializeObserverForRunningTerminal()
        runInstallScript() // Run the install.sh script
    }
    
    func observeTerminalLifecycle() {
        let workspace = NSWorkspace.shared
        
        workspace.notificationCenter.addObserver(windowPositionDelegate,
                                                 selector: #selector(WindowPositionManager.handleTerminalLaunch(_:)),
                                                 name: NSWorkspace.didLaunchApplicationNotification,
                                                 object: nil)
        
        workspace.notificationCenter.addObserver(windowPositionDelegate,
                                                 selector: #selector(WindowPositionManager.handleTerminalTermination(_:)),
                                                 name: NSWorkspace.didTerminateApplicationNotification,
                                                 object: nil)
    }
    
    private func runInstallScript() {
        // Get the path to the install.sh script in the app bundle
        guard let scriptPath = Bundle.main.path(forResource: "install", ofType: "sh") else {
            print("install.sh not found in the app bundle")
            return
        }

        print("Found install.sh at path: \(scriptPath)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath]

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                print("Script executed successfully.")
            } else {
                print("Script execution failed with status: \(process.terminationStatus)")
            }
        } catch {
            print("Failed to execute script: \(error)")
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
