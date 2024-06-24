//
//  ApplicationDelegate.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 23/06/24.
//

import Cocoa

class ApplicationDelegate: NSObject, NSApplicationDelegate {
    let terminalContentDelegate = TerminalContentManager()
    let windowPositionDelegate = WindowPositionManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityPermissions()
    }
    
    func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            initializeApp()
        } else {
            print("Waiting for accessibility permissions...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.requestAccessibilityPermissions()
            }
        }
    }
    
    func initializeApp() {
        observeTerminalLifecycle()
        terminalContentDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("AppDidFinishLaunching")))
        windowPositionDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("AppDidFinishLaunching")))
        windowPositionDelegate.initializeObserverForRunningTerminal()
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
}
