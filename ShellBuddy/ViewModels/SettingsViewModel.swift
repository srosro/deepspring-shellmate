//
//  SettingsViewModel.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 26/06/24.
//

import Foundation
import ApplicationServices
import Combine
import AppKit

class SettingsViewModel: ObservableObject {
    @Published var isAppTrusted = false
    @Published var isTerminalTrusted = false
    private var timer: AnyCancellable?

    init() {
        checkAccessibilityPermissions()
        startTimer()
    }

    func checkAccessibilityPermissions() {
        isAppTrusted = AccessibilityChecker.isAppTrusted()
        isTerminalTrusted = AccessibilityChecker.isTerminalTrusted()
    }

    private func startTimer() {
        timer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkAccessibilityPermissions()
            }
    }

    deinit {
        timer?.cancel()
    }
    
    func initializeApp() {
        if let appDelegate = NSApplication.shared.delegate as? ApplicationDelegate {
            appDelegate.initializeApp()
        }
    }
    
    func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
    
    func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
