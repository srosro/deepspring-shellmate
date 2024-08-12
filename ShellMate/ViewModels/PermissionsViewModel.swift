//
//  PermissionsViewModel.swift
//  ShellMate
//
//  Created by Daniel Delattre on 26/06/24.
//

import Foundation
import Combine
import AppKit

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
                    self.scheduleApiKeyCheck()
                } else {
                    // Otherwise, update UserDefaults with the sanitized API key
                    UserDefaults.standard.set(sanitizedApiKey, forKey: "apiKey")
                    // Schedule the API key check
                    self.scheduleApiKeyCheck()
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
        self.apiKeyValidationState = ApiKeyValidationState(rawValue: UserDefaults.standard.string(forKey: "apiKeyValidationState") ?? ApiKeyValidationState.unverified.rawValue) ?? .unverified
    }

    deinit {
        timer?.cancel()
        apiKeyCheckTask?.cancel()
    }

    private func scheduleApiKeyCheck() {
        print("Scheduling API Key check")
        apiKeyCheckTask?.cancel() // Cancel any existing task

        let task = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            Task {
                let result = await self.checkApiKey(self.apiKey)
                switch result {
                case .success:
                    print("DEBUG: API key check succeeded in scheduled task.")
                case .failure(let error):
                    print("DEBUG: API key check failed in scheduled task with error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.userValidatedOwnOpenAIAPIKey(isValid: false)
                    }
                }
            }
        }
        apiKeyCheckTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: task) // Delay by 2 seconds
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
                }
                else {
                    self.updateValidationState(.unverified) // It is valid, but it was not validated by the user
                    self.userValidatedOwnOpenAIAPIKey(isValid: nil)
                }
            }
            return .success(())
        } catch {
            print("DEBUG: Error occurred while setting up GPT Assistant: \(error)")
            DispatchQueue.main.async {
                self.updateValidationState(.invalid)
                self.apiKeyErrorMessage = error.localizedDescription
                self.userValidatedOwnOpenAIAPIKey(isValid: false)
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
        NotificationCenter.default.post(name: .userValidatedOwnOpenAIAPIKey, object: nil, userInfo: ["isValid": isValid as Any])
    }
    
    private func updateValidationState(_ state: ApiKeyValidationState) {
        print("DEBUG: -- method called to update the value of state to : \(state)")
        self.apiKeyValidationState = state
        UserDefaults.standard.set(state.rawValue, forKey: "apiKeyValidationState")
    }
}
