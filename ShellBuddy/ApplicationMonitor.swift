//
//  ApplicationMonitor.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 27/05/24.
//

import SwiftUI
import Foundation

class ApplicationMonitor {
    static let shared = ApplicationMonitor()
    private(set) var isMinimized: Bool = false  // Now accessible outside but only settable inside the class
    var onMinimizedChanged: ((Bool) -> Void)?

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidMiniaturize(_:)), name: NSWindow.didMiniaturizeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidDeminiaturize(_:)), name: NSWindow.didDeminiaturizeNotification, object: nil)
    }

    @objc private func windowDidMiniaturize(_ notification: Notification) {
        isMinimized = true
        onMinimizedChanged?(isMinimized)
    }

    @objc private func windowDidDeminiaturize(_ notification: Notification) {
        isMinimized = false
        onMinimizedChanged?(isMinimized)
    }
}
