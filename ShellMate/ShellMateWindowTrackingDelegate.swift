//
//  ShellMateWindowTrackingDelegate.swift
//  ShellMate
//
//  Created by daniel on 09/07/24.
//

import Cocoa

class ShellMateWindowTrackingDelegate: NSObject {
    private var localMouseEventMonitor: Any?
    private var trackingTimer: Timer?

    override init() {
        super.init()
        startMonitoringLocalMouseEvents()
    }

    deinit {
        stopMonitoringLocalMouseEvents()
        stopTrackingWindowPosition()
    }

    private func startMonitoringLocalMouseEvents() {
        localMouseEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            self?.handleLocalMouseEvent(event)
            return event
        }
    }

    private func stopMonitoringLocalMouseEvents() {
        if let monitor = localMouseEventMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseEventMonitor = nil
        }
    }

    private func handleLocalMouseEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            print("Mouse button pressed at: \(event.locationInWindow)")
            startTrackingWindowPosition()
        case .leftMouseUp:
            print("Mouse button released at: \(event.locationInWindow)")
            stopTrackingWindowPosition()
        default:
            break
        }
    }

    private func startTrackingWindowPosition() {
        guard trackingTimer == nil else { return }
        
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            self?.printWindowPosition()
        }
    }

    private func stopTrackingWindowPosition() {
        trackingTimer?.invalidate()
        trackingTimer = nil
    }

    private func printWindowPosition() {
        if let window = NSApplication.shared.windows.first {
            let position = window.frame.origin
            print("Current window position: \(position)")
        }
    }
}
