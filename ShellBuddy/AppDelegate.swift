import Cocoa
import AXSwift

class ApplicationDelegate: NSObject, NSApplicationDelegate {
    var terminalTextAreaElement: AXUIElement? = nil
    var terminalTextObserver: Observer?
    var highlightTextObserver: Observer?
    var previousTerminalText: String?
    var previousHighlightedText: String?
    var currentTextDebounceUUID: UUID?
    var currentHighlightDebounceUUID: UUID?
    var textDebounceTimer: Timer?
    var highlightDebounceTimer: Timer?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Check that we have permission
        guard UIElement.isProcessTrusted(withPrompt: true) else {
            NSLog("No accessibility API permission, exiting")
            NSRunningApplication.current.terminate()
            return
        }

        // Get Application by bundleIdentifier
        if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Terminal").first {
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
        } else {
            NSLog("Terminal application is not running")
        }
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
        let uuid = UUID()
        currentTextDebounceUUID = uuid

        textDebounceTimer?.invalidate()
        textDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.currentTextDebounceUUID == uuid {
                self.processTerminalText()
            }
        }
    }

    func debounceHighlightChange() {
        let uuid = UUID()
        currentHighlightDebounceUUID = uuid

        highlightDebounceTimer?.invalidate()
        highlightDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.currentHighlightDebounceUUID == uuid {
                self.processHighlightedText()
            }
        }
    }
}
