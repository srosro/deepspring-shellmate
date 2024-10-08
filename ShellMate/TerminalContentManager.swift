import AXSwift
import Cocoa
import Sentry

class TerminalContentManager: NSObject, NSApplicationDelegate {
  var terminalTextAreaElement: AXUIElement?
  var terminalTextObserver: Observer?
  var highlightTextObserver: Observer?
  var previousTerminalText: String?
  var previousHighlightedText: String?
  var previousActiveLine: String?
  var textDebounceWorkItem: DispatchWorkItem?
  var highlightDebounceWorkItem: DispatchWorkItem?
  var activeLineDebounceWorkItem: DispatchWorkItem?
  var currentTerminalWindowID: CGWindowID?  // Store the current terminal window ID
  var preHighlightDebounceWorkItem: DispatchWorkItem?
  var preTextDebounceWorkItem: DispatchWorkItem?
  var debounceHighlightCancelCount = 0  // Counter for canceled debounceHighlightChange
  var debounceTextCancelCount = 0  // Counter for canceled debounceTextChange

  // Variables for debounce periods
  var preDebounceHighlightPeriod: TimeInterval = 0.1
  var mainDebounceHighlightPeriod: TimeInterval = 0.5
  var preDebounceTextPeriod: TimeInterval = 0.07
  var mainDebounceTextPeriod: TimeInterval = 1.5
  var activeLineDebouncePeriod: TimeInterval = 0.05

  // Variables for observer re-add periods
  var reAddTextObserverPeriod: TimeInterval = 2.0
  var reAddHighlightObserverPeriod: TimeInterval = 2.0

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Add observer for terminal window change notifications
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleTerminalWindowIdDidChange(_:)),
      name: .terminalWindowIdDidChange, object: nil)
  }

  @objc func handleTerminalWindowIdDidChange(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
      let windowID = userInfo["terminalWindowID"] as? CGWindowID
    else {
      return
    }

    let windowElement = userInfo["terminalWindow"] as! AXUIElement

    print("Received notification for terminal window change. Window ID: \(windowID)")

    // Remove old observers before adding new ones
    removeTerminalTextObserver()
    removeHighlightObserver()

    // Update the terminal text area element based on the new window information
    if let textAreaElement = findTextAreaElement(in: windowElement) {
      terminalTextAreaElement = textAreaElement
      currentTerminalWindowID = windowID  // Update the current terminal window ID
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
    let childrenError = AXUIElementCopyAttributeValue(
      element, kAXChildrenAttribute as CFString, &children)

    if childrenError == .success, let children = children as? [AXUIElement] {
      for child in children {
        if let foundElement = findTextAreaElement(in: child) {
          return foundElement
        }
      }
    }
    return nil
  }

  func checkForErrorKeywords(in text: String) {
    if OnboardingStateManager.shared.isStepCompleted(step: 4) {
      return
    }
    let lowercasedText = text.lowercased()
    let keywords = ["error", "traceback", "exception"]

    for keyword in keywords {
      if lowercasedText.contains(keyword) {
        print("Keyword '\(keyword)' found in text.")
        OnboardingStateManager.shared.markAsCompleted(step: 4)
        return
      }
    }
  }

  func checkForCommandNotFound(in text: String) {
    if OnboardingStateManager.shared.isStepCompleted(step: 5) {
      return
    }
    let lowercasedText = text.lowercased()
    let keyword = "command not found: sm"

    if lowercasedText.contains(keyword) {
      print("Keyword '\(keyword)' found in text.")
      OnboardingStateManager.shared.markAsCompleted(step: 5)
      return
    }
  }

  func processTerminalText() {
    guard let element = terminalTextAreaElement else { return }

    if let sanitizedText = getSanitizedTerminalText(from: element) {
      let alphanumericText = sanitizedText.replacingOccurrences(
        of: "\\W+", with: "", options: .regularExpression)

      if alphanumericText != previousTerminalText && !alphanumericText.isEmpty {
        previousTerminalText = alphanumericText
        //printTerminalText(sanitizedText, windowID: currentTerminalWindowID)

        // Log the event when terminal change is identified
        MixpanelHelper.shared.trackEvent(name: "terminalTextChangeIdentified")

        let last50Lines = getLastNLines(from: sanitizedText, numberOfLines: 50)
        checkForErrorKeywords(in: last50Lines)
        checkForCommandNotFound(in: last50Lines)
        // Obfuscate sensitive information
        let obfuscatedLast50Lines = obfuscateAuthTokens(in: last50Lines)

        // Send notifications
        sendContentAnalysisNotification(
          text: obfuscatedLast50Lines, windowID: currentTerminalWindowID, source: "terminalContent")
      }
    } else {
      print("Error retrieving text")
    }
  }

  private func getSanitizedTerminalText(from element: AXUIElement) -> String? {
    var textValue: AnyObject?
    let textError = AXUIElementCopyAttributeValue(
      element, kAXValueAttribute as CFString, &textValue)

    if textError == .success, let textValue = textValue as? String {
      let sanitizedText = textValue.replacingOccurrences(
        of: "\n+", with: "\n", options: .regularExpression)
      return sanitizedText
    } else {
      return nil
    }
  }

  private func getLastLine(from text: String) -> String {
    let lines = text.split(separator: "\n")
    return lines.last.map(String.init) ?? ""
  }

  private func getLastNLines(from text: String, numberOfLines: Int) -> String {
    let lines = text.split(separator: "\n")
    let lastNLines = lines.suffix(numberOfLines).joined(separator: "\n")
    return lastNLines
  }

  private func postTerminalActiveLineChangedNotification(text: String) {
    guard text != previousActiveLine else { return }  // Avoid duplicate notifications
    previousActiveLine = text

    let userInfo: [String: Any] = [
      "activeLine": text
    ]
    NotificationCenter.default.post(
      name: .terminalActiveLineChanged, object: nil, userInfo: userInfo)
  }

  private func sendContentAnalysisNotification(text: String, windowID: CGWindowID?, source: String)
  {
    let currentTimestamp = Double(Date().timeIntervalSince1970)
    let userInfo: [String: Any] = [
      "text": text,
      "currentTerminalWindowID": windowID ?? "",
      "source": source,
      "changeIdentifiedAt": currentTimestamp,
    ]
    NotificationCenter.default.post(
      name: .requestTerminalContentAnalysis, object: nil, userInfo: userInfo)
  }

  func debounceActiveLineChange() {
    guard let element = terminalTextAreaElement else { return }

    activeLineDebounceWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      if let sanitizedText = self?.getSanitizedTerminalText(from: element) {
        let lastLine = self?.getLastLine(from: sanitizedText)
        self?.postTerminalActiveLineChangedNotification(text: lastLine ?? "")
      }
    }
    activeLineDebounceWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + activeLineDebouncePeriod, execute: workItem)
  }

  func debounceTerminalTextChange() {
    // Cancel any previous pre-debounce work item immediately
    preTextDebounceWorkItem?.cancel()

    // Increment the cancel counter
    debounceTextCancelCount += 1

    // Check if the cancel counter has reached the threshold
    if debounceTextCancelCount >= 10 {
      // Remove the text observer
      removeTerminalTextObserver()

      // Reset the cancel counter
      debounceTextCancelCount = 0

      // Store the current terminal window ID
      let currentWindowID = currentTerminalWindowID

      // Re-add the text observer after a delay
      DispatchQueue.main.asyncAfter(deadline: .now() + reAddTextObserverPeriod) { [weak self] in
        guard let self = self, let element = self.terminalTextAreaElement else { return }
        // Check if the terminal window ID is still the same
        if self.currentTerminalWindowID == currentWindowID {
          self.startTerminalTextObserver(for: element)
        }
      }
    } else {
      // Create a new pre-debounce DispatchWorkItem
      let preDebounceWorkItem = DispatchWorkItem { [weak self] in
        self?.executeMainTextDebounce()
        // Reset the cancel counter when the debouncer item gets executed
        self?.debounceTextCancelCount = 0
      }

      // Assign the new work item to the preTextDebounceWorkItem variable
      preTextDebounceWorkItem = preDebounceWorkItem

      // Schedule the execution of the pre-debounce work item after a short delay
      DispatchQueue.main.asyncAfter(
        deadline: .now() + preDebounceTextPeriod, execute: preDebounceWorkItem)
    }
  }

  private func executeMainTextDebounce() {
    NotificationCenter.default.post(name: .terminalContentChangeStarted, object: nil)
    textDebounceWorkItem?.cancel()

    // Create the main debounce work item
    let workItem = DispatchWorkItem { [weak self] in
      self?.processTerminalText()
      NotificationCenter.default.post(name: .terminalContentChangeEnded, object: nil)
    }

    // Assign the new work item to the textDebounceWorkItem variable
    textDebounceWorkItem = workItem

    // Schedule the execution of the main work item after the main debounce delay
    DispatchQueue.main.asyncAfter(deadline: .now() + mainDebounceTextPeriod, execute: workItem)

    print("New main text debounce work item created")
  }

  func processHighlightedText() throws {
    do {
      // Define the source as a constant
      let source = "highlighted"

      let sanitizedText = try getSanitizedHighlightedText()
      let alphanumericText = sanitizedText.replacingOccurrences(
        of: "\\W+", with: "", options: .regularExpression)

      if alphanumericText != self.previousHighlightedText {
        self.previousHighlightedText = alphanumericText

        // Log the event when highlighted text change is identified
        MixpanelHelper.shared.trackEvent(name: "terminalHighlightChangeIdentified")
        self.sendContentAnalysisNotification(
          text: sanitizedText, windowID: self.currentTerminalWindowID, source: source)
      } else {
        // Log when no meaningful change is detected
        NSLog("No meaningful change detected in highlighted text.")
      }
    } catch {
      // Log the error
      NSLog("Error in processHighlightedText: \(error.localizedDescription)")

      // Log the error to Sentry
      let sentryError = NSError(
        domain: "TerminalContentManager.HighlightProcessing",
        code: 1001,
        userInfo: [
          NSLocalizedDescriptionKey: "Error processing highlighted text",
          NSUnderlyingErrorKey: error,
        ]
      )
      SentrySDK.capture(error: sentryError)

      // Rethrow the error
      throw error
    }
  }

  private func getSanitizedHighlightedText() throws -> String {
    guard let element = terminalTextAreaElement else {
      throw HighlightError.noTerminalTextAreaElement
    }

    var selectionValue: AnyObject?
    let selectionResult = AXUIElementCopyAttributeValue(
      element, kAXSelectedTextAttribute as CFString, &selectionValue)

    if selectionResult == .success, let highlightedText = selectionValue as? String {
      let sanitizedText = highlightedText.replacingOccurrences(
        of: "\n+", with: "\n", options: .regularExpression)
      let alphanumericText = sanitizedText.replacingOccurrences(
        of: "\\W+", with: "", options: .regularExpression)
      if alphanumericText.isEmpty {
        throw HighlightError.emptyHighlightedText
      }
      return sanitizedText
    } else {
      NSLog("No highlighted text or error retrieving it: \(selectionResult)")
      throw HighlightError.retrievalError(selectionResult)
    }
  }

  enum HighlightError: Error {
    case noTerminalTextAreaElement
    case emptyHighlightedText
    case retrievalError(AXError)
  }

  func printTerminalText(_ text: String, windowID: CGWindowID?) {
    print("Terminal text from window \(String(describing: windowID)):\n\"\(text)\"")
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

    terminalTextObserver = app.createObserver {
      [weak self]
      (observer: Observer, element: UIElement, event: AXNotification, info: [String: AnyObject]?) in
      guard let self = self else { return }
      if event == .valueChanged {
        self.debounceTerminalTextChange()
        self.debounceActiveLineChange()
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

    highlightTextObserver = app.createObserver {
      [weak self]
      (observer: Observer, element: UIElement, event: AXNotification, info: [String: AnyObject]?) in
      guard let self = self else { return }
      if event == .selectedTextChanged {
        NSLog("selectedTextChanged event detected. Info: \(String(describing: info))")
        self.debounceHighlightChange()
      }
    }

    do {
      try highlightTextObserver?.addNotification(
        .selectedTextChanged, forElement: UIElement(element))
    } catch let error {
      NSLog("Error: Could not watch element \(element): \(error)")
    }
  }

  func debounceHighlightChange() {
    // Cancel any previous pre-debounce work item immediately
    preHighlightDebounceWorkItem?.cancel()

    // Increment the cancel counter
    debounceHighlightCancelCount += 1

    // Check if the cancel counter has reached the threshold
    if debounceHighlightCancelCount >= 10 {
      // Remove the highlight observer
      removeHighlightObserver()

      // Reset the cancel counter
      debounceHighlightCancelCount = 0

      // Store the current terminal window ID
      let currentWindowID = currentTerminalWindowID

      // Re-add the highlight observer after a delay
      DispatchQueue.main.asyncAfter(deadline: .now() + reAddHighlightObserverPeriod) {
        [weak self] in
        guard let self = self, let element = self.terminalTextAreaElement else { return }
        // Check if the terminal window ID is still the same
        if self.currentTerminalWindowID == currentWindowID {
          self.startHighlightObserver(for: element)
        }
      }
    } else {
      // Create a new pre-debounce DispatchWorkItem
      let preDebounceWorkItem = DispatchWorkItem { [weak self] in
        self?.executeMainHighlightDebounce()
        // Reset the cancel counter after processing the debounce work item
        self?.debounceHighlightCancelCount = 0
      }

      // Assign the new work item to the preHighlightDebounceWorkItem variable
      preHighlightDebounceWorkItem = preDebounceWorkItem

      // Schedule the execution of the pre-debounce work item after a short delay
      DispatchQueue.main.asyncAfter(
        deadline: .now() + preDebounceHighlightPeriod, execute: preDebounceWorkItem)
    }
  }

  private func executeMainHighlightDebounce() {
    // Cancel any previous main debounce work item
    highlightDebounceWorkItem?.cancel()

    guard hasValidHighlightText() else {
      NSLog("Invalid highlight text during main debounce execution")
      return
    }

    NotificationCenter.default.post(name: .terminalContentChangeStarted, object: nil)

    // Create the main debounce work item
    let workItem = DispatchWorkItem { [weak self] in
      DispatchQueue.main.async {
        guard let self = self else {
          NSLog("Self is nil during main debounce work item execution")
          return
        }

        do {
          try self.processHighlightedText()
        } catch {
          SentrySDK.capture(error: error)
          NSLog("Error processing highlighted text: \(error.localizedDescription)")
        }

        NotificationCenter.default.post(name: .terminalContentChangeEnded, object: nil)
      }
    }

    // Assign the new work item to the highlightDebounceWorkItem variable
    highlightDebounceWorkItem = workItem

    // Schedule the execution of the main work item after the main debounce delay
    DispatchQueue.main.asyncAfter(deadline: .now() + mainDebounceHighlightPeriod, execute: workItem)

    print("New main highlight debounce work item created")
  }

  private func hasValidHighlightText() -> Bool {
    do {
      let sanitizedText = try getSanitizedHighlightedText()
      return !sanitizedText.isEmpty
    } catch {
      return false
    }
  }

  func removeTerminalTextObserver() {
    if let observer = terminalTextObserver {
      observer.stop()
      terminalTextObserver = nil
      print("Terminal text observer removed.")
    }
  }

  func removeHighlightObserver() {
    if let observer = highlightTextObserver {
      observer.stop()
      highlightTextObserver = nil
      print("Highlight text observer removed.")
    }
  }
}
