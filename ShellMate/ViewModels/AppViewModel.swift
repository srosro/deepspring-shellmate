import SwiftUI


class AppViewModel: ObservableObject {
    @Published var currentTerminalID: String?
    @Published var currentStateText: String = "No changes on Terminal"
    @Published var updateCounter: Int = 1
    @Published var results: [String: (suggestionsCount: Int, suggestionsHistory: [(UUID, [[String: String]])], updatedAt: Date)] = [:]
    @Published var isGeneratingSuggestion: [String: Bool] = [:]
    
    private var threadIdDict: [String: String] = [:]
    private var currentTerminalStateID: UUID?
    private let additionalSuggestionDelaySeconds: TimeInterval = 2.0
    private let maxSuggestionsPerEvent: Int = 4
    let gptAssistantManager: GPTAssistantManager
    
    init() {
        self.gptAssistantManager = GPTAssistantManager()
        setupNotificationObservers() // Moved notification observer setup to a separate method
    }
    
    private func setupNotificationObservers() { // New method for setting up notification observers
        NotificationCenter.default.addObserver(self, selector: #selector(handleTerminalChangeStarted), name: .terminalContentChangeStarted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTerminalChangeEnded), name: .terminalContentChangeEnded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTerminalWindowIdDidChange(_:)), name: .terminalWindowIdDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRequestTerminalContentAnalysis(_:)), name: .requestTerminalContentAnalysis, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSuggestionGenerationStatusChanged(_:)), name: .suggestionGenerationStatusChanged, object: nil)
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
        guard let userInfo = notification.userInfo,
              let text = userInfo["text"] as? String,
              let windowID = userInfo["currentTerminalWindowID"] as? CGWindowID,
              let source = userInfo["source"] as? String,
              let changeIdentifiedAt = userInfo["changeIdentifiedAt"] as? Double else {
            return
        }
        analyzeTerminalContent(text: text, windowID: windowID, source: source, changeIdentifiedAt: changeIdentifiedAt)
    }

    
    @objc private func handleSuggestionGenerationStatusChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let identifier = userInfo["identifier"] as? String,
              let isGeneratingSuggestion = userInfo["isGeneratingSuggestion"] as? Bool else {
            return
        }
        DispatchQueue.main.async {
            self.isGeneratingSuggestion[identifier] = isGeneratingSuggestion
        }
    }
    
    private func analyzeTerminalContent(text: String, windowID: CGWindowID, source: String, changeIdentifiedAt: Double) {
        guard let currentTerminalId = self.currentTerminalID else {
            return
        }
        self.currentTerminalStateID = UUID()
        guard let terminalStateID = self.currentTerminalStateID else {
            return
        }

        // Log the event when terminal content analysis is requested
        let changedTerminalContentSentToGptAt = Date().timeIntervalSince1970
        MixpanelHelper.shared.trackEvent(name: "terminalContentAnalysisRequested", properties: [
            "currentTerminalId": currentTerminalId,
            "currentTerminalStateID": terminalStateID.uuidString,
            "changeIdentifiedAt": changeIdentifiedAt,
            "changedTerminalContentSentToGptAt": changedTerminalContentSentToGptAt,
            "triggerSource": source
        ])

        Task.detached { [weak self] in
            guard let strongSelf = self else { return }
            guard let threadId = await strongSelf.getOrCreateThreadId(for: currentTerminalId) else { return }

            await strongSelf.processGPTResponse(
                identifier: currentTerminalId,
                terminalStateID: terminalStateID,
                threadId: threadId,
                messageContent: text,
                changeIdentifiedAt: changeIdentifiedAt,
                changedTerminalContentSentToGptAt: changedTerminalContentSentToGptAt,
                source: source)

            DispatchQueue.main.asyncAfter(deadline: .now() + strongSelf.additionalSuggestionDelaySeconds) {
                strongSelf.generateAdditionalSuggestions(
                    identifier: currentTerminalId,
                    terminalStateID: terminalStateID,
                    threadId: threadId,
                    changeIdentifiedAt: Date().timeIntervalSince1970,
                    source: "automaticFollowUpSuggestion"
                )
            }
        }
    }


    private func generateAdditionalSuggestions(identifier: String, terminalStateID: UUID, threadId: String, changeIdentifiedAt: Double, source: String) {
        guard let currentTerminalID = self.currentTerminalID,
              let currentTerminalStateID = self.currentTerminalStateID,
              currentTerminalID == identifier,
              currentTerminalStateID == terminalStateID else {
            return
        }

        if self.currentStateText != "No changes on Terminal" {
            return
        }

        if let suggestionsHistory = results[currentTerminalID]?.suggestionsHistory,
           let lastSuggestions = suggestionsHistory.last?.1,
           lastSuggestions.count >= self.maxSuggestionsPerEvent {
            return
        }

        // Log the event when terminal content analysis is requested
        let changedTerminalContentSentToGptAt = Date().timeIntervalSince1970
        MixpanelHelper.shared.trackEvent(name: "terminalContentAnalysisRequested", properties: [
            "currentTerminalId": currentTerminalID,
            "currentTerminalStateID": terminalStateID.uuidString,
            "changeIdentifiedAt": changeIdentifiedAt,
            "changedTerminalContentSentToGptAt": changedTerminalContentSentToGptAt,
            "triggerSource": source
        ])

        Task.detached { [weak self] in
            guard let strongSelf = self else { return }
            
            await strongSelf.processGPTResponse(
                identifier: identifier,
                terminalStateID: terminalStateID,
                threadId: threadId,
                messageContent: "please generate another suggestion of command. Don't provide a duplicated suggestion",
                changeIdentifiedAt: changeIdentifiedAt,
                changedTerminalContentSentToGptAt: changedTerminalContentSentToGptAt,
                source: source
            )
            
            DispatchQueue.main.asyncAfter(deadline: .now() + strongSelf.additionalSuggestionDelaySeconds) {
                strongSelf.generateAdditionalSuggestions(
                    identifier: identifier,
                    terminalStateID: terminalStateID,
                    threadId: threadId,
                    changeIdentifiedAt: Date().timeIntervalSince1970,
                    source: "automaticFollowUpSuggestion"
                )
            }
        }
    }


    
    @MainActor
    private func getOrCreateThreadId(for identifier: String) async -> String? {
        if let threadId = threadIdDict[identifier] {
            return threadId
        }
        
        do {
            let createdThreadId = try await gptAssistantManager.createThread()
            threadIdDict[identifier] = createdThreadId
            return createdThreadId
        } catch {
            return nil
        }
    }
    
    private func processGPTResponse(identifier: String, terminalStateID: UUID, threadId: String, messageContent: String, changeIdentifiedAt: Double, changedTerminalContentSentToGptAt: Double, source: String) async {
        Task { @MainActor in
            NotificationCenter.default.post(name: .suggestionGenerationStatusChanged, object: nil, userInfo: ["identifier": identifier, "isGeneratingSuggestion": true])
        }
        do {
            let response = try await gptAssistantManager.processMessageInThread(threadId: threadId, messageContent: messageContent)
            if let command = response["command"] as? String,
               let intention = response["intention"] as? String {
                await appendResult(identifier: identifier, terminalStateID: terminalStateID, response: intention, command: command, explanation: "explanation")
            }
        } catch {
            print("Error processing message in thread: \(error.localizedDescription)")
        }
        Task { @MainActor in
            NotificationCenter.default.post(name: .suggestionGenerationStatusChanged, object: nil, userInfo: ["identifier": identifier, "isGeneratingSuggestion": false])
            
            // Log the event when response is received from GPT
            let responseReceivedFromGptAt = Date().timeIntervalSince1970
            let delayToProcessChange = changedTerminalContentSentToGptAt - changeIdentifiedAt
            let delayToGetResponseFromGpt = responseReceivedFromGptAt - changedTerminalContentSentToGptAt
            let totalDelayToProcessChange = responseReceivedFromGptAt - changeIdentifiedAt

            MixpanelHelper.shared.trackEvent(name: "terminalContentAnalysisCompleted", properties: [
                "currentTerminalId": identifier,
                "currentTerminalStateID": terminalStateID.uuidString,
                "changeIdentifiedAt": changeIdentifiedAt,
                "changedTerminalContentSentToGptAt": changedTerminalContentSentToGptAt,
                "responseReceivedFromGptAt": responseReceivedFromGptAt,
                "delayToProcessChange": delayToProcessChange,
                "delayToGetResponseFromGpt": delayToGetResponseFromGpt,
                "totalDelayToProcessChange": totalDelayToProcessChange,
                "triggerSource": source
            ])
        }
    }

    @MainActor
    private func appendResult(identifier: String, terminalStateID: UUID, response: String?, command: String?, explanation: String?) {
        guard let response = response, !response.isEmpty,
              let command = command, !command.isEmpty,
              let explanation = explanation, !explanation.isEmpty else {
            return
        }

        let newEntry = ["gptResponse": response, "suggestedCommand": command, "commandExplanation": explanation]
        let currentTime = Date()

        DispatchQueue.main.async {
            if var windowInfo = self.results[identifier] {
                var batchFound = false
                for (index, batch) in windowInfo.suggestionsHistory.enumerated() where batch.0 == terminalStateID {
                    windowInfo.suggestionsHistory[index].1.append(newEntry)
                    batchFound = true
                    break
                }
                if !batchFound {
                    windowInfo.suggestionsHistory.append((terminalStateID, [newEntry]))
                }
                windowInfo.suggestionsCount += 1
                windowInfo.updatedAt = currentTime
                self.results[identifier] = windowInfo
            } else {
                self.results[identifier] = (suggestionsCount: 1, suggestionsHistory: [(terminalStateID, [newEntry])], updatedAt: currentTime)
            }

            self.updateCounter += 1
            self.writeResultsToFile()
        }
    }

    private func getSharedTemporaryDirectory() -> URL {
        let sharedTempDirectory = URL(fileURLWithPath: "/tmp/shellMateShared")
        
        // Ensure the directory exists
        if !FileManager.default.fileExists(atPath: sharedTempDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: sharedTempDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Failed to create shared temporary directory: \(error)")
            }
        }
        
        return sharedTempDirectory
    }

    private func writeResultsToFile() {
        DispatchQueue.global(qos: .background).async { // Moved file writing to a background thread
            guard let currentTerminalID = self.currentTerminalID,
                  let terminalResults = self.results[currentTerminalID] else {
                return
            }
            let sharedTempDirectory = self.getSharedTemporaryDirectory()
            let filePath = sharedTempDirectory.appendingPathComponent("shellMateCommandSuggestions.json")

            var jsonOutput: [String: String] = [:]
            for (batchIndex, batch) in terminalResults.suggestionsHistory.enumerated() {
                for (suggestionIndex, gptResponse) in batch.1.enumerated() {
                    if let suggestedCommand = gptResponse["suggestedCommand"] {
                        let jsonId = "\(batchIndex + 1).\(suggestionIndex + 1)"
                        jsonOutput[jsonId] = suggestedCommand
                    }
                }
            }

            do {
                let jsonData = try JSONEncoder().encode(jsonOutput)
                try jsonData.write(to: filePath, options: .atomic)
            } catch {
                print("Failed to write JSON data to file: \(error.localizedDescription)")
            }
        }
    }
}
