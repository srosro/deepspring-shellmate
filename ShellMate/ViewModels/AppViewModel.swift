import AXSwift
import Combine
import SwiftUI
import Sentry
import Cocoa

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
  @Published var shouldShowSuggestionsView: [String: Bool] = [:]
  @Published var hasAtLeastOneSuggestion: [String: Bool] = [:]
  @Published var hasUserValidatedOwnOpenAIAPIKey: APIKeyValidationState = .usingFreeTier
  @Published var isAssistantSetupSuccessful: Bool = false
  @Published var areNotificationObserversSetup: Bool = false
  @Published var shouldTroubleShootAPIKey: Bool = false
  @Published var shouldShowSamAltmansFace: Bool = true
  @Published var pendingProTips:
    [String: (
      proTipIdx: Int, proTipEntry: [String: String], terminalStateID: UUID, currentTime: Date
    )] = [:]

  private var pendingTerminalAnalysis:
    (
      identifier: String, changeIdentifiedAt: Double, source: String,
      messageContent: String
    )?
  private var consecutiveFailedInternetChecks: Int = 0
  private var internetConnectionGracePeriodTask: Task<Void, Never>?

  private var currentTerminalStateID: UUID?
  private let additionalSuggestionDelaySeconds: TimeInterval = 3.0
  private let provideMoreContextBannerDelay: TimeInterval = 7
  private let maxSuggestionsPerEvent: Int = 4
  private var shouldGenerateFollowUpSuggestionsFlag: Bool = true
  private var gptAssistantManager: GPTAssistantManager = GPTAssistantManager.shared
  private var firstProTipDebounceWorkItem: DispatchWorkItem?

  // UserDefaults keys
  private let GPTSuggestionsFreeTierCountKey = "GPTSuggestionsFreeTierCount"
  private let hasGPTSuggestionsFreeTierCountReachedLimitKey =
    "hasGPTSuggestionsFreeTierCountReachedLimit"
  private var terminalIDCheckTimer: Timer?
  private var apiKeyValidationDebounceTask: DispatchWorkItem?

  // Limit for free tier suggestions
  @AppStorage("GPTSuggestionsFreeTierLimit") private(set) var GPTSuggestionsFreeTierLimit: Int = 50

  @Published var GPTSuggestionsFreeTierCount: Int {
    didSet {
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

  @AppStorage("totalSuggestionsGenerated") private var totalSuggestionsGenerated: Int = 0 {
    didSet {
      calculateSamAltmansFaceLikelihood()
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
            NetworkErrorViewModel.shared.shouldShowNetworkError = true
          }
        } else {
          print("Internet connection restored during grace period.")
          self.resetInternetConnectionCheckState()
        }
      } catch {
        SentrySDK.capture(error: error)
        print("Error during grace period task: \(error.localizedDescription)")
      }
    }
  }

  private func resetInternetConnectionCheckState() {
    consecutiveFailedInternetChecks = 0
    NetworkErrorViewModel.shared.shouldShowNetworkError = false
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
  private func calculateSamAltmansFaceLikelihood() {
    let n = Double(totalSuggestionsGenerated)
    let adjustedLikelihood = min(100, (1.0 / (1.5 + n / 10)) * 100)
    let randomValue = Double.random(in: 0...100)
    shouldShowSamAltmansFace = randomValue <= adjustedLikelihood

    // DEBUG statement
    print(
      "DEBUG: totalSuggestionsGenerated: \(totalSuggestionsGenerated), Adjusted Likelihood: \(String(format: "%.2f", adjustedLikelihood)), Random Value: \(String(format: "%.2f", randomValue)), Should Show Sam Altman's Face: \(shouldShowSamAltmansFace)"
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
      self, selector: #selector(handleOnboardingStepUpdate(_:)),
      name: .forwardOnboardingStepToAppViewModel, object: nil)
    areNotificationObserversSetup = true
    startCheckingTerminalID()  // Necessary as sometimes the AppViewModel will only setup the observer for handleTerminalWindowIdDidChange after the first setup was run, so the currentTerminalID would be empty, causing errors
  }

  private func shouldGenerateSuggestions(for terminalID: String) -> Bool {
    // Check if ShellMate is visible
    guard ShellMateWindowVisibilityService.shared.isShellMateVisible() else {
      print("ShellMate is not visible. Skipping suggestion generation.")
      return false
    }

    // Check for free tier limits
    if hasGPTSuggestionsFreeTierCountReachedLimit && hasUserValidatedOwnOpenAIAPIKey == .usingFreeTier {
      print("Free tier limit reached. Skipping suggestion generation.")
      return false
    }

    // Check for invalid API key
    if hasUserValidatedOwnOpenAIAPIKey == .invalid {
      print("Invalid API key. Skipping suggestion generation.")
      return false
    }

    // Check if suggestion generation is paused
    if PauseSuggestionManager.shared.isSuggestionGenerationPaused(for: terminalID) {
      print("Suggestion generation is paused for terminal ID: \(terminalID)")
      return false
    }

    // Check for internet connection
    if !hasInternetConnection {
      print("No internet connection. Skipping suggestion generation.")
      return false
    }

    return true
  }

  @objc private func handleTerminalChangeStarted() {
    guard let terminalID = currentTerminalID,
          shouldGenerateSuggestions(for: terminalID) else {
      return
    }
    self.currentStateText = "Detecting changes..."
    self.currentTerminalStateID = UUID()  // Forcing updating stateID here. Otherwise it would only be updated when user finish updating the terminal (and would cause problems for the showProvideMoreContextBanner
  }

  @objc private func handleTerminalChangeEnded() {
    guard let terminalID = currentTerminalID, !PauseSuggestionManager.shared.isSuggestionGenerationPaused(for: terminalID) else {
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

    DispatchQueue.main.async {
      self.currentTerminalID = terminalID
      AFKSessionService.shared.currentTerminalID = terminalID // Update AFKSessionService
    }

    checkAndInitializeShouldShowSuggestionsView(for: terminalID)
    checkAndInitializeAtLeastOneSuggestionFlag(for: terminalID)
    PauseSuggestionManager.shared.checkAndInitializePauseFlag(for: terminalID)
    EmptyStateViewModel.shared.initializeEmptyStateMessage(for: terminalID)
    // Pass the terminal ID to UpdateShellProfileViewModel
    UpdateShellProfileViewModel.shared.updateCurrentTerminalID(terminalID)
    initializeSampleCommandForOnboardingIfNeeded(for: terminalID)
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

    // Clear the pending terminal analysis as the new analysis takes priority
    pendingTerminalAnalysis = nil

    guard shouldGenerateSuggestions(for: String(windowID)) else {
      return
    }

    analyzeTerminalContent(text: text, source: source, changeIdentifiedAt: changeIdentifiedAt)
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
        GPTAssistantThreadIDManager.shared.removeAllThreadIds()
        print("DEBUG: threadIdDict cleared")
      }
    }
  }

  private func analyzeTerminalContent(
    text: String, source: String, changeIdentifiedAt: Double
  ) {
    guard let currentTerminalId = self.currentTerminalID,
          shouldGenerateSuggestions(for: currentTerminalId) else {
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

    // Create the new task
    Task.detached { [weak self] in
      guard let strongSelf = self else {
        print("DEBUG: Self is nil.")
        return
      }
      do {
        print("DEBUG: Calling getOrCreateThreadId for currentTerminalId: \(currentTerminalId)")
        let _ = try await GPTAssistantThreadIDManager.shared.getOrCreateThreadId(
          for: currentTerminalId)
        await strongSelf.processTerminalContentAnalysisWithGPT(
          identifier: currentTerminalId,
          terminalStateID: terminalStateID,
          messageContent: text,
          changeIdentifiedAt: changeIdentifiedAt,
          changedTerminalContentSentToGptAt: changedTerminalContentSentToGptAt,
          source: source
        )

        if let pending = strongSelf.pendingTerminalAnalysis,
          pending.identifier == strongSelf.currentTerminalID
        {
          print("Processing pending terminal analysis for terminal \(pending.identifier)")
          // Process the pending terminal analysis instead of generating a new one
          DispatchQueue.main.asyncAfter(
            deadline: .now() + strongSelf.additionalSuggestionDelaySeconds
          ) {
            strongSelf.analyzeTerminalContent(
              text: pending.messageContent,
              source: pending.source,
              changeIdentifiedAt: pending.changeIdentifiedAt
            )
          }
          strongSelf.pendingTerminalAnalysis = nil  // Clear the pending analysis after processing
        } else if strongSelf.shouldGenerateFollowUpSuggestionsFlag {
          DispatchQueue.main.asyncAfter(
            deadline: .now() + strongSelf.additionalSuggestionDelaySeconds
          ) {
            strongSelf.generateAdditionalSuggestions(
              identifier: currentTerminalId,
              terminalStateID: terminalStateID,
              changeIdentifiedAt: Date().timeIntervalSince1970,
              source: "automaticFollowUpSuggestion"
            )
          }
        }
      } catch {
        SentrySDK.capture(error: error)
        print("DEBUG: Error getting or creating thread ID: \(error.localizedDescription)")

        if error.localizedDescription.contains("The network connection was lost")
          || error.localizedDescription.contains("The request timed out")
        {
          DispatchQueue.main.async {
            strongSelf.hasInternetConnection = false
            SuggestionGenerationMonitor.shared.setIsGeneratingSuggestion(
              for: currentTerminalId, to: false)
          }
        } else if error.localizedDescription.contains(
          "The Internet connection appears to be offline")
        {
          DispatchQueue.main.async {
            NetworkErrorViewModel.shared.shouldShowNetworkError = true
            strongSelf.hasInternetConnection = false
            SuggestionGenerationMonitor.shared.setIsGeneratingSuggestion(
              for: currentTerminalId, to: false)
          }
        }
      }
    }
  }

  private func generateAdditionalSuggestions(
    identifier: String, terminalStateID: UUID, changeIdentifiedAt: Double,
    source: String
  ) {
    guard shouldGenerateSuggestions(for: identifier) else {
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

      await strongSelf.processTerminalContentAnalysisWithGPT(
        identifier: identifier,
        terminalStateID: terminalStateID,
        messageContent:
          "please generate another suggestion of command. Don't provide a duplicated suggestion",
        changeIdentifiedAt: changeIdentifiedAt,
        changedTerminalContentSentToGptAt: changedTerminalContentSentToGptAt,
        source: source
      )

      if let pending = strongSelf.pendingTerminalAnalysis,
        pending.identifier == strongSelf.currentTerminalID
      {
        print("Processing pending terminal analysis for terminal \(pending.identifier)")
        // Process the pending terminal analysis instead of generating a new one
        DispatchQueue.main.asyncAfter(
          deadline: .now() + strongSelf.additionalSuggestionDelaySeconds
        ) {
          strongSelf.analyzeTerminalContent(
            text: pending.messageContent,
            source: pending.source,
            changeIdentifiedAt: pending.changeIdentifiedAt
          )
        }
        strongSelf.pendingTerminalAnalysis = nil  // Clear the pending
      } else if strongSelf.shouldGenerateFollowUpSuggestionsFlag {
        DispatchQueue.main.asyncAfter(
          deadline: .now() + strongSelf.additionalSuggestionDelaySeconds
        ) {
          strongSelf.generateAdditionalSuggestions(
            identifier: identifier,
            terminalStateID: terminalStateID,
            changeIdentifiedAt: Date().timeIntervalSince1970,
            source: "automaticFollowUpSuggestion"
          )
        }
      }
    }
  }

  private func processTerminalContentAnalysisWithGPT(
    identifier: String, terminalStateID: UUID, messageContent: String,
    changeIdentifiedAt: Double, changedTerminalContentSentToGptAt: Double, source: String
  ) async {
    do {
      let response = try await gptAssistantManager.processMessageInThread(
        terminalID: identifier, messageContent: messageContent)

      // Check if the response is empty and return early if it is
      if response.isEmpty {
        // Mark suggestion generation as false since we are skipping processing
        Task { @MainActor in
          SuggestionGenerationMonitor.shared.setIsGeneratingSuggestion(for: identifier, to: false)
        }
        pendingTerminalAnalysis = (
          identifier: identifier,
          changeIdentifiedAt: changeIdentifiedAt, source: source,
          messageContent: messageContent
        )
        return
      }

      if let command = response["command"] as? String,
        let commandExplanation = response["commandExplanation"] as? String,
        let intention = response["intention"] as? String,
        let shouldGenerateFollowUpSuggestions = response["shouldGenerateFollowUpSuggestions"]
          as? Bool
      {
        if !shouldGenerateFollowUpSuggestions {
          self.showProvideMoreContextBanner(terminalStateID: terminalStateID)
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
      SentrySDK.capture(error: error)
      print("Error processing message in thread: \(error.localizedDescription)")

      if error.localizedDescription.contains("The network connection was lost")
        || error.localizedDescription.contains("The request timed out")
      {
        DispatchQueue.main.async {
          self.hasInternetConnection = false
          SuggestionGenerationMonitor.shared.setIsGeneratingSuggestion(for: identifier, to: false)

        }
      } else if error.localizedDescription.contains("The Internet connection appears to be offline")
      {
        DispatchQueue.main.async {
          NetworkErrorViewModel.shared.shouldShowNetworkError = true
          self.hasInternetConnection = false
          SuggestionGenerationMonitor.shared.setIsGeneratingSuggestion(for: identifier, to: false)
        }
      } else {
        // For all other error cases, ensure isGeneratingSuggestion is set to false
        DispatchQueue.main.async {
          SuggestionGenerationMonitor.shared.setIsGeneratingSuggestion(for: identifier, to: false)
        }
      }
    }

    Task { @MainActor in
      SuggestionGenerationMonitor.shared.setIsGeneratingSuggestion(for: identifier, to: false)

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

  private func incrementGPTSuggestionsCount(tier: APIKeyValidationState, by count: Int) {
    // Increment the total suggestions count
    totalSuggestionsGenerated += count

    if tier == .valid {
      MixpanelHelper.shared.trackEvent(
        name: "incrementGPTSuggestionsCount", properties: ["tier": "byo"])
      MixpanelHelper.shared.incrementPeopleProperty(
        name: "gptSuggestionsCount_byo", by: Double(count))
    } else if tier == .usingFreeTier {
      GPTSuggestionsFreeTierCount += count

      MixpanelHelper.shared.trackEvent(
        name: "incrementGPTSuggestionsCount", properties: ["tier": "free"])
      MixpanelHelper.shared.setPeopleProperties(
        properties: ["gptSuggestionsCount_free": GPTSuggestionsFreeTierCount])
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
        if entry["isProTipBanner"] != "true" {
          MixpanelHelper.shared.trackEvent(name: "newSuggestionsGroupCreated")
        }
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

    // Update hasAtLeastOneSuggestion and conditionally trigger updateShouldShowSuggestionsView
    self.updateHasAtLeastOneSuggestion(for: identifier, with: entry)
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
      let currentTime = Date()

      // Check if there is a pending pro-tip for this identifier (only for proTipIdx 2)
      if let pendingProTip = self.pendingProTips[identifier], pendingProTip.proTipIdx == 2 {
        self.updateResults(
          identifier: identifier,
          terminalStateID: pendingProTip.terminalStateID,
          entry: pendingProTip.proTipEntry,
          currentTime: pendingProTip.currentTime
        )

        // Remove the pending pro-tip after appending it
        self.pendingProTips.removeValue(forKey: identifier)
      }

      // Create the new entry
      let newEntry = [
        "gptResponse": response, "suggestedCommand": command, "commandExplanation": explanation,
      ]

      // Use updateResults directly for the new entry
      self.updateResults(
        identifier: identifier,
        terminalStateID: terminalStateID,
        entry: newEntry,
        currentTime: currentTime
      )

      self.writeResultsToFile()
      self.incrementGPTSuggestionsCount(tier: self.hasUserValidatedOwnOpenAIAPIKey, by: 1)
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
    let response = "refresh shell profile - fix command not found: sm"
    let command = UpdateShellProfileViewModel.shared.fixingCommand
    let explanation =
      "Reloads your terminal profile, allowing the 'sm' command to function properly."

    appendResult(
      identifier: identifier,
      terminalStateID: terminalStateID,
      response: response,
      command: command,
      explanation: explanation
    )

    // Ensure this is executed after appendResult
    DispatchQueue.main.async {
      if let indices = self.getCurrentSuggestionIndices(
        identifier: identifier, terminalStateID: terminalStateID)
      {
        let suggestionID = generateSuggestionViewElementID(batchIndex: indices.batchIndex)
        UpdateShellProfileViewModel.shared.fixSmCommandNotFoundSuggestionIndex = suggestionID
        UpdateShellProfileViewModel.shared.updateShouldShowUpdateShellProfile(value: true)
      } else {
        print("Failed to retrieve current suggestion indices")
      }
    }
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
    // For some reason, this code was being executed twice simultaneously, causing the first pro tip banner
    // to be appended twice. To prevent this, we added a debouncing mechanism using DispatchWorkItem,
    // ensuring that if the function is triggered in quick succession, only the last invocation within
    // the 0.3-second window will proceed, thus avoiding duplicate banners.

    guard let terminalID = terminalID else {
      return
    }

    guard !OnboardingStateManager.shared.isStepCompleted(step: 1) else {
      return
    }

    // Cancel any previous work item to debounce
    firstProTipDebounceWorkItem?.cancel()

    // Create and execute the debounced work item
    firstProTipDebounceWorkItem = DispatchWorkItem { [weak self] in
      if let self = self,
        self.results[terminalID]?.suggestionsHistory.isEmpty ?? true
      {
        self.appendProTip(identifier: terminalID, proTipIdx: 1)
        MixpanelHelper.shared.trackEvent(name: "onboardingStep1FlowShown")
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: firstProTipDebounceWorkItem!)
  }

  func setPauseSuggestionGeneration(for terminalID: String, to pause: Bool) {
    PauseSuggestionManager.shared.setPauseSuggestionGeneration(for: terminalID, to: pause)

    if pause {
      currentStateText = "ShellMate paused"
    } else {
      currentStateText = "No changes on Terminal"
    }

    // Reset afkPausedTerminals in AFKSessionService
    AFKSessionService.shared.resetAFKPausedTerminal(for: terminalID)
  }

  func checkAndInitializePauseFlag(for terminalID: String) {
    PauseSuggestionManager.shared.checkAndInitializePauseFlag(for: terminalID)
  }

  func checkAndInitializeAtLeastOneSuggestionFlag(for terminalID: String) {
    if self.hasAtLeastOneSuggestion[terminalID] == nil {
      DispatchQueue.main.async {
        self.hasAtLeastOneSuggestion[terminalID] = false
      }
    }
  }

  func checkAndInitializeShouldShowSuggestionsView(for terminalID: String) {
    // Ensure that shouldShowSuggestionsView is initialized
    if self.shouldShowSuggestionsView[terminalID] == nil {
      // If the onboarding step is not completed, set to true immediately
      if !OnboardingStateManager.shared.isStepCompleted(step: 1) {
        DispatchQueue.main.async {
          self.shouldShowSuggestionsView[terminalID] = true
        }
      } else {
        // Otherwise, initialize it as false
        DispatchQueue.main.async {
          self.shouldShowSuggestionsView[terminalID] = false
        }
      }
    }
  }

  func updateHasAtLeastOneSuggestion(for identifier: String, with entry: [String: String]) {
    // Check if the new entry is not a proTip and update hasAtLeastOneSuggestion flag
    if self.hasAtLeastOneSuggestion[identifier] != true {
      if entry["isProTipBanner"] == nil {
        // Update the flag only if it changes from nil or false to true
        self.hasAtLeastOneSuggestion[identifier] = true

        // Call updateShouldShowSuggestionsView only if hasAtLeastOneSuggestion was changed
        self.updateShouldShowSuggestionsView(for: identifier)
      }
    }
  }

  func updateShouldShowSuggestionsView(for identifier: String) {
    // Ensure that shouldShowSuggestionsView for the terminal ID cannot revert to false
    if self.shouldShowSuggestionsView[identifier] == false
      && self.hasAtLeastOneSuggestion[identifier] == true
    {
      self.shouldShowSuggestionsView[identifier] = true
    }
  }

  private func showProvideMoreContextBanner(terminalStateID: UUID) {
    let numberOfSuggestionsGroupToCheck = 50  // Number of suggestion groups to check for proTipIdx 6
    // Check if the last suggestion is a proTip with index 1, and the last 6 suggestions for proTipIdx 6
    if let terminalID = currentTerminalID,
      let suggestionsHistory = results[terminalID]?.suggestionsHistory
    {
      // Flatten the history to get all suggestions
      let allSuggestions = suggestionsHistory.flatMap { $0.1 }

      // Check if there are enough suggestions
      guard allSuggestions.count >= numberOfSuggestionsGroupToCheck else {
        print("Not enough suggestions to check. Skipping markAsCompleted.")
        return
      }

      // Check only the last suggestion for proTipIdx 1
      if let lastSuggestion = allSuggestions.last,
        let isProTipBanner = lastSuggestion["isProTipBanner"],
        isProTipBanner == "true",
        let proTipIdx = lastSuggestion["proTipIdx"],
        proTipIdx == "1"
      {
        print("Found a proTip with index 1 in the last suggestion. Skipping markAsCompleted.")
        return
      }

      // Check the last 6 suggestions for proTipIdx 6
      let lastSuggestions = allSuggestions.suffix(numberOfSuggestionsGroupToCheck)
      for suggestion in lastSuggestions {
        if let isProTipBanner = suggestion["isProTipBanner"],
          isProTipBanner == "true",
          let proTipIdx = suggestion["proTipIdx"],
          proTipIdx == "6"
        {
          print("Found a proTip with index 6 in the last 6 suggestions. Skipping markAsCompleted.")
          return
        }
      }
    }

    // Wait for 7 seconds before proceeding
    DispatchQueue.main.asyncAfter(deadline: .now() + provideMoreContextBannerDelay) {
      // Compare if the currentTerminalStateID is still the same as received
      if self.currentTerminalStateID == terminalStateID {
        OnboardingStateManager.shared.markAsCompleted(step: 6)
      } else {
        print("Terminal state ID has changed, canceling markAsCompleted.")
      }
    }
  }

  private func getCurrentSuggestionIndices(identifier: String, terminalStateID: UUID) -> (
    batchIndex: Int, index: Int
  )? {
    // First, find the window data associated with the provided identifier
    guard let windowData = results[identifier] else {
      return nil
    }

    // Iterate over the suggestionsHistory to find the batch that matches the terminalStateID
    for (batchIndex, batch) in windowData.suggestionsHistory.enumerated() {
      // Check if this batch matches the terminalStateID we're looking for
      if batch.0 == terminalStateID {
        let suggestionCount = batch.1.count
        if suggestionCount > 0 {
          // Return the batchIndex and the index of the last suggestion in this batch
          return (batchIndex, suggestionCount - 1)
        } else {
          return (batchIndex, 0)  // If there are no suggestions, return the first index (0)
        }
      }
    }
    return nil
  }
}
