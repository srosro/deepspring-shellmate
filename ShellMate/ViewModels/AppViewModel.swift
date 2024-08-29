import AXSwift
import Combine
import SwiftUI

enum APIKeyValidationState {
  case valid
  case invalid
  case usingFreeTier
}

class AppViewModel: ObservableObject {
  @Published var currentTerminalID: String?
  @Published var currentStateText: String = "No changes on Terminal"
  @Published var updateCounter: Int = 1
  @Published var results:
    [String: (
      suggestionsCount: Int, suggestionsHistory: [(UUID, [[String: String]])], updatedAt: Date
    )] = [:]
  @Published var isGeneratingSuggestion: [String: Bool] = [:]
  @Published var pauseSuggestionGeneration: [String: Bool] = [:]
  @Published var hasUserValidatedOwnOpenAIAPIKey: APIKeyValidationState = .usingFreeTier
  @Published var isAssistantSetupSuccessful: Bool = false
  @Published var areNotificationObserversSetup: Bool = false
  @Published var shouldTroubleShootAPIKey: Bool = false
  @Published var shouldShowNetworkIssueWarning: Bool = false
  @Published var shouldShowSamAltmansFace: Bool = true
  @Published var pendingProTips:
    [String: (
      proTipIdx: Int, proTipEntry: [String: String], terminalStateID: UUID, currentTime: Date
    )] = [:]

  private var consecutiveFailedInternetChecks: Int = 0
  private var internetConnectionGracePeriodTask: Task<Void, Never>?

  private var threadIdDict: [String: String] = [:]
  private var currentTerminalStateID: UUID?
  private let additionalSuggestionDelaySeconds: TimeInterval = 3.0
  private let maxSuggestionsPerEvent: Int = 4
  private var shouldGenerateFollowUpSuggestionsFlag: Bool = true
  private var gptAssistantManager: GPTAssistantManager = GPTAssistantManager.shared

  // UserDefaults keys
  private let GPTSuggestionsFreeTierCountKey = "GPTSuggestionsFreeTierCount"
  private let hasGPTSuggestionsFreeTierCountReachedLimitKey =
    "hasGPTSuggestionsFreeTierCountReachedLimit"
  private var terminalIDCheckTimer: Timer?
  private var apiKeyValidationDebounceTask: DispatchWorkItem?

  // Limit for free tier suggestions
  @AppStorage("GPTSuggestionsFreeTierLimit") private(set) var GPTSuggestionsFreeTierLimit: Int = 100

  @Published var GPTSuggestionsFreeTierCount: Int {
    didSet {
      print("[][] did set")
      UserDefaults.standard.set(GPTSuggestionsFreeTierCount, forKey: GPTSuggestionsFreeTierCountKey)
      updateHasGPTSuggestionsFreeTierCountReachedLimit()
    }
  }
  @Published var hasGPTSuggestionsFreeTierCountReachedLimit: Bool {
    didSet {
      UserDefaults.standard.set(
        hasGPTSuggestionsFreeTierCountReachedLimit,
        forKey: hasGPTSuggestionsFreeTierCountReachedLimitKey)
    }
  }

  @Published var hasInternetConnection: Bool = true {
    didSet {
      if hasInternetConnection == false {
        print("Internet connection lost. Starting check loop.")
        startInternetCheckLoop()
      } else if hasInternetConnection == true {
        print("Internet connection restored. Resetting connection check state.")
        resetInternetConnectionCheckState()

        if !areNotificationObserversSetup {
          print("Setting up assistant and notification observers.")
          Task {
            await initializeAssistant()
          }
        }
      }
    }
  }

  private func startInternetConnectionGracePeriod() {
    // Cancel any existing grace period task
    internetConnectionGracePeriodTask?.cancel()

    internetConnectionGracePeriodTask = Task.detached { [weak self] in
      guard let self = self else { return }

      do {
        // Wait for 10 seconds grace period
        try await Task.sleep(nanoseconds: 10 * 1_000_000_000)

        // Check internet connection status after the grace period
        let isConnected = await checkInternetConnection()
        if !isConnected {
          print("Internet connection still down after grace period. Showing network issue warning.")
          DispatchQueue.main.async {
            self.shouldShowNetworkIssueWarning = true
          }
        } else {
          print("Internet connection restored during grace period.")
          self.resetInternetConnectionCheckState()
        }
      } catch {
        print("Error during grace period task: \(error.localizedDescription)")
      }
    }
  }

  private func resetInternetConnectionCheckState() {
    consecutiveFailedInternetChecks = 0
    shouldShowNetworkIssueWarning = false
    internetConnectionGracePeriodTask?.cancel()
    internetConnectionGracePeriodTask = nil
  }

  init() {
    self.GPTSuggestionsFreeTierCount = UserDefaults.standard.integer(
      forKey: GPTSuggestionsFreeTierCountKey)
    self.hasGPTSuggestionsFreeTierCountReachedLimit = UserDefaults.standard.bool(
      forKey: hasGPTSuggestionsFreeTierCountReachedLimitKey)
    updateHasGPTSuggestionsFreeTierCountReachedLimit()

    NotificationCenter.default.addObserver(
      self, selector: #selector(handleUserValidatedOwnOpenAIAPIKey),
      name: .userValidatedOwnOpenAIAPIKey, object: nil)

    Task {
      await initializeAssistant()
    }
  }

  // Method to calculate the likelihood
  func calculateSamAltmansFaceLikelihood() {
    let n = Double(GPTSuggestionsFreeTierCount)
    let adjustedLikelihood = min(100, (1.0 / (1.5 + n / 10)) * 100)
    let randomValue = Double.random(in: 0...100)
    shouldShowSamAltmansFace = randomValue <= adjustedLikelihood

    // DEBUG statement
    print(
      "DEBUG: GPTSuggestionsFreeTierCount: \(GPTSuggestionsFreeTierCount), Adjusted Likelihood: \(adjustedLikelihood), Random Value: \(randomValue), Should Show Sam Altman's Face: \(shouldShowSamAltmansFace)"
    )
  }

  func startInternetCheckLoop() {
    DispatchQueue.global().async {
      self.consecutiveFailedInternetChecks = 0  // Reset the counter at the start of the loop

      while !self.hasInternetConnection {
        Task {
          let isConnected = await checkInternetConnection()
          if isConnected {
            DispatchQueue.main.async {
              self.hasInternetConnection = true
            }
            return
          } else {
            DispatchQueue.main.async {
              self.consecutiveFailedInternetChecks += 1
              print("Internet check failed. Counter: \(self.consecutiveFailedInternetChecks)")

              if self.consecutiveFailedInternetChecks == 3 {
                print("Three consecutive failed internet checks. Starting grace period.")
                self.startInternetConnectionGracePeriod()
                return
              }
            }
          }
        }
        sleep(1)  // 1 second delay
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
        self.shouldTroubleShootAPIKey = false
        self.setupNotificationObservers()
      } else {
        print("Assistant setup failed.")
        Task {
          print("Checking internet connection...")
          let isConnected = await checkInternetConnection()
          DispatchQueue.main.async {
            print("DEBUG: Internet connection check result: \(isConnected)")
            if isConnected {
              print("DEBUG: Assistant setup failed and has internet.")
              self.shouldTroubleShootAPIKey = true
            } else {
              print("DEBUG: Assistant setup failed and has no internet.")
              self.hasInternetConnection = false
            }
          }
        }
      }
    }
  }

  func startCheckingTerminalID() {
    terminalIDCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
      [weak self] _ in
      self?.ensureCurrentTerminalIDHasValue()
    }
  }

  func stopCheckingTerminalID() {
    terminalIDCheckTimer?.invalidate()
    terminalIDCheckTimer = nil
  }

  func ensureCurrentTerminalIDHasValue() {
    if currentTerminalID == nil || currentTerminalID?.isEmpty == true {
      print(
        "DEBUG: currentTerminalID is nil or empty. Posting reinitializeTerminalWindowID notification."
      )
      NotificationCenter.default.post(name: .reinitializeTerminalWindowID, object: nil)
    } else {
      print("DEBUG: currentTerminalID has a value: \(currentTerminalID!)")
      stopCheckingTerminalID()  // Stop the timer once a valid ID is found
    }
  }

  private func setupNotificationObservers() {
    guard !areNotificationObserversSetup else {
      print("Notification observers are already set up.")
      return
    }

    NotificationCenter.default.addObserver(
      self, selector: #selector(handleTerminalChangeStarted), name: .terminalContentChangeStarted,
      object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleTerminalChangeEnded), name: .terminalContentChangeEnded,
      object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleTerminalWindowIdDidChange(_:)),
      name: .terminalWindowIdDidChange, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleRequestTerminalContentAnalysis(_:)),
      name: .requestTerminalContentAnalysis, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleSuggestionGenerationStatusChanged(_:)),
      name: .suggestionGenerationStatusChanged, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleUserAcceptedFreeCredits), name: .userAcceptedFreeCredits,
      object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleOnboardingStepUpdate(_:)),
      name: .forwardOnboardingStepToAppViewModel, object: nil)
    areNotificationObserversSetup = true
    startCheckingTerminalID()  // Necessary as sometimes the AppViewModel will only setup the observer for handleTerminalWindowIdDidChange after the first setup was run, so the currentTerminalID would be empty, causing errors
  }

  @objc private func handleTerminalChangeStarted() {
    if hasGPTSuggestionsFreeTierCountReachedLimit
      && hasUserValidatedOwnOpenAIAPIKey == .usingFreeTier
    {
      return
    } else if hasUserValidatedOwnOpenAIAPIKey == .invalid {
      return
    }
    guard let terminalID = currentTerminalID, pauseSuggestionGeneration[terminalID] != true else {
      return
    }
    self.currentStateText = "Detecting changes..."
  }

  @objc private func handleTerminalChangeEnded() {
    guard let terminalID = currentTerminalID, pauseSuggestionGeneration[terminalID] != true else {
      return
    }
    self.currentStateText = "No changes on Terminal"
  }

  @MainActor
  @objc private func handleTerminalWindowIdDidChange(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
      let windowID = userInfo["terminalWindowID"] as? CGWindowID
    else {
      return
    }
    let terminalID = String(windowID)
    self.currentTerminalID = terminalID
    initializeSampleCommandForOnboardingIfNeeded(for: terminalID)

    checkAndInitializePauseFlag(for: terminalID)
  }

  @objc private func handleRequestTerminalContentAnalysis(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
      let text = userInfo["text"] as? String,
      let windowID = userInfo["currentTerminalWindowID"] as? CGWindowID,
      let source = userInfo["source"] as? String,
      let changeIdentifiedAt = userInfo["changeIdentifiedAt"] as? Double
    else {
      return
    }

    if hasGPTSuggestionsFreeTierCountReachedLimit
      && hasUserValidatedOwnOpenAIAPIKey == .usingFreeTier
    {
      return
    } else if hasUserValidatedOwnOpenAIAPIKey == .invalid {
      return
    }

    if !hasInternetConnection {
      print("No internet connection.")
      return
    }
    analyzeTerminalContent(
      text: text, windowID: windowID, source: source, changeIdentifiedAt: changeIdentifiedAt)
  }

  @objc private func handleSuggestionGenerationStatusChanged(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
      let identifier = userInfo["identifier"] as? String,
      let isGeneratingSuggestion = userInfo["isGeneratingSuggestion"] as? Bool
    else {
      return
    }
    DispatchQueue.main.async {
      self.isGeneratingSuggestion[identifier] = isGeneratingSuggestion
      self.calculateSamAltmansFaceLikelihood()
    }
  }

  @objc private func handleUserValidatedOwnOpenAIAPIKey(_ notification: Notification) {
    print("DEBUG: handleUserValidatedOwnOpenAIAPIKey called")

    // Cancel any existing debounced task
    apiKeyValidationDebounceTask?.cancel()

    // Debounce logic
    apiKeyValidationDebounceTask = DispatchWorkItem { [weak self] in
      guard let self = self else { return }

      // Step 1: Determine the new validation state
      self.determineAPIKeyValidationState(from: notification)

      // Step 2: Process the assistant initialization for valid or acceptable free tier usage
      if self.hasUserValidatedOwnOpenAIAPIKey == .valid
        || (self.hasUserValidatedOwnOpenAIAPIKey == .usingFreeTier
          && !self.hasGPTSuggestionsFreeTierCountReachedLimit)
      {
        self.processAssistantInitialization()
      } else {
        print("DEBUG: User's API key is invalid or free tier limit has been reached")
      }
    }

    // Execute the task after a delay of 0.25 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: apiKeyValidationDebounceTask!)
  }

  @objc private func handleUserAcceptedFreeCredits() {
    // Increase the limit for free tier suggestions by 2000
    GPTSuggestionsFreeTierLimit += 2000

    // Check if the free tier count has reached the limit again
    updateHasGPTSuggestionsFreeTierCountReachedLimit()

    print("User accepted free credits. New limit: \(GPTSuggestionsFreeTierLimit)")
  }

  @objc private func handleOnboardingStepUpdate(_ notification: Notification) {
    guard let newStep = notification.userInfo?["newStep"] as? Int else {
      return
    }

    // Get the current terminal ID
    guard let terminalID = currentTerminalID else {
      return
    }

    // Ensure the call to appendProTip happens on the main actor
    Task { @MainActor in
      appendProTip(identifier: terminalID, proTipIdx: newStep)
      print(
        "DEBUG: Onboarding step \(newStep) will trigger appendProTip for terminal ID \(terminalID)")
    }
  }

  private func determineAPIKeyValidationState(from notification: Notification) {
    if let userInfo = notification.userInfo, let isValid = userInfo["isValid"] as? Bool {
      self.hasUserValidatedOwnOpenAIAPIKey = isValid ? .valid : .invalid
    } else {
      print("DEBUG: User's API key validation state is unknown (nil)")
      self.hasUserValidatedOwnOpenAIAPIKey = .usingFreeTier
      print(
        "DEBUG: hasUserValidatedOwnOpenAIAPIKey set to usingFreeTier due to nil validation state")
    }
  }

  private func processAssistantInitialization() {
    Task {
      print("DEBUG: Starting assistant initialization")
      await self.initializeAssistant()
      DispatchQueue.main.async {
        print("DEBUG: Assistant initialization completed")

        // Clear the entire threadIdDict
        self.threadIdDict.removeAll()
        print("DEBUG: threadIdDict cleared")
      }
    }
  }

  private func analyzeTerminalContent(
    text: String, windowID: CGWindowID, source: String, changeIdentifiedAt: Double
  ) {
    guard let currentTerminalId = self.currentTerminalID else {
      print("DEBUG: Current terminal ID is nil.")
      return
    }

    guard pauseSuggestionGeneration[currentTerminalId] != true else {
      print("Content analysis is paused for terminal ID: \(currentTerminalId)")
      return
    }

    self.currentTerminalStateID = UUID()
    guard let terminalStateID = self.currentTerminalStateID else {
      print("DEBUG: Current terminal state ID is nil.")
      return
    }

    // Log the event when terminal content analysis is requested
    let changedTerminalContentSentToGptAt = Date().timeIntervalSince1970
    MixpanelHelper.shared.trackEvent(
      name: "terminalContentAnalysisRequested",
      properties: [
        "currentTerminalId": currentTerminalId,
        "currentTerminalStateID": terminalStateID.uuidString,
        "changeIdentifiedAt": changeIdentifiedAt,
        "changedTerminalContentSentToGptAt": changedTerminalContentSentToGptAt,
        "triggerSource": source,
      ])

    Task.detached { [weak self] in
      guard let strongSelf = self else {
        print("DEBUG: Self is nil.")
        return
      }
      do {
        print("DEBUG: Calling getOrCreateThreadId for currentTerminalId: \(currentTerminalId)")
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
          DispatchQueue.main.asyncAfter(
            deadline: .now() + strongSelf.additionalSuggestionDelaySeconds
          ) {
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
        print("DEBUG: Error getting or creating thread ID: \(error.localizedDescription)")

        if error.localizedDescription.contains("The network connection was lost")
          || error.localizedDescription.contains("The request timed out")
        {
          DispatchQueue.main.async {
            strongSelf.hasInternetConnection = false
            strongSelf.isGeneratingSuggestion[currentTerminalId] = false
          }
        } else if error.localizedDescription.contains(
          "The Internet connection appears to be offline")
        {
          DispatchQueue.main.async {
            strongSelf.shouldShowNetworkIssueWarning = true
            strongSelf.hasInternetConnection = false
            strongSelf.isGeneratingSuggestion[currentTerminalId] = false
          }
        }
      }
    }
  }

  private func generateAdditionalSuggestions(
    identifier: String, terminalStateID: UUID, threadId: String, changeIdentifiedAt: Double,
    source: String
  ) {
    if hasGPTSuggestionsFreeTierCountReachedLimit
      && hasUserValidatedOwnOpenAIAPIKey == .usingFreeTier
    {
      return
    } else if hasUserValidatedOwnOpenAIAPIKey == .invalid {
      return
    }
    guard pauseSuggestionGeneration[identifier] != true else {
      print("Additional suggestion generation is paused for terminal ID: \(identifier)")
      return
    }

    if !hasInternetConnection {
      return
    }

    guard let currentTerminalID = self.currentTerminalID,
      let currentTerminalStateID = self.currentTerminalStateID,
      currentTerminalID == identifier,
      currentTerminalStateID == terminalStateID
    else {
      return
    }

    if self.currentStateText != "No changes on Terminal" {
      return
    }

    if let suggestionsHistory = results[currentTerminalID]?.suggestionsHistory,
      let lastSuggestions = suggestionsHistory.last?.1,
      lastSuggestions.count >= self.maxSuggestionsPerEvent
    {
      return
    }

    // Log the event when terminal content analysis is requested
    let changedTerminalContentSentToGptAt = Date().timeIntervalSince1970
    MixpanelHelper.shared.trackEvent(
      name: "terminalContentAnalysisRequested",
      properties: [
        "currentTerminalId": currentTerminalID,
        "currentTerminalStateID": terminalStateID.uuidString,
        "changeIdentifiedAt": changeIdentifiedAt,
        "changedTerminalContentSentToGptAt": changedTerminalContentSentToGptAt,
        "triggerSource": source,
      ])

    Task.detached { [weak self] in
      guard let strongSelf = self else { return }

      await strongSelf.processGPTResponse(
        identifier: identifier,
        terminalStateID: terminalStateID,
        threadId: threadId,
        messageContent:
          "please generate another suggestion of command. Don't provide a duplicated suggestion",
        changeIdentifiedAt: changeIdentifiedAt,
        changedTerminalContentSentToGptAt: changedTerminalContentSentToGptAt,
        source: source
      )

      if strongSelf.shouldGenerateFollowUpSuggestionsFlag {
        DispatchQueue.main.asyncAfter(
          deadline: .now() + strongSelf.additionalSuggestionDelaySeconds
        ) {
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
    print("DEBUG: getOrCreateThreadId called for identifier: \(identifier)")

    if let threadId = threadIdDict[identifier] {
      print("DEBUG: Found existing thread ID for identifier \(identifier): \(threadId)")
      return threadId
    }

    print("DEBUG: No existing thread ID for identifier \(identifier). Creating a new thread ID.")
    do {
      let createdThreadId = try await gptAssistantManager.createThread()
      threadIdDict[identifier] = createdThreadId
      print("DEBUG: Created new thread ID for identifier \(identifier): \(createdThreadId)")
      return createdThreadId
    } catch {
      print("DEBUG: Failed to create thread ID for identifier \(identifier) with error: \(error)")
      throw error
    }
  }

  private func processGPTResponse(
    identifier: String, terminalStateID: UUID, threadId: String, messageContent: String,
    changeIdentifiedAt: Double, changedTerminalContentSentToGptAt: Double, source: String
  ) async {
    Task { @MainActor in
      NotificationCenter.default.post(
        name: .suggestionGenerationStatusChanged, object: nil,
        userInfo: ["identifier": identifier, "isGeneratingSuggestion": true])
    }
    do {
      let response = try await gptAssistantManager.processMessageInThread(
        threadId: threadId, messageContent: messageContent)
      if let command = response["command"] as? String,
        let commandExplanation = response["commandExplanation"] as? String,
        let intention = response["intention"] as? String,
        let shouldGenerateFollowUpSuggestions = response["shouldGenerateFollowUpSuggestions"]
          as? Bool
      {
        if !shouldGenerateFollowUpSuggestions {
          self.showProvideMoreContextBanner()
        } else {
          await appendResult(
            identifier: identifier,
            terminalStateID: terminalStateID,
            response: intention,
            command: command,
            explanation: commandExplanation
          )
        }
        shouldGenerateFollowUpSuggestionsFlag = shouldGenerateFollowUpSuggestions
      }
    } catch {
      print("Error processing message in thread: \(error.localizedDescription)")

      if error.localizedDescription.contains("The network connection was lost")
        || error.localizedDescription.contains("The request timed out")
      {
        DispatchQueue.main.async {
          self.hasInternetConnection = false
          self.isGeneratingSuggestion[identifier] = false
        }
      } else if error.localizedDescription.contains("The Internet connection appears to be offline")
      {
        DispatchQueue.main.async {
          self.shouldShowNetworkIssueWarning = true
          self.hasInternetConnection = false
          self.isGeneratingSuggestion[identifier] = false
        }
      }
    }

    Task { @MainActor in
      NotificationCenter.default.post(
        name: .suggestionGenerationStatusChanged, object: nil,
        userInfo: ["identifier": identifier, "isGeneratingSuggestion": false])

      // Log the event when response is received from GPT
      let responseReceivedFromGptAt = Date().timeIntervalSince1970
      let delayToProcessChange = changedTerminalContentSentToGptAt - changeIdentifiedAt
      let delayToGetResponseFromGpt = responseReceivedFromGptAt - changedTerminalContentSentToGptAt
      let totalDelayToProcessChange = responseReceivedFromGptAt - changeIdentifiedAt

      MixpanelHelper.shared.trackEvent(
        name: "terminalContentAnalysisCompleted",
        properties: [
          "currentTerminalId": identifier,
          "currentTerminalStateID": terminalStateID.uuidString,
          "changeIdentifiedAt": changeIdentifiedAt,
          "changedTerminalContentSentToGptAt": changedTerminalContentSentToGptAt,
          "responseReceivedFromGptAt": responseReceivedFromGptAt,
          "delayToProcessChange": delayToProcessChange,
          "delayToGetResponseFromGpt": delayToGetResponseFromGpt,
          "totalDelayToProcessChange": totalDelayToProcessChange,
          "triggerSource": source,
        ])
    }
  }

  private func incrementGPTSuggestionsFreeTierCount(by count: Int) {
    GPTSuggestionsFreeTierCount += count

    if GPTSuggestionsFreeTierCount >= (GPTSuggestionsFreeTierLimit - 10) {
      MixpanelHelper.shared.trackEvent(name: "freeTierLimitApproaching")
    } else if GPTSuggestionsFreeTierCount >= GPTSuggestionsFreeTierLimit {
      MixpanelHelper.shared.trackEvent(name: "freeTierLimitReached")
    }
  }
  private func updateHasGPTSuggestionsFreeTierCountReachedLimit() {
    hasGPTSuggestionsFreeTierCountReachedLimit =
      GPTSuggestionsFreeTierCount >= GPTSuggestionsFreeTierLimit
  }

  private func updateResults(
    identifier: String,
    terminalStateID: UUID,
    entry: [String: String],
    currentTime: Date
  ) {
    if var windowInfo = self.results[identifier] {
      var batchFound = false
      for (index, batch) in windowInfo.suggestionsHistory.enumerated()
      where batch.0 == terminalStateID {
        windowInfo.suggestionsHistory[index].1.append(entry)
        batchFound = true
        break
      }
      if !batchFound {
        windowInfo.suggestionsHistory.append((terminalStateID, [entry]))
      }
      windowInfo.suggestionsCount += 1
      windowInfo.updatedAt = currentTime
      self.results[identifier] = windowInfo
    } else {
      self.results[identifier] = (
        suggestionsCount: 1, suggestionsHistory: [(terminalStateID, [entry])],
        updatedAt: currentTime
      )
    }
    self.updateCounter += 1
  }

  @MainActor
  private func appendResult(
    identifier: String, terminalStateID: UUID, response: String?, command: String?,
    explanation: String?
  ) {
    guard let response = response, !response.isEmpty,
      let command = command, !command.isEmpty,
      let explanation = explanation, !explanation.isEmpty
    else {
      return
    }

    DispatchQueue.main.async {
      // Check if there is a pending pro-tip for this identifier (only for proTipIdx 2)
      if let pendingProTip = self.pendingProTips[identifier], pendingProTip.proTipIdx == 2 {
        self.appendProTipToResults(
          identifier: identifier,
          proTipEntry: pendingProTip.proTipEntry,
          terminalStateID: pendingProTip.terminalStateID,
          currentTime: pendingProTip.currentTime
        )
        // Remove the pending pro-tip after appending it
        self.pendingProTips.removeValue(forKey: identifier)
      }

      let newEntry = [
        "gptResponse": response, "suggestedCommand": command, "commandExplanation": explanation,
      ]
      let currentTime = Date()

      self.updateResults(
        identifier: identifier,
        terminalStateID: terminalStateID,
        entry: newEntry,
        currentTime: currentTime
      )

      self.writeResultsToFile()
      if self.hasUserValidatedOwnOpenAIAPIKey == .usingFreeTier {
        self.incrementGPTSuggestionsFreeTierCount(by: 1)
      }
    }
  }

  @MainActor
  func appendProTip(identifier: String, proTipIdx: Int) {
    let proTipEntry = ["isProTipBanner": "true", "proTipIdx": String(proTipIdx)]
    let currentTime = Date()
    let terminalStateID = UUID()

    switch proTipIdx {
    case 2:
      handlePendingProTip(
        identifier: identifier,
        proTipIdx: proTipIdx,
        proTipEntry: proTipEntry,
        terminalStateID: terminalStateID,
        currentTime: currentTime
      )

    case 5:
      handleSpecialProTipIdx5(
        identifier: identifier,
        terminalStateID: terminalStateID,
        proTipEntry: proTipEntry,
        currentTime: currentTime
      )

    default:
      appendProTipToResults(
        identifier: identifier,
        proTipEntry: proTipEntry,
        terminalStateID: terminalStateID,
        currentTime: currentTime
      )
    }
  }

  private func handlePendingProTip(
    identifier: String,
    proTipIdx: Int,
    proTipEntry: [String: String],
    terminalStateID: UUID,
    currentTime: Date
  ) {
    pendingProTips[identifier] = (
      proTipIdx: proTipIdx, proTipEntry: proTipEntry, terminalStateID: terminalStateID,
      currentTime: currentTime
    )
  }

  @MainActor
  private func handleSpecialProTipIdx5(
    identifier: String,
    terminalStateID: UUID,
    proTipEntry: [String: String],
    currentTime: Date
  ) {
    let response = "Fix sm command not found"
    let command = "source " + getShellProfile()
    let explanation =
      "Reloads your terminal profile, allowing the 'sm' command to function properly."

    appendProTipToResults(
      identifier: identifier,
      proTipEntry: proTipEntry,
      terminalStateID: terminalStateID,
      currentTime: currentTime
    )

    appendResult(
      identifier: identifier,
      terminalStateID: UUID(),  // Create a new UUID so that the suggestion in in other block instead of with the pro-tip (would be hidden)
      response: response,
      command: command,
      explanation: explanation
    )
  }

  private func appendProTipToResults(
    identifier: String, proTipEntry: [String: String], terminalStateID: UUID, currentTime: Date
  ) {
    DispatchQueue.main.async {
      self.updateResults(
        identifier: identifier,
        terminalStateID: terminalStateID,
        entry: proTipEntry,
        currentTime: currentTime
      )
    }
  }

  private func getSharedTemporaryDirectory() -> URL {
    let sharedTempDirectory = URL(fileURLWithPath: "/tmp/shellMateShared")

    // Ensure the directory exists
    if !FileManager.default.fileExists(atPath: sharedTempDirectory.path) {
      do {
        try FileManager.default.createDirectory(
          at: sharedTempDirectory, withIntermediateDirectories: true, attributes: nil)
      } catch {
        print("Failed to create shared temporary directory: \(error)")
      }
    }

    return sharedTempDirectory
  }

  private func writeResultsToFile() {
    DispatchQueue.global(qos: .background).async {  // Moved file writing to a background thread
      guard let currentTerminalID = self.currentTerminalID,
        let terminalResults = self.results[currentTerminalID]
      else {
        return
      }
      let filePath = getShellMateCommandSuggestionsFilePath()

      var jsonOutput: [String: String] = [:]

      // Use the normal for loop index
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

    guard !OnboardingStateManager.shared.isStepCompleted(step: 1) else {
      return
    }

    if self.results[terminalID]?.suggestionsHistory.isEmpty ?? true {
      appendProTip(identifier: terminalID, proTipIdx: 1)
      MixpanelHelper.shared.trackEvent(name: "onboardingStep1FlowShown")
    }
  }

  func setPauseSuggestionGeneration(for terminalID: String, to pause: Bool) {
    pauseSuggestionGeneration[terminalID] = pause

    if pause {
      currentStateText = "ShellMate paused"
    } else {
      currentStateText = "No changes on Terminal"
    }
  }

  func checkAndInitializePauseFlag(for terminalID: String) {
    if pauseSuggestionGeneration[terminalID] == nil {
      pauseSuggestionGeneration[terminalID] = false
    }
  }

  private func showProvideMoreContextBanner() {
    // Check if the last suggestion is a proTip
    if let terminalID = currentTerminalID,
      let suggestionsHistory = results[terminalID]?.suggestionsHistory,
      let lastSuggestion = suggestionsHistory.last?.1.last,
      let isProTipBanner = lastSuggestion["isProTipBanner"],
      isProTipBanner == "true"
    {
      print("Last suggestion is a proTip. Skipping markAsCompleted.")
      return
    }

    // This is not exactly an onboarding banner, instead a user feedback warning
    OnboardingStateManager.shared.markAsCompleted(step: 6)
  }
}
