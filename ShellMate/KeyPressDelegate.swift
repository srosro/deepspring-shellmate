import Foundation
import Cocoa

class KeyPressDelegate {
    private var eventMonitor: Any?
    private var debounceWorkItem: DispatchWorkItem?
    private var currentActiveLine: String? // Variable to store the current active line

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("KeyPressDelegate - Application did finish launching.")
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleTerminalActiveLineChanged(_:)),
                                               name: .terminalActiveLineChanged,
                                               object: nil)
        startMonitoring() // Ensure startMonitoring is called
    }

    deinit {
        print("KeyPressDelegate - Deinitialized")
        stopMonitoring()
        NotificationCenter.default.removeObserver(self, name: .terminalActiveLineChanged, object: nil)
    }

    func startMonitoring() {
        print("KeyPressDelegate - Start monitoring key presses.")
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            //print("KeyPressDelegate - Key press detected.")
            self?.handleKeyPress(event: event)
        }
    }

    private func stopMonitoring() {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
            print("KeyPressDelegate - Stopped monitoring key presses.")
        }
    }

    private func handleKeyPress(event: NSEvent) {
        // Get the frontmost application
        if let frontmostApp = NSWorkspace.shared.frontmostApplication,
           frontmostApp.bundleIdentifier == "com.apple.Terminal" {
            // Check if the key pressed is the Enter key
            if event.keyCode == 36 {
                print("KeyPressDelegate - Enter key detected.")
                debounceEnterKey()
            }
        }
    }

    private func debounceEnterKey() {
        // Cancel any existing debounce work item
        debounceWorkItem?.cancel()

        // Create a new work item to handle the Enter key press
        debounceWorkItem = DispatchWorkItem { [weak self] in
            self?.processEnterKey()
        }

        // Execute the work item after a delay of 0.05 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: debounceWorkItem!)
    }

    func isValidSMIndexCommand(line: String) -> Bool {
        // Regular expression pattern to match "sm" followed by a space and a single number (integer or float)
        let pattern = #"^.*\bsm\s+(\d+(\.\d+)?)\s*$"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: line.utf16.count)
            
            // Check if there's a match
            if let _ = regex.firstMatch(in: line, options: [], range: range) {
                return true
            }
        } catch {
            print("Error creating regular expression: \(error)")
        }
        
        return false
    }
    
    // Function to extract the index after `sm` command
    func extractSMCommandIndex(line: String) -> String? {
        // Regular expression to match `sm` followed by a space and a number
        let regex = try! NSRegularExpression(pattern: #"sm\s+([0-9]*\.?[0-9]+)"#, options: [])
        let nsString = line as NSString
        let results = regex.matches(in: line, options: [], range: NSRange(location: 0, length: nsString.length))
        
        // Extract the first match
        if let match = results.first {
            let numberRange = match.range(at: 1)
            let numberString = nsString.substring(with: numberRange)
            
            // Check if the number is an integer
            if let intArg = Int(numberString) {
                // Convert integer argument to float with ".1" suffix
                return "\(intArg).1"
            } else if let _ = Float(numberString) {
                // If it's already a float, return it as is
                return numberString
            }
        }
        
        // Return nil if no valid `sm` command index is found
        return nil
    }
    
    // Function to check for valid `sm` question
    func isValidSMQuestion(line: String) -> Bool {
        // Regular expression to match `sm` followed by a space and a quoted string
        let regex = try! NSRegularExpression(pattern: #"sm\s+["'](.+?)["']"#, options: [])
        let nsString = line as NSString
        let results = regex.matches(in: line, options: [], range: NSRange(location: 0, length: nsString.length))
        
        // Check if there's at least one match
        return !results.isEmpty
    }

    // Updated processEnterKey function
    private func processEnterKey() {
        print("Enter key pressed in Terminal")
        if let activeLine = currentActiveLine {
            print("Current active line: \(activeLine)")
            let isValidSMIndexCommand = isValidSMIndexCommand(line: activeLine)
            print("Is valid 'sm' index command: \(isValidSMIndexCommand)")

            if isValidSMIndexCommand {
                // Extract the `sm` command index
                if let smCommandIndex = extractSMCommandIndex(line: activeLine) {
                    print("Extracted 'sm' command index: \(smCommandIndex)")

                    // Get the file path to shellMateCommandSuggestions.json
                    let filePath = getShellMateCommandSuggestionsFilePath()

                    // Load the command from JSON file using the extracted index
                    if let command = loadCommandFromJSON(filePath: filePath, key: smCommandIndex) {
                        print("Loaded command: \(command)")

                        // Set the desired text into the clipboard
                        setClipboardContent(text: command)

                        // Paste the clipboard content
                        pasteClipboardContent()
                        
                        if OnboardingStateManager.shared.showOnboarding && OnboardingStateManager.shared.currentStep == 2 {
                            OnboardingStateManager.shared.setStep(to: 3)
                        }
                    } else {
                        print("No command found for index \(smCommandIndex)")
                    }
                } else {
                    print("No valid 'sm' command index found.")
                }
            } else if OnboardingStateManager.shared.showOnboarding
                        && OnboardingStateManager.shared.currentStep == 1
                        && isValidSMQuestion(line: activeLine) {
                print("DANBUG: Valid 'sm' question detected: \(activeLine)")
                if doesCurrentLineContainOnboardingCommand(line: activeLine) {
                    print("DANBUG: Current line contains the onboarding command")
                    OnboardingStateManager.shared.setStep(to: 2)
                }
            }
        } else {
            print("No active line available.")
        }
    }
    
    // Function to sanitize text
    private func sanitizeText(_ text: String) -> String {
        let alphanumericText = text.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: " ")
        let reducedSpacesText = alphanumericText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression, range: nil)
        return reducedSpacesText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // Function to check if current line contains the onboarding command
    func doesCurrentLineContainOnboardingCommand(line: String) -> Bool {
        let sanitizedLine = sanitizeText(line)
        let sanitizedCommand = sanitizeText(getOnboardingSmCommand())
        return sanitizedLine.contains(sanitizedCommand)
    }

    @objc private func handleTerminalActiveLineChanged(_ notification: Notification) {
        if let userInfo = notification.userInfo, let activeLine = userInfo["activeLine"] as? String {
            print("Received active line from Terminal: \(activeLine)")
            currentActiveLine = activeLine // Update the current active line
        }
    }
}

