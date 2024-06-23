import Cocoa
import AXSwift

class TerminalContentManager: NSObject, NSApplicationDelegate {
    var terminalTextAreaElement: AXUIElement?
    var terminalTextObserver: Observer?
    var highlightTextObserver: Observer?
    var previousTerminalText: String?
    var previousHighlightedText: String?
    var textDebounceWorkItem: DispatchWorkItem?
    var highlightDebounceWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Observe the Terminal lifecycle
        observeTerminalLifecycle()
        
        // Check if Terminal is already running and set up observers
        setupTerminalObservers()
        
        // Add observer for terminal window change notifications
        NotificationCenter.default.addObserver(self, selector: #selector(handleTerminalWindowDidChange(_:)), name: .terminalWindowDidChange, object: nil)
    }

    func observeTerminalLifecycle() {
        let workspace = NSWorkspace.shared
        workspace.notificationCenter.addObserver(self, selector: #selector(handleTerminalLaunch(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        workspace.notificationCenter.addObserver(self, selector: #selector(handleTerminalTermination(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
    }

    @objc func handleTerminalLaunch(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let launchedApp = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              launchedApp.bundleIdentifier == "com.apple.Terminal" else {
            return
        }
        setupTerminalObservers()
    }

    @objc func handleTerminalTermination(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let terminatedApp = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              terminatedApp.bundleIdentifier == "com.apple.Terminal" else {
            return
        }
        removeTerminalObservers()
        terminalTextAreaElement = nil
        terminalTextObserver = nil
        highlightTextObserver = nil
        NSLog("Terminal application terminated.")
    }

    func setupTerminalObservers() {
        guard let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Terminal").first else {
            NSLog("Terminal application is not running")
            return
        }
        
        let appElement = AXUIElementCreateApplication(runningApp.processIdentifier)
        
        // Try to get the first window
        var windowElement: AnyObject?
        let windowError = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowElement)
        
        if windowError == .success, let windowArray = windowElement as? [AXUIElement], let window = windowArray.first {
            // Retrieve the AXTextArea element directly
            if let textAreaElement = findTextAreaElement(in: window) {
                terminalTextAreaElement = textAreaElement
                startTerminalTextObserver(for: textAreaElement)
                startHighlightObserver(for: textAreaElement)
            } else {
                NSLog("AXTextArea element not found")
            }
        } else {
            NSLog("Error retrieving window: \(windowError)")
        }
    }

    func removeTerminalObservers() {
        terminalTextObserver = nil
        highlightTextObserver = nil
    }

    func findTextAreaElement(in element: AXUIElement) -> AXUIElement? {
        var role: AnyObject?
        let roleError = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)

        if roleError == .success, let role = role as? String, role == "AXTextArea" {
            return element
        }

        var children: AnyObject?
        let childrenError = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)

        if childrenError == .success, let children = children as? [AXUIElement] {
            for child in children {
                if let foundElement = findTextAreaElement(in: child) {
                    return foundElement
                }
            }
        }
        return nil
    }

    @objc func handleTerminalWindowDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let windowID = userInfo["terminalWindowID"] as? CGWindowID,
              let windowElement = userInfo["terminalWindow"] as! AXUIElement? else {
            return
        }

        print("Received notification for terminal window change. Window ID: \(windowID)")

        // Update the terminal text area element based on the new window information
        if let textAreaElement = findTextAreaElement(in: windowElement) {
            terminalTextAreaElement = textAreaElement
            startTerminalTextObserver(for: textAreaElement)
            startHighlightObserver(for: textAreaElement)
        } else {
            NSLog("AXTextArea element not found in the new terminal window")
        }
    }

    func processTerminalText() {
        guard let element = terminalTextAreaElement else { return }

        var textValue: AnyObject?
        let textError = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &textValue)

        if textError == .success, let textValue = textValue as? String {
            let sanitizedText = textValue.replacingOccurrences(of: "\n+", with: "\n", options: .regularExpression)
            let alphanumericText = sanitizedText.replacingOccurrences(of: "\\W+", with: "", options: .regularExpression)
            if alphanumericText != previousTerminalText {
                previousTerminalText = alphanumericText
                printTerminalText(sanitizedText)
            }
        } else {
            print("Error retrieving text: \(textError)")
        }
    }

    func processHighlightedText() {
        guard let element = terminalTextAreaElement else { return }

        var selectionValue: AnyObject?
        let selectionResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectionValue)

        if selectionResult == .success, let highlightedText = selectionValue as? String {
            let sanitizedText = highlightedText.replacingOccurrences(of: "\n+", with: "\n", options: .regularExpression)
            let alphanumericText = sanitizedText.replacingOccurrences(of: "\\W+", with: "", options: .regularExpression)
            if alphanumericText != previousHighlightedText {
                previousHighlightedText = alphanumericText
                printHighlightedText(sanitizedText)
            }
        } else {
            print("No highlighted text or error retrieving it: \(selectionResult)")
        }
    }

    func printTerminalText(_ text: String) {
        print("Terminal text:\n\"\(text)\"")
    }

    func printHighlightedText(_ text: String) {
        print("Highlighted text:\n\"\(text)\"")
    }

    func startTerminalTextObserver(for element: AXUIElement) {
        guard let app = Application.allForBundleID("com.apple.Terminal").first else {
            NSLog("Error: Could not create Application object")
            return
        }

        terminalTextObserver = app.createObserver { [weak self] (observer: Observer, element: UIElement, event: AXNotification, info: [String: AnyObject]?) in
            guard let self = self else { return }
            if event == .valueChanged {
                self.debounceTerminalTextChange()
            }
        }

        do {
            try terminalTextObserver?.addNotification(.valueChanged, forElement: UIElement(element))
        } catch let error {
            NSLog("Error: Could not watch element \(element): \(error)")
        }
    }

    func startHighlightObserver(for element: AXUIElement) {
        guard let app = Application.allForBundleID("com.apple.Terminal").first else {
            NSLog("Error: Could not create Application object")
            return
        }

        highlightTextObserver = app.createObserver { [weak self] (observer: Observer, element: UIElement, event: AXNotification, info: [String: AnyObject]?) in
            guard let self = self else { return }
            if event == .selectedTextChanged {
                self.debounceHighlightChange()
            }
        }

        do {
            try highlightTextObserver?.addNotification(.selectedTextChanged, forElement: UIElement(element))
        } catch let error {
            NSLog("Error: Could not watch element \(element): \(error)")
        }
    }

    func debounceTerminalTextChange() {
        textDebounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.processTerminalText()
        }
        textDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
    }

    func debounceHighlightChange() {
        highlightDebounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.processHighlightedText()
        }
        highlightDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
}
