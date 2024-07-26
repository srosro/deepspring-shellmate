import SwiftUI
import Combine


class AppViewModel: ObservableObject {
    @Published var currentTerminalID: String?
    @Published var currentStateText: String = "No changes on Terminal"
    @Published var updateCounter: Int = 1
    @Published var results: [String: (suggestionsCount: Int, suggestionsHistory: [(UUID, [[String: String]])], updatedAt: Date)] = [:]
    @Published var isGeneratingSuggestion: [String: Bool] = [:]
    @Published var hasUserValidatedOwnOpenAIAPIKey: Bool = false
    @Published var isAssistantSetupSuccessful: Bool = false
    @Published var areNotificationObserversSetup: Bool = false

    private var threadIdDict: [String: String] = [:]
    private var currentTerminalStateID: UUID?
    private let additionalSuggestionDelaySeconds: TimeInterval = 3.0
    private let maxSuggestionsPerEvent: Int = 4
    private var shouldGenerateFollowUpSuggestionsFlag: Bool = true
    private var gptAssistantManager: GPTAssistantManager = GPTAssistantManager.shared

    // UserDefaults keys
    private let GPTSuggestionsFreeTierCountKey = "GPTSuggestionsFreeTierCount"
    private let hasGPTSuggestionsFreeTierCountReachedLimitKey = "hasGPTSuggestionsFreeTierCountReachedLimit"
    
    // Limit for free tier suggestions
    let GPTSuggestionsFreeTierLimit = 150
    
    @Published var GPTSuggestionsFreeTierCount: Int {
        didSet {
            UserDefaults.standard.set(GPTSuggestionsFreeTierCount, forKey: GPTSuggestionsFreeTierCountKey)
            updateHasGPTSuggestionsFreeTierCountReachedLimit()
        }
    }
    @Published var hasGPTSuggestionsFreeTierCountReachedLimit: Bool {
        didSet {
            UserDefaults.standard.set(hasGPTSuggestionsFreeTierCountReachedLimit, forKey: hasGPTSuggestionsFreeTierCountReachedLimitKey)
        }
    }
    
    @Published var hasInternetConnection: Bool = true {
        didSet {
            if hasInternetConnection == false {
                print("Internet connection lost. Starting check loop.")
                startInternetCheckLoop()
            } else if hasInternetConnection == true && !areNotificationObserversSetup {
                print("Internet connection restored. Setting up assistant and notification observers.")
                Task {
                    await initializeAssistant()
                }
            }
        }
    }
    
    init() {
        self.GPTSuggestionsFreeTierCount = UserDefaults.standard.integer(forKey: GPTSuggestionsFreeTierCountKey)
        self.hasGPTSuggestionsFreeTierCountReachedLimit = UserDefaults.standard.bool(forKey: hasGPTSuggestionsFreeTierCountReachedLimitKey)
        updateHasGPTSuggestionsFreeTierCountReachedLimit()
        
        Task {
            await initializeAssistant()
        }
    }
    
    func startInternetCheckLoop() {
        DispatchQueue.global().async {
            while !self.hasInternetConnection {
                Task {
                    let isConnected = await checkInternetConnection()
                    if isConnected {
                        DispatchQueue.main.async {
                            self.hasInternetConnection = true
                        }
                        return
                    }
                }
                sleep(1) // 1 second delay
            }
        }
    }
    
    func initializeAssistant() async {
        print("Starting assistant setup...")
        let success = await gptAssistantManager.setupAssistant()
        DispatchQueue.main.async {
            self.isAssistantSetupSuccessful = success
            if success {
                print("Assistant setup successful.")
                print("Assistant ID: \(self.gptAssistantManager.assistantId)")
                self.setupNotificationObservers()
            } else {
                print("Assistant setup failed.")
                self.hasInternetConnection = false
            }
        }
    }
    
    func ensureCurrentTerminalIDHasValue() {
        if currentTerminalID == nil || currentTerminalID?.isEmpty == true {
            print("DANBUG: currentTerminalID is nil or empty. Posting reinitializeTerminalWindowID notification.")
            NotificationCenter.default.post(name: .reinitializeTerminalWindowID, object: nil)
        } else {
            print("DANBUG: currentTerminalID has a value: \(currentTerminalID!)")
        }
    }
    
    private func setupNotificationObservers() {
        guard !areNotificationObserversSetup else {
            print("Notification observers are already set up.")
            return
        }

        NotificationCenter.default.addObserver(self, selector: #selector(handleTerminalChangeStarted), name: .terminalContentChangeStarted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTerminalChangeEnded), name: .terminalContentChangeEnded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTerminalWindowIdDidChange(_:)), name: .terminalWindowIdDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRequestTerminalContentAnalysis(_:)), name: .requestTerminalContentAnalysis, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSuggestionGenerationStatusChanged(_:)), name: .suggestionGenerationStatusChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUserValidatedOwnOpenAIAPIKey), name: .userValidatedOwnOpenAIAPIKey, object: nil)
        areNotificationObserversSetup = true
        ensureCurrentTerminalIDHasValue() // Necessary as sometimes the AppViewModel will only setup the observer for handleTerminalWindowIdDidChange after the first setup was run, so the currentTerminalID would be empty, causing errors
    }
    
    @objc private func handleTerminalChangeStarted() {
        if hasGPTSuggestionsFreeTierCountReachedLimit && !hasUserValidatedOwnOpenAIAPIKey {
            return
        }
        self.currentStateText = "Detecting changes..."
    }
    
    @objc private func handleTerminalChangeEnded() {
        self.currentStateText = "No changes on Terminal"
        // Process trigger the generation of a suggestion.
    }
    
    @MainActor @objc private func handleTerminalWindowIdDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let windowID = userInfo["terminalWindowID"] as? CGWindowID else {
            return
        }
        self.currentTerminalID = String(windowID)
        initializeSampleCommandForOnboardingIfNeeded(for: String(windowID))
    }
    
    @objc private func handleRequestTerminalContentAnalysis(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let text = userInfo["text"] as? String,
              let windowID = userInfo["currentTerminalWindowID"] as? CGWindowID,
              let source = userInfo["source"] as? String,
              let changeIdentifiedAt = userInfo["changeIdentifiedAt"] as? Double else {
            return
        }
        
        if hasGPTSuggestionsFreeTierCountReachedLimit && !hasUserValidatedOwnOpenAIAPIKey {
            print("Suggestions limit reached and user has not validated their own OpenAI API key.")
            return
        }
        if !hasInternetConnection {
            print("No internet connection.")
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
    
    @objc private func handleUserValidatedOwnOpenAIAPIKey(_ notification: Notification) {
        if let userInfo = notification.userInfo, let isValid = userInfo["isValid"] as? Bool, isValid == true {
            self.hasUserValidatedOwnOpenAIAPIKey = true
            
            // Clear the entire threadIdDict
            threadIdDict.removeAll()
            
            // Create a new instance of gptAssistantManager
            gptAssistantManager = GPTAssistantManager.shared
        } else {
            self.hasUserValidatedOwnOpenAIAPIKey = false
        }
    }
    
    private func analyzeTerminalContent(text: String, windowID: CGWindowID, source: String, changeIdentifiedAt: Double) {
        guard let currentTerminalId = self.currentTerminalID else {
            print("DANBUG: Current terminal ID is nil.")
            return
        }
        self.currentTerminalStateID = UUID()
        guard let terminalStateID = self.currentTerminalStateID else {
            print("DANBUG: Current terminal state ID is nil.")
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
            guard let strongSelf = self else {
                print("DANBUG: Self is nil.")
                return
            }
            do {
                print("DANBUG: Calling getOrCreateThreadId for currentTerminalId: \(currentTerminalId)")
                let threadId = try await strongSelf.getOrCreateThreadId(for: currentTerminalId)
                await strongSelf.processGPTResponse(
                    identifier: currentTerminalId,
                    terminalStateID: terminalStateID,
                    threadId: threadId,
                    messageContent: text,
                    changeIdentifiedAt: changeIdentifiedAt,
                    changedTerminalContentSentToGptAt: changedTerminalContentSentToGptAt,
                    source: source
                )
                
                if strongSelf.shouldGenerateFollowUpSuggestionsFlag {
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
            } catch {
                print("DANBUG: Error getting or creating thread ID: \(error.localizedDescription)")
                if error.localizedDescription.contains("The network connection was lost") || error.localizedDescription.contains("The request timed out") {
                    DispatchQueue.main.async {
                        strongSelf.hasInternetConnection = false
                        strongSelf.isGeneratingSuggestion[currentTerminalId] = false
                    }
                }
            }
        }
    }

    
    private func generateAdditionalSuggestions(identifier: String, terminalStateID: UUID, threadId: String, changeIdentifiedAt: Double, source: String) {
        if hasGPTSuggestionsFreeTierCountReachedLimit && !hasUserValidatedOwnOpenAIAPIKey {
            return
        }
        
        if !hasInternetConnection {
            return
        }
        
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
            
            if strongSelf.shouldGenerateFollowUpSuggestionsFlag {
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
    }
    
    @MainActor
    private func getOrCreateThreadId(for identifier: String) async throws -> String {
        print("DANBUG: getOrCreateThreadId called for identifier: \(identifier)")

        if let threadId = threadIdDict[identifier] {
            print("DANBUG: Found existing thread ID for identifier \(identifier): \(threadId)")
            return threadId
        }
        
        print("DANBUG: No existing thread ID for identifier \(identifier). Creating a new thread ID.")
        do {
            let createdThreadId = try await gptAssistantManager.createThread()
            threadIdDict[identifier] = createdThreadId
            print("DANBUG: Created new thread ID for identifier \(identifier): \(createdThreadId)")
            return createdThreadId
        } catch {
            print("DANBUG: Failed to create thread ID for identifier \(identifier) with error: \(error)")
            throw error
        }
    }

    
    private func processGPTResponse(identifier: String, terminalStateID: UUID, threadId: String, messageContent: String, changeIdentifiedAt: Double, changedTerminalContentSentToGptAt: Double, source: String) async {
        Task { @MainActor in
            NotificationCenter.default.post(name: .suggestionGenerationStatusChanged, object: nil, userInfo: ["identifier": identifier, "isGeneratingSuggestion": true])
        }
        do {
            let response = try await gptAssistantManager.processMessageInThread(threadId: threadId, messageContent: messageContent)
            if let command = response["command"] as? String,
               let commandExplanation = response["commandExplanation"] as? String,
               let intention = response["intention"] as? String,
               let shouldGenerateFollowUpSuggestions = response["shouldGenerateFollowUpSuggestions"] as? Bool {
                await appendResult(identifier: identifier, terminalStateID: terminalStateID, response: intention, command: command, explanation: commandExplanation)
                shouldGenerateFollowUpSuggestionsFlag = shouldGenerateFollowUpSuggestions
            }
        } catch {
            print("Error processing message in thread: \(error.localizedDescription)")
            if error.localizedDescription.contains("The network connection was lost") || error.localizedDescription.contains("The request timed out") {
                DispatchQueue.main.async {
                    self.hasInternetConnection = false
                    self.isGeneratingSuggestion[identifier] = false
                }
            }
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
    
    private func incrementGPTSuggestionsFreeTierCount(by count: Int) {
        GPTSuggestionsFreeTierCount += count
    }
    private func updateHasGPTSuggestionsFreeTierCountReachedLimit() {
        hasGPTSuggestionsFreeTierCountReachedLimit = GPTSuggestionsFreeTierCount >= GPTSuggestionsFreeTierLimit
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
            if !self.hasUserValidatedOwnOpenAIAPIKey {
                self.incrementGPTSuggestionsFreeTierCount(by: 1)
            }
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
            let filePath = getShellMateCommandSuggestionsFilePath()
            
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
    
    @MainActor
    func initializeSampleCommandForOnboardingIfNeeded(for terminalID: String?) {
        guard let terminalID = terminalID else {
            return
        }
        
        let showOnboarding = UserDefaults.standard.object(forKey: "showOnboarding") as? Bool ?? true
        
        guard showOnboarding else {
            return
        }
        
        if self.results[terminalID]?.suggestionsHistory.isEmpty ?? true {
            self.appendResult(identifier: terminalID, terminalStateID: UUID(), response: "Complete the task", command: "sm \"\(getOnboardingSmCommand())\"", explanation: "This is a sample command to show you how to use ShellMate.")
        }
    }
}
