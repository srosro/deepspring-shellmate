//
//  KeyPressWatcher.swift
//  ShellMate
//
//  Created by daniel on 05/07/24.
//

import Foundation
import Cocoa

class KeyPressDelegate {
    private var eventMonitor: Any?

    init() {
        startMonitoring()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleTerminalActiveLineChanged(_:)),
                                               name: .terminalActiveLineChanged,
                                               object: nil)
    }

    deinit {
        stopMonitoring()
        NotificationCenter.default.removeObserver(self, name: .terminalActiveLineChanged, object: nil)
    }

    private func startMonitoring() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyPress(event: event)
        }
    }

    private func stopMonitoring() {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    private func handleKeyPress(event: NSEvent) {
        // Get the frontmost application
        if let frontmostApp = NSWorkspace.shared.frontmostApplication,
           frontmostApp.bundleIdentifier == "com.apple.Terminal" {
            // Check if the key pressed is the Enter key
            if event.keyCode == 36 {
                print("Enter key pressed in Terminal")
            }
        }
    }

    @objc private func handleTerminalActiveLineChanged(_ notification: Notification) {
        if let userInfo = notification.userInfo, let activeLine = userInfo["activeLine"] as? String {
            print("Received active line from Terminal: \(activeLine)")
        }
    }
}
