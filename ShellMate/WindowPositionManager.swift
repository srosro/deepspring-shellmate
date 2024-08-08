//
//  WindowManager.swift
//  ShellMate
//
//  Created by Daniel Delattre on 23/06/24.
//

import Cocoa
import ApplicationServices


class WindowPositionManager: NSObject, NSApplicationDelegate {
    var terminalObserver: AXObserver?
    var isTerminalFocused: Bool = false  // Add a variable to store the focused state
    var focusedTerminalWindowID: CGWindowID? = nil
    var previousFocusedWindowID: CGWindowID? = nil

    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("Application did finish launching.")
        initializeFocusedWindowID() // Required in case app launches with terminal already open
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleUpdatedAppPositionAfterWindowAttachmentChange(_:)), name: .updatedAppPositionAfterWindowAttachmentChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleReinitializeTerminalWindowID), name: .reinitializeTerminalWindowID, object: nil)
    }
    
    func initializeFocusedWindowID() {
        guard let windowData = getTerminalWindowPositionAndSize() else {
            return
        }
        
        if let windowID = windowData.windowID {
            print("DEBUG: terminal window initialized")
            NotificationCenter.default.post(name: .terminalWindowIdDidChange, object: self, userInfo: [
                "terminalWindowID": windowID,
                "terminalWindow": windowData.focusedWindow!
            ])
        }
        
        positionAndSizeWindow(terminalPosition: windowData.position, terminalSize: windowData.size, shouldAnimate: true)
    }
    
    @objc func handleReinitializeTerminalWindowID(_ notification: Notification) {
        initializeFocusedWindowID()
    }
    
    @objc func handleTerminalLaunch(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let launchedApp = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              launchedApp.bundleIdentifier == "com.apple.Terminal" else {
            return
        }
        setupTerminalObserver()
        initializeFocusedWindowID() // Required in case app launches with terminal not open yet
    }
    
    @objc func handleTerminalTermination(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let terminatedApp = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              terminatedApp.bundleIdentifier == "com.apple.Terminal" else {
            return
        }
        removeTerminalObserver()
        miniaturizeAppWindow()
        isTerminalFocused = false  // Reset the focused state when Terminal is terminated
    }
    
    @objc func handleUpdatedAppPositionAfterWindowAttachmentChange(_ notification: Notification) {
        guard let windowData = getTerminalWindowPositionAndSize() else {
            return
        }
        positionAndSizeWindow(terminalPosition: windowData.position, terminalSize: windowData.size, shouldAnimate: true)
    }
    
    func initializeObserverForRunningTerminal() {
        if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == "com.apple.Terminal" }) {
            setupTerminalObserver()
        }
    }
    
    func setupTerminalObserver() {
        print("Setting up observer for Terminal.")
        
        guard let terminalApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.Terminal" }) else {
            print("Terminal application is not running.")
            return
        }
        
        var observer: AXObserver?
        let pid = terminalApp.processIdentifier
        let callback: AXObserverCallback = { (observer, element, notification, refcon) in
            print("Observer callback triggered for Terminal: \(notification).")
            let delegate = Unmanaged<WindowPositionManager>.fromOpaque(refcon!).takeUnretainedValue()
            delegate.updateAppWindowPositionAndSize(notification: notification as CFString) // Pass the notification
        }
        
        let result = AXObserverCreate(pid_t(pid), callback, &observer)
        
        if result != .success {
            print("Failed to create AXObserver for Terminal. Error: \(result.rawValue)")
            return
        }
        
        self.terminalObserver = observer
        
        guard let observer = observer else {
            print("Failed to create AXObserver.")
            return
        }
        
        let terminalElement = AXUIElementCreateApplication(pid_t(pid))
        let runLoopSource = AXObserverGetRunLoopSource(observer)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
        print("Observer added to run loop for Terminal.")
        
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        addNotifications(to: observer, element: terminalElement, refcon: refcon)
        updateAppWindowPositionAndSize(notification: kAXFocusedWindowChangedNotification as CFString)
    }
    
    func removeTerminalObserver() {
        guard let observer = terminalObserver else { return }
        let runLoopSource = AXObserverGetRunLoopSource(observer)
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
        terminalObserver = nil
        print("Observer removed for Terminal.")
    }
    
    func addNotifications(to observer: AXObserver, element: AXUIElement, refcon: UnsafeMutableRawPointer) {
        let notifications = [
            kAXFocusedWindowChangedNotification as CFString,
            kAXApplicationDeactivatedNotification as CFString,
            kAXApplicationActivatedNotification as CFString,
            kAXWindowCreatedNotification as CFString,
            kAXWindowMovedNotification as CFString,
            kAXWindowMiniaturizedNotification as CFString,
            kAXWindowDeminiaturizedNotification as CFString,
            kAXUIElementDestroyedNotification as CFString,  // Close event substitute
            kAXResizedNotification as CFString,
            kAXFocusedUIElementChangedNotification as CFString  // To detect tab changes from the same terminal.
        ]
        
        for notification in notifications {
            let result = AXObserverAddNotification(observer, element, notification, refcon)
            if result != .success {
                print("Failed to add \(notification) notification to observer. Error: \(result.rawValue)")
            }
        }
    }
    
    func getTerminalWindowPositionAndSize() -> (position: CGPoint, size: CGSize, windowID: CGWindowID?, focusedWindow: AXUIElement?)? {
        guard let terminalApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.Terminal" }) else {
            print("Terminal application is not running.")
            return nil
        }

        guard let focusedWindow = getFocusedWindow(for: terminalApp) else {
            print("Failed to determine focused window for the Terminal application.")
            return nil
        }

        guard let _ = getWindowTitle(for: focusedWindow) else {
            // This check is necessary to avoid attaching ShellMate to non-terminal windows
            // (e.g., the prompt where the user confirms if they want to close the terminal)
            print("Unable to retrieve window title")
            return nil
        }
        
        let position = getWindowPosition(for: focusedWindow)
        let size = getWindowSize(for: focusedWindow)

        let currentWindowID = findWindowID(for: position, size: size, pid: terminalApp.processIdentifier)
        return (position, size, currentWindowID, focusedWindow)
    }

    
    func updateAppWindowPositionAndSize(notification: CFString) {
        print("Updating app window position and size.")

        guard let terminalApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.Terminal" }) else {
            print("Terminal application is not running.")
            miniaturizeAppWindow()
            return
        }

        let wasTerminalFocused = isTerminalFocused  // Store the previous focused state
        isTerminalFocused = isTerminalAppFocused(terminalApp)  // Update the current focused state

        let terminalElement = AXUIElementCreateApplication(terminalApp.processIdentifier)
        var windowList: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(terminalElement, kAXWindowsAttribute as CFString, &windowList)

        if result == .success, let axWindows = windowList as? [AXUIElement] {
            let visibleWindows = axWindows.filter { window in
                var isMinimized: CFTypeRef?
                let minimizedResult = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &isMinimized)
                return minimizedResult == .success && (isMinimized as? Bool) == false
            }

            if visibleWindows.isEmpty {
                let shouldMiniaturize = (notification == kAXWindowMiniaturizedNotification as CFString) || (notification == kAXUIElementDestroyedNotification as CFString)

                if shouldMiniaturize {
                    print("No visible Terminal windows found. Miniaturizing ShellMate app window.")
                    miniaturizeAppWindow()
                }
                return
            }

            guard let focusedWindow = getFocusedWindow(for: terminalApp) else {
                print("Failed to determine focused window for the Terminal application.")
                miniaturizeAppWindow()
                return
            }
            
            // Get the window's title
            guard let title = getWindowTitle(for: focusedWindow) else {
                // This check is necessary to avoid attaching ShellMate to non-terminal windows
                // (e.g., the prompt where the user confirms if they want to close the terminal)
                print("Unable to retrieve window title")
                return
            }

            print("Focused window title: \(title)")

            // Update the current focused window ID
            previousFocusedWindowID = focusedTerminalWindowID  // Store the previous focused window ID
            // Get the window's position and size
            let position = getWindowPosition(for: focusedWindow)
            let size = getWindowSize(for: focusedWindow)
            focusedTerminalWindowID = findWindowID(for: position, size: size, pid: terminalApp.processIdentifier)
            
            var shouldBringToFront = false

            if !wasTerminalFocused && isTerminalFocused {
                print("Terminal application is currently focused.")
                shouldBringToFront = true
            }

            // Check if the current and previous window IDs are not nil to avoid misfiring updates
            if let currentWindowID = focusedTerminalWindowID, let previousWindowID = previousFocusedWindowID, currentWindowID != previousWindowID {
                print("The focused terminal window changed from \(String(describing: previousFocusedWindowID)) to \(String(describing: currentWindowID)).")
                shouldBringToFront = true
                print("DEBUG: terminal window changed")
                NotificationCenter.default.post(name: .terminalWindowIdDidChange, object: self, userInfo: [
                    "terminalWindowID": currentWindowID,
                    "terminalWindow": focusedWindow
                ])
            }

            if shouldBringToFront {
                bringAppWindowToFrontWithoutFocus()  // Bring the app window to front without stealing focus
            }

            let shouldAnimate = (notification == kAXWindowMovedNotification as CFString)
            // Call the function with the updated parameters
            positionAndSizeWindow(terminalPosition: position, terminalSize: size, shouldAnimate: shouldAnimate)
            
        } else {
            print("Failed to get windows for Terminal.")
            
            // Check if the app has accessibility access
            if !AccessibilityChecker.isAppTrusted() {
                showPermissionsView()
            }
            return
        }
    }

    
    func isTerminalAppFocused(_ terminalApp: NSRunningApplication) -> Bool {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        let focusedAppResult = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        
        if focusedAppResult == .success, let focusedAppElement = focusedApp {
            var appPID: pid_t = 0
            AXUIElementGetPid(focusedAppElement as! AXUIElement, &appPID)
            return appPID == terminalApp.processIdentifier
        }
        return false
    }
    
    func getFocusedWindow(for terminalApp: NSRunningApplication) -> AXUIElement? {
        let terminalElement = AXUIElementCreateApplication(terminalApp.processIdentifier)
        var focusedWindow: CFTypeRef?
        let focusedWindowResult = AXUIElementCopyAttributeValue(terminalElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        return focusedWindowResult == .success ? (focusedWindow as! AXUIElement) : nil
    }
    
    func bringAppWindowToFrontWithoutFocus() {
        guard let window = NSApplication.shared.windows.first else {
            print("Failed to find the application window.")
            return
        }
        
        window.level = .floating
        window.orderFrontRegardless()  // Bring the window to the front without stealing focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            window.level = .normal
        }
    }
    
    func miniaturizeAppWindow() {
        guard let window = NSApplication.shared.windows.first else {
            print("Failed to find the application window.")
            return
        }
        
        // Retrieve the saved window attachment position from UserDefaults
        let savedPosition = UserDefaults.standard.string(forKey: "windowAttachmentPosition") ?? WindowAttachmentPosition.float.rawValue
        guard let attachmentPosition = WindowAttachmentPosition(rawValue: savedPosition) else {
            print("Invalid attachment position saved in UserDefaults.")
            return
        }
        
        // Check the current state of the attachment position. If it is float, just return and don't miniaturize
        if attachmentPosition == .float {
            print("Attachment position is 'float'. Will not miniaturize")
            return
        }
        
        // Miniaturize the window if it's not in float state
        window.miniaturize(nil)
    }
    
    func getWindowTitle(for window: AXUIElement) -> String? {
        var windowTitle: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &windowTitle)
        return result == .success ? windowTitle as? String : nil
    }
    
    func getWindowPosition(for window: AXUIElement) -> CGPoint {
        var position: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &position)
        var point = CGPoint.zero
        if result == .success {
            AXValueGetValue(position as! AXValue, .cgPoint, &point)
        }
        return point
    }
    
    func getWindowSize(for window: AXUIElement) -> CGSize {
        var size: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &size)
        var sizeValue = CGSize.zero
        if result == .success {
            AXValueGetValue(size as! AXValue, .cgSize, &sizeValue)
        }
        return sizeValue
    }
    
    func findWindowID(for position: CGPoint, size: CGSize, pid: pid_t) -> CGWindowID? {
        let windowListOption = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let cgWindowListInfo = CGWindowListCopyWindowInfo(windowListOption, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for windowInfo in cgWindowListInfo {
            if let windowPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
               let windowBounds = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
               windowPID == pid,
               windowBounds["X"] == position.x,
               windowBounds["Y"] == position.y,
               windowBounds["Width"] == size.width,
               windowBounds["Height"] == size.height {
                return windowInfo[kCGWindowNumber as String] as? CGWindowID
            }
        }

        return nil
    }
}



func positionAndSizeWindow(terminalPosition: CGPoint, terminalSize: CGSize, shouldAnimate: Bool) {
    guard let screen = NSScreen.main, let window = NSApplication.shared.windows.first else {
        print("Failed to find the application window or screen.")
        return
    }
    
    // Get the saved window attachment position from UserDefaults
    let savedPosition = UserDefaults.standard.string(forKey: "windowAttachmentPosition") ?? "right"
    guard let attachmentPosition = WindowAttachmentPosition(rawValue: savedPosition) else {
        print("Invalid attachment position saved in UserDefaults.")
        return
    }
    print("Saved position: \(savedPosition)")
    
    // Calculate the new y position
    let screenHeight = screen.frame.height
    let newYPosition = screenHeight - terminalPosition.y - terminalSize.height
    
    // Calculate the new x position based on the attachmentPosition enum
    let newXPosition: CGFloat
    switch attachmentPosition {
    case .left:
        newXPosition = terminalPosition.x - window.frame.width
    case .right:
        newXPosition = terminalPosition.x + terminalSize.width
    case .float:
        return
    }
    
    // Calculate the new position
    let newPosition = CGPoint(x: newXPosition, y: newYPosition)
    let newSize = CGSize(width: window.frame.width, height: terminalSize.height)
    
    if shouldAnimate {
        // Animate the window position change
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3 // Set the duration of the animation
            window.animator().setFrame(NSRect(origin: newPosition, size: newSize), display: true)
        }, completionHandler: {
            print("Window repositioning animation completed.")
        })
    } else {
        // Update the window position and size without animation
        window.setFrame(NSRect(origin: newPosition, size: newSize), display: true)
    }
}
