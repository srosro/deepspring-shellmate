import SwiftUI


@main
struct ShellBuddyApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) var appDelegate
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}


class AppViewModel: ObservableObject {
    @Published var currentTerminalID: String?
    @Published var currentStateText: String
    @Published var updateCounter: Int = 0
    @Published var results: [String: (suggestionsCount: Int, suggestionsHistory: [(UUID, [[String: String]])], updatedAt: Date)]

    init() {
        self.results = [:]
        self.currentTerminalID = "dummyID"
        self.currentStateText = "No changes on Terminal"
        self.fakeAppendResults()
        // Add observers for text change notifications
        NotificationCenter.default.addObserver(self, selector: #selector(handleTerminalChangeStarted), name: .terminalContentChangeStarted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTerminalChangeEnded), name: .terminalContentChangeEnded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTerminalWindowIdDidChange(_:)), name: .terminalWindowIdDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRequestTerminalContentAnalysis(_:)), name: .requestTerminalContentAnalysis, object: nil)
    }

    @objc private func handleTerminalChangeStarted() {
        self.currentStateText = "Detecting changes..."
    }

    @objc private func handleTerminalChangeEnded() {
        self.currentStateText = "No changes on Terminal"
        
        // Process trigger the generation of a suggestion.
    }
    
    @objc private func handleTerminalWindowIdDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let windowID = userInfo["terminalWindowID"] as? CGWindowID else {
            return
        }
        
        self.currentTerminalID = String(windowID)
    }
    
    @objc private func handleRequestTerminalContentAnalysis(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let text = userInfo["text"] as? String,
           let windowID = userInfo["currentTerminalWindowID"] as? CGWindowID,
           let source = userInfo["source"] as? String {
            print("Text: \(text)")
            print("Window ID: \(windowID)")
            print("Source: \(source)")
        }
    }

    private func appendResult(identifier: String, terminalStateID: UUID, response: String?, command: String?, explanation: String?) {
        // Ensure all parameters are provided and not empty
        guard let response = response, !response.isEmpty,
              let command = command, !command.isEmpty,
              let explanation = explanation, !explanation.isEmpty else {
            //self.logger.error("Missing or empty parameter(s) for identifier \(identifier). Response: \(String(describing: response)), Command: \(String(describing: command)), Explanation: \(String(describing: explanation))")
            return
        }
        
        let newEntry = ["gptResponse": response, "suggestedCommand": command, "commandExplanation": explanation]
        let currentTime = Date() // Get the current time

        DispatchQueue.main.async {
            //self.logger.debug("Appending result for identifier \(identifier). Response: \(response), Command: \(command), Explanation: \(explanation)")
            
            if var windowInfo = self.results[identifier] {
                var batchFound = false
                
                // Look for the batch with the matching UUID
                for (index, batch) in windowInfo.suggestionsHistory.enumerated() {
                    if batch.0 == terminalStateID {
                        // Append the new entry to the found batch
                        windowInfo.suggestionsHistory[index].1.append(newEntry)
                        batchFound = true
                        break
                    }
                }
                
                if !batchFound {
                    // Create a new batch if no batch with the matching UUID was found
                    windowInfo.suggestionsHistory.append((terminalStateID, [newEntry]))
                }
                
                // Increment the suggestions count
                windowInfo.suggestionsCount += 1
                // Update the timestamp
                windowInfo.updatedAt = currentTime
                self.results[identifier] = windowInfo
            } else {
                // Initialize if this is the first entry for this identifier
                self.results[identifier] = (suggestionsCount: 1, suggestionsHistory: [(terminalStateID, [newEntry])], updatedAt: currentTime)
            }
            
            self.updateCounter += 1  // Increment the counter to notify a change
            // Write results to file
            self.writeResultsToFile()
        }
    }
    func fakeAppendResults() {
        let terminalStateID1 = UUID()
        let terminalStateID2 = UUID()

        let fakeData: [(String, String, String)] = [
            ("Showing the user's intention", "echo 'Hello, World!' [1]", "prints 'Hello, World!' [1]"),
            ("Hello, World! [2]", "echo 'Hello, World!' [2]", "prints 'Hello, World!' [2]"),
            ("Hello, World! [3]", "echo 'Hello, World!' [3]", "prints 'Hello, World!' [3]"),
            ("Instead of the actual command", "echo 'Hello, World!' [4]", "prints 'Hello, World!' [4]"),
            ("Hello, World! [5]", "echo 'Hello, World!' [5]", "prints 'Hello, World!' [5]"),
            ("Hello, World! [6]", "echo 'Hello, World!' [6]", "prints 'Hello, World!' [6]"),
        ]

        var counter = 0

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if counter < fakeData.count {
                let identifier = self.currentTerminalID ?? "dummyID"
                let (response, command, explanation) = fakeData[counter]
                let terminalStateID = counter % 2 == 0 ? terminalStateID1 : terminalStateID2
                self.appendResult(identifier: identifier, terminalStateID: terminalStateID, response: response, command: command, explanation: explanation)
                counter += 1
                self.currentStateText = self.currentStateText == "Detecting changes..." ? "No changes on Terminal" : "Detecting changes..."
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func getDownloadsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
        return paths[0]
    }

    // Helper function to write JSON data to a file
    private func writeResultsToFile() {
        // Use a shared directory accessible by both applications
        let downloadsDirectory = getDownloadsDirectory()
        let filePath = downloadsDirectory.appendingPathComponent("shellBuddyCommandSuggestions.json")

        // Get the currentTerminalID
        guard let currentTerminalID = self.currentTerminalID else {
            //self.logger.debug("No current terminal ID found.")
            return
        }
        
        // Prepare the JSON output
        var jsonOutput: [String: String] = [:]
        
        if let terminalResults = self.results[currentTerminalID] {
            for (batchIndex, batch) in terminalResults.suggestionsHistory.enumerated() {
                for (suggestionIndex, gptResponse) in batch.1.enumerated() {
                    if let suggestedCommand = gptResponse["suggestedCommand"] {
                        let jsonId = "\(batchIndex + 1).\(suggestionIndex + 1)"
                        jsonOutput[jsonId] = suggestedCommand
                    }
                }
            }
        }
        
        // Encode the JSON output
        do {
            let jsonData = try JSONEncoder().encode(jsonOutput)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                try jsonString.write(to: filePath, atomically: true, encoding: .utf8)
                //self.logger.debug("Successfully wrote results to file at \(filePath).")
            }
        } catch {
            //self.logger.error("Failed to write JSON data to file: \(error.localizedDescription)")
        }
    }
}

