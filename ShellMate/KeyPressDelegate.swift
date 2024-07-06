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
            print("KeyPressDelegate - Key press detected.")
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

    func isValidSMCommand(line: String) -> Bool {
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
    
    private func processEnterKey() {
        print("Enter key pressed in Terminal")
        if let activeLine = currentActiveLine {
            print("Current active line: \(activeLine)")
            let isValidSMCommand = isValidSMCommand(line: activeLine)
            print("Is valid 'sm' command: \(isValidSMCommand)")
        } else {
            print("No active line available.")
        }
    }

    @objc private func handleTerminalActiveLineChanged(_ notification: Notification) {
        if let userInfo = notification.userInfo, let activeLine = userInfo["activeLine"] as? String {
            print("Received active line from Terminal: \(activeLine)")
            currentActiveLine = activeLine // Update the current active line
        }
    }
}
