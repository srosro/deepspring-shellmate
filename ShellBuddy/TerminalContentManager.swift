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
    var currentTerminalWindowID: CGWindowID? // Store the current terminal window ID

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Add observer for terminal window change notifications
        NotificationCenter.default.addObserver(self, selector: #selector(handleTerminalWindowDidChange(_:)), name: .terminalWindowDidChange, object: nil)
    }

    @objc func handleTerminalWindowDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let windowID = userInfo["terminalWindowID"] as? CGWindowID else {
            return
        }
        
        let windowElement = userInfo["terminalWindow"] as! AXUIElement

        print("Received notification for terminal window change. Window ID: \(windowID)")

        // Update the terminal text area element based on the new window information
        if let textAreaElement = findTextAreaElement(in: windowElement) {
            terminalTextAreaElement = textAreaElement
            currentTerminalWindowID = windowID // Update the current terminal window ID
            startTerminalTextObserver(for: textAreaElement)
            startHighlightObserver(for: textAreaElement)
        } else {
            NSLog("AXTextArea element not found in the new terminal window")
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
                printTerminalText(sanitizedText, windowID: currentTerminalWindowID)
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
                printHighlightedText(sanitizedText, windowID: currentTerminalWindowID)
            }
        } else {
            print("No highlighted text or error retrieving it: \(selectionResult)")
        }
    }

    func printTerminalText(_ text: String, windowID: CGWindowID?) {
        print("Terminal text from window \(String(describing: windowID)):\n\"\(text)\"")
    }

    func printHighlightedText(_ text: String, windowID: CGWindowID?) {
        print("Highlighted text from window \(String(describing: windowID)):\n\"\(text)\"")
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
