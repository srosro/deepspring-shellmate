import Cocoa
import AXSwift
import Sentry

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
        NotificationCenter.default.addObserver(self, selector: #selector(handleTerminalWindowIdDidChange(_:)), name: .terminalWindowIdDidChange, object: nil)
    }

    @objc func handleTerminalWindowIdDidChange(_ notification: Notification) {
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

    private func getLastNLines(from text: String, numberOfLines: Int) -> String {
        let lines = text.split(separator: "\n")
        let lastNLines = lines.suffix(numberOfLines).joined(separator: "\n")
        return lastNLines
    }
    
    func processTerminalText() {
        // Define the source as a constant
        let source = "terminalContent"

        // send notification terminal content change has been identified
        guard let element = terminalTextAreaElement else { return }

        var textValue: AnyObject?
        let textError = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &textValue)

        if textError == .success, let textValue = textValue as? String {
            let sanitizedText = textValue.replacingOccurrences(of: "\n+", with: "\n", options: .regularExpression)
            let alphanumericText = sanitizedText.replacingOccurrences(of: "\\W+", with: "", options: .regularExpression)
            
            if alphanumericText != previousTerminalText && !alphanumericText.isEmpty {
                previousTerminalText = alphanumericText
                printTerminalText(sanitizedText, windowID: currentTerminalWindowID)
                
                // Log the event when terminal change is identified
                MixpanelHelper.shared.trackEvent(name: "terminalTextChangeIdentified")
                
                sendContentAnalysisNotification(text: getLastNLines(from: sanitizedText, numberOfLines: 50),
                                                windowID: currentTerminalWindowID,
                                                source: source)
            }
        } else {
            print("Error retrieving text: \(textError)")
        }
    }


    private func sendContentAnalysisNotification(text: String, windowID: CGWindowID?, source: String) {
        let currentTimestamp = Double(Date().timeIntervalSince1970)
        let userInfo: [String: Any] = [
            "text": text,
            "currentTerminalWindowID": windowID ?? "",
            "source": source,
            "changeIdentifiedAt": currentTimestamp
        ]
        NotificationCenter.default.post(name: .requestTerminalContentAnalysis, object: nil, userInfo: userInfo)
    }


    func processHighlightedText() {
        // Define the source as a constant
        let source = "highlighted"

        if let sanitizedText = getSanitizedHighlightedText() {
            let alphanumericText = sanitizedText.replacingOccurrences(of: "\\W+", with: "", options: .regularExpression)
            
            // Log the previous and current highlighted text
            NSLog("Previous highlighted text: \(previousHighlightedText ?? "nil")")
            NSLog("Current highlighted text: \(sanitizedText)")

            if alphanumericText != previousHighlightedText {
                previousHighlightedText = alphanumericText
                printHighlightedText(sanitizedText, windowID: currentTerminalWindowID)
                
                // Log the event when highlighted text change is identified
                MixpanelHelper.shared.trackEvent(name: "terminalHighlightChangeIdentified")
                sendContentAnalysisNotification(text: sanitizedText, windowID: currentTerminalWindowID, source: source)
            } else {
                // Log when no meaningful change is detected
                NSLog("No meaningful change detected in highlighted text.")
            }
        }
    }




    func printTerminalText(_ text: String, windowID: CGWindowID?) {
        print("Terminal text from window \(String(describing: windowID)):\n\"\(text)\"")
    }

    func printHighlightedText(_ text: String, windowID: CGWindowID?) {
        print("Highlighted text from window \(String(describing: windowID)):\n\"\(text)\"")
        // Intentionally causing an error
        //fatalError("Intentional crash to test Sentry integration - Highlight")
        
        do {
            try intentionalError()
        } catch {
            SentrySDK.capture(error: error)
            fatalError("Intentional crash to test Sentry integration")

        }

    }
    func intentionalError() throws {
        enum TestError: Error {
            case intentional
        }
        
        throw TestError.intentional
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
                NSLog("selectedTextChanged event detected. Info: \(String(describing: info))")
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
        NotificationCenter.default.post(name: .terminalContentChangeStarted, object: nil)
        textDebounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.processTerminalText()
            NotificationCenter.default.post(name: .terminalContentChangeEnded, object: nil)
        }
        textDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem)
    }

    func debounceHighlightChange() {
        // This check is necessary because clicking on the terminal without highlighting anything will trigger a selected text changed event.
        guard self.hasValidHighlightText() else {
            NSLog("Invalid highlight text")
            return
        }

        NotificationCenter.default.post(name: .terminalContentChangeStarted, object: nil)

        highlightDebounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else {
                NSLog("Self is nil in DispatchWorkItem")
                return
            }

            guard self.hasValidHighlightText() else {
                NSLog("Invalid highlight text during debounced work item execution")
                return
            }

            // Ensure processHighlightedText is executed on the main thread
            DispatchQueue.main.async {
                self.processHighlightedText()
                NotificationCenter.default.post(name: .terminalContentChangeEnded, object: nil)
            }
        }

        highlightDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }


    private func getSanitizedHighlightedText() -> String? {
        guard let element = terminalTextAreaElement else { return nil }

        var selectionValue: AnyObject?
        let selectionResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectionValue)

        if selectionResult == .success, let highlightedText = selectionValue as? String {
            let sanitizedText = highlightedText.replacingOccurrences(of: "\n+", with: "\n", options: .regularExpression)
            let alphanumericText = sanitizedText.replacingOccurrences(of: "\\W+", with: "", options: .regularExpression)
            return alphanumericText.isEmpty ? nil : sanitizedText
        } else {
            NSLog("No highlighted text or error retrieving it: \(selectionResult)")
            return nil
        }
    }
    
    private func hasValidHighlightText() -> Bool {
        return getSanitizedHighlightedText() != nil
    }
}
