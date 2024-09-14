//
//  PermissionsViewModel.swift
//  ShellMate
//
//  Created by Daniel Delattre on 26/06/24.
//

import AppKit
import Combine
import Foundation

class PermissionsViewModel: ObservableObject {
  @Published var isAppTrusted = false

  private var timer: AnyCancellable?

  init() {
    checkAccessibilityPermissions()
    startTimer()
  }

  deinit {
    timer?.cancel()
  }

  func checkAccessibilityPermissions() {
    isAppTrusted = AccessibilityChecker.isAppTrusted()
  }

  private func startTimer() {
    timer = Timer.publish(every: 1.0, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        self?.checkAccessibilityPermissions()
      }
  }

  func initializeApp() {
    NotificationCenter.default.post(name: .startAppInitialization, object: nil)
  }

  func requestAccessibilityPermissions() {
    let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
    AXIsProcessTrustedWithOptions(options)
  }
}

enum ApiKeyValidationState: String {
  case unverified
  case valid
  case invalid
}

class LicenseViewModel: ObservableObject {
  static let shared = LicenseViewModel()

  @Published var apiKeyErrorMessage: String?
  @Published var apiKey: String = "" {
    didSet {
      // Cancel any ongoing validation
      apiKeyCheckTask?.cancel()

      sanitizeApiKey(apiKey)

      // Debounce the API key validation
      let debouncedTask = DispatchWorkItem { [weak self] in
        guard let self = self else { return }

        // Sanitize the API key by removing spaces and newlines
        let sanitizedApiKey = self.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if the sanitized API key is empty
        if sanitizedApiKey.isEmpty {
          // If it is empty, update UserDefaults with an empty string
          print("DEBUG: sanitized empty key trigger")
          UserDefaults.standard.set("", forKey: "apiKey")
          self.scheduleApiKeyCheck(after: 2, completion: { _ in })
        } else {
          // Otherwise, update UserDefaults with the sanitized API key
          UserDefaults.standard.set(sanitizedApiKey, forKey: "apiKey")
          // Schedule the API key check
          self.scheduleApiKeyCheck(after: 2, completion: { _ in })
        }

        print("API Key updated: \(sanitizedApiKey)")
      }

      // Execute the task after a delay to debounce
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: debouncedTask)
      apiKeyCheckTask = debouncedTask
    }
  }

  @Published var apiKeyValidationState: ApiKeyValidationState = .unverified {
    didSet {
      print("DEBUG: the current state is: \(apiKeyValidationState)")
    }
  }

  private var timer: AnyCancellable?
  private var apiKeyCheckTask: DispatchWorkItem?

  private init() {
    self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
    self.apiKeyValidationState =
      ApiKeyValidationState(
        rawValue: UserDefaults.standard.string(forKey: "apiKeyValidationState")
          ?? ApiKeyValidationState.unverified.rawValue) ?? .unverified
  }

  deinit {
    timer?.cancel()
    apiKeyCheckTask?.cancel()
  }

  // Add a property to track the async task for cancellation
  private var currentApiKeyCheckTask: Task<Void, Never>? = nil

  func scheduleApiKeyCheck(
    after delay: TimeInterval, maxRetries: Int = 3, completion: @escaping (Bool) -> Void
  ) {
    // Cancel any existing task (this will cancel the entire retry process if it's ongoing)
    apiKeyCheckTask?.cancel()
    currentApiKeyCheckTask?.cancel()  // Cancel the current async task if it's running

    // Define a new DispatchWorkItem that encapsulates the logic
    let task = DispatchWorkItem { [weak self] in
      guard let self = self else { return }

      // Create a Task to handle the async call within DispatchWorkItem
      self.currentApiKeyCheckTask = Task {
        // Call the asynchronous function to check the API key
        await self.executeApiKeyCheckWithRetry(maxRetries: maxRetries, completion: completion)
      }
    }

    // Assign the new DispatchWorkItem to apiKeyCheckTask so that it can be cancelled later if needed
    apiKeyCheckTask = task

    // Schedule the task with the initial delay
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
  }

  private func executeApiKeyCheckWithRetry(maxRetries: Int, completion: @escaping (Bool) -> Void)
    async
  {
    var retriesLeft = maxRetries

    // Loop to retry the API key check
    while retriesLeft > 0 {
      // Check if the task has been cancelled
      if Task.isCancelled {
        print("API Validation Task was cancelled.")
        return
      }

      let result = await checkApiKey(self.apiKey)  // Asynchronously call the API check

      switch result {
      case .success:
        MixpanelHelper.shared.trackEvent(name: "openAIAPIKeyValidationSuccess")
        completion(true)  // Return true for success
        return  // Exit the function, no need to retry anymore

      case .failure(let error):
        MixpanelHelper.shared.trackEvent(
          name: "openAIAPIKeyValidationFailure", properties: ["error": error.localizedDescription]
        )

        retriesLeft -= 1

        if retriesLeft > 0 {
          // Sleep for 10 seconds before retrying (non-blocking)
          try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
        } else {
          DispatchQueue.main.async {
            self.userValidatedOwnOpenAIAPIKey(isValid: false)
          }
          completion(false)  // Return false after exhausting retries
        }
      }
    }
  }

  func checkApiKey(_ key: String) async -> Result<Void, Error> {
    print("DEBUG: Starting API Key check")

    let assistantCreator = GPTAssistantCreator()
    let assistantBaseName = "ShellMateSuggestCommands"
    let assistantCurrentVersion: String

    do {
      assistantCurrentVersion = try getAppVersionAndBuild()
      print("DEBUG: Retrieved app version and build: \(assistantCurrentVersion)")
    } catch {
      print("DEBUG: Error retrieving app version and build: \(error)")
      DispatchQueue.main.async {
        self.updateValidationState(.invalid)
        self.apiKeyErrorMessage = error.localizedDescription
        self.userValidatedOwnOpenAIAPIKey(isValid: false)
      }
      return .failure(error)
    }

    let assistantInstructions = GPTAssistantInstructions.getInstructions()

    do {
      let assistantId = try await assistantCreator.getOrUpdateAssistant(
        assistantBaseName: assistantBaseName,
        assistantCurrentVersion: assistantCurrentVersion,
        assistantInstructions: assistantInstructions
      )
      print("DEBUG: Assistant ID: \(assistantId)")

      DispatchQueue.main.async {
        self.apiKeyErrorMessage = nil
        if !key.isEmpty && key != getHardcodedOpenAIAPIKey() {
          self.userValidatedOwnOpenAIAPIKey(isValid: true)
          self.updateValidationState(.valid)
          MixpanelHelper.shared.trackEvent(name: "userValidatedOwnOpenAIAPIKey")
        } else {
          self.updateValidationState(.unverified)  // It is valid, but it was not validated by the user
          self.userValidatedOwnOpenAIAPIKey(isValid: nil)
        }
      }
      return .success(())
    } catch {
      print("DEBUG: Error occurred while setting up GPT Assistant: \(error)")
      DispatchQueue.main.async {
        self.updateValidationState(.invalid)
        self.apiKeyErrorMessage = error.localizedDescription

        if let nsError = error as NSError?,
          let httpStatusCode = nsError.userInfo["HTTPStatusCode"] as? Int, httpStatusCode == 401
        {
          self.userValidatedOwnOpenAIAPIKey(isValid: false)
        }
      }
      return .failure(error)
    }
  }

  private func userValidatedOwnOpenAIAPIKey(isValid: Bool?) {
    if let isValid = isValid {
      print("User has validated their own OpenAI API Key. Valid: \(isValid)")
    } else {
      print("User has validated their own OpenAI API Key. Valid: nil")
    }
    NotificationCenter.default.post(
      name: .userValidatedOwnOpenAIAPIKey, object: nil, userInfo: ["isValid": isValid as Any])
  }

  private func updateValidationState(_ state: ApiKeyValidationState) {
    print("DEBUG: -- method called to update the value of state to : \(state)")
    self.apiKeyValidationState = state
    UserDefaults.standard.set(state.rawValue, forKey: "apiKeyValidationState")
  }

  func sanitizeApiKey(_ text: String) {
    let sanitized = text.replacingOccurrences(
      of: "[\\s\\r\\n]+", with: "", options: .regularExpression)
    // Only update apiKey if sanitized is different to prevent infinite loop
    if sanitized != apiKey {
      DispatchQueue.main.async {
        self.apiKey = sanitized
      }
    }
  }
}
