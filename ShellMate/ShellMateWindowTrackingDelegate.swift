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
    private var windowPositionDelegate: WindowPositionManager?
    private var windowAttachmentChangeDebouncer: Timer?
    private let windowAttachmentChangeDebounceInterval: TimeInterval = 0.1 // Debounce interval for window attachment change events


    func setWindowPositionDelegate(_ delegate: WindowPositionManager) {
        self.windowPositionDelegate = delegate
    }

    private func monitorLocalMouseEvents() {
        localMouseEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            self?.handleLocalMouseEvent(event)
            return event
        }
    }

    func startTracking() {
        monitorLocalMouseEvents()
    }

    func stopTracking() {
        stopMonitoringLocalMouseEvents()
        stopTrackingWindowPosition()
    }

    private func stopMonitoringLocalMouseEvents() {
        if let monitor = localMouseEventMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseEventMonitor = nil
        }
    }

    private func handleLocalMouseEvent(_ event: NSEvent) {
        guard let window = event.window, window.title == "ShellMate" else {
            return
        }
        switch event.type {
        case .leftMouseDown:
            handleMouseDown(event)
        case .leftMouseUp:
            handleMouseUp(event)
        default:
            break
        }
    }

    private func handleMouseDown(_ event: NSEvent) {
        print("Mouse button pressed.")
        startTrackingWindowPosition()
    }

    private func handleMouseUp(_ event: NSEvent) {
        print("Mouse button released.")
        printWindowPosition() // Print the window position here
        checkAndPrintWindowPositionRelativeToTerminal()
        stopTrackingWindowPosition()
    }

    private func checkAndPrintWindowPositionRelativeToTerminal() {
        if let positionDelegate = windowPositionDelegate {
            if let result = positionDelegate.getTerminalWindowPositionAndSize() {
                print("App window position: \(result.position), Size: \(result.size), WindowID: \(String(describing: result.windowID)), FocusedWindow: \(String(describing: result.focusedWindow))")
                let relativePosition = checkWindowPositionRelativeToTerminal(appWindowPosition: NSApplication.shared.windows.first?.frame, terminalWindowPosition: result)
                print("Relative Position: \(relativePosition)")
                postWindowAttachmentPositionDidChangeNotification(position: relativePosition.lowercased())
            } else {
                print("No terminal window position and size found.")
            }
        } else {
            print("windowPositionDelegate is not set.")
        }
    }


    private func checkWindowPositionRelativeToTerminal(appWindowPosition: NSRect?, terminalWindowPosition: (position: CGPoint, size: CGSize, windowID: CGWindowID?, focusedWindow: AXUIElement?)) -> String {
        guard let appWindowPosition = appWindowPosition else { return "Unknown" }

        let appWindowCenterX = appWindowPosition.origin.x + (appWindowPosition.size.width / 2)
        let terminalWindowCenterX = terminalWindowPosition.position.x + (terminalWindowPosition.size.width / 2)

        if appWindowCenterX < terminalWindowCenterX {
            return "LEFT"
        } else {
            return "RIGHT"
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
            let size = window.frame.size
            print("Current window position: \(position), Size: \(size)")
        }
    }
    
    private func postWindowAttachmentPositionDidChangeNotification(position: String) {
        // Avoid posting duplicated events
        windowAttachmentChangeDebouncer?.invalidate()
        windowAttachmentChangeDebouncer = Timer.scheduledTimer(withTimeInterval: windowAttachmentChangeDebounceInterval, repeats: false) { _ in
            print("POSTING BY DRAG DID CHANGE")
            let userInfo: [String: String] = [
                "position": position,
                "source": "dragging"
            ]
            NotificationCenter.default.post(name: .windowAttachmentPositionDidChange, object: nil, userInfo: userInfo)
        }
    }
}
