//
//  ShellMateWindowTrackingDelegate.swift
//  ShellMate
//
//  Created by daniel on 09/07/24.
//

import Cocoa
import AXSwift

class ShellMateWindowTrackingDelegate: NSObject {
    private var localMouseEventMonitor: Any?
    private var windowPositionDelegate: WindowPositionManager?
    private var terminalObserver: AXObserver?

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
        setupObserverForShellMate()
    }

    private func handleMouseUp(_ event: NSEvent) {
        print("Mouse button released.")
        printWindowPosition()
        checkAndPrintWindowPositionRelativeToTerminal()
        removeObserverForShellMate()
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

    private func printWindowPosition() {
        if let window = NSApplication.shared.windows.first {
            let position = window.frame.origin
            let size = window.frame.size
            print("Current window position: \(position), Size: \(size)")
        }
    }

    private func postWindowAttachmentPositionDidChangeNotification(position: String) {
        print("POSTING BY DRAG DID CHANGE")
        let userInfo: [String: String] = [
            "position": position,
            "source": "dragging"
        ]
        NotificationCenter.default.post(name: .windowAttachmentPositionDidChange, object: nil, userInfo: userInfo)
    }

    private func setupObserverForShellMate() {
        guard let shellMateApp = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == "ShellMate" }) else {
            print("ShellMate application is not running.")
            return
        }

        var observer: AXObserver?
        let pid = shellMateApp.processIdentifier
        let callback: AXObserverCallback = { (observer, element, notification, refcon) in
            print("Observer callback triggered for ShellMate: \(notification).")
            let delegate = Unmanaged<ShellMateWindowTrackingDelegate>.fromOpaque(refcon!).takeUnretainedValue()
            delegate.handleWindowPositionChange(notification: notification as CFString)
        }

        let result = AXObserverCreate(pid_t(pid), callback, &observer)

        if result != .success {
            print("Failed to create AXObserver for ShellMate. Error: \(result.rawValue)")
            return
        }

        self.terminalObserver = observer

        guard let observer = observer else {
            print("Failed to create AXObserver.")
            return
        }

        let shellMateElement = AXUIElementCreateApplication(pid_t(pid))
        let runLoopSource = AXObserverGetRunLoopSource(observer)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
        print("Observer added to run loop for ShellMate.")

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        addNotifications(to: observer, element: shellMateElement, refcon: refcon)
    }

    private func removeObserverForShellMate() {
        guard let observer = terminalObserver else { return }
        let runLoopSource = AXObserverGetRunLoopSource(observer)
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
        terminalObserver = nil
        print("Observer removed for ShellMate.")
    }

    private func addNotifications(to observer: AXObserver, element: AXUIElement, refcon: UnsafeMutableRawPointer) {
        let notifications = [
            kAXMovedNotification as CFString,
            kAXResizedNotification as CFString
        ]

        for notification in notifications {
            let result = AXObserverAddNotification(observer, element, notification, refcon)
            if result != .success {
                print("Failed to add \(notification) notification to observer. Error: \(result.rawValue)")
            }
        }
    }

    private func handleWindowPositionChange(notification: CFString) {
        printWindowPosition()
    }
}
