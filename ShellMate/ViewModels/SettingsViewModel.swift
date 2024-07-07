//
//  SettingsViewModel.swift
//  ShellMate
//
//  Created by Daniel Delattre on 26/06/24.
//

import Foundation
import ApplicationServices
import Combine
import AppKit

class SettingsViewModel: ObservableObject {
    @Published var isAppTrusted = false
    
    private var timer: AnyCancellable?

    init() {
        checkAccessibilityPermissions()
        startTimer()
    }

    func checkAccessibilityPermissions() {
        isAppTrusted = AccessibilityChecker.isAppTrusted()
    }

    private func startTimer() {
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
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
}
