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
        if let appDelegate = NSApplication.shared.delegate as? ApplicationDelegate {
            appDelegate.initializeApp()
        }
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
    @Published var apiKey: String {
        didSet {
            // Sanitize the API key by removing spaces
            let sanitizedApiKey = apiKey.replacingOccurrences(of: " ", with: "")
            
            // Check if the sanitized API key is empty
            if sanitizedApiKey.isEmpty {
                // If it is empty, update UserDefaults with an empty string
                UserDefaults.standard.set("", forKey: "apiKey")
                // Update the validation state to unverified
                self.updateValidationState(.unverified)
                self.userValidatedOwnOpenAIAPIKey(isValid: false)
            } else {
                // Otherwise, update UserDefaults with the sanitized API key
                UserDefaults.standard.set(sanitizedApiKey, forKey: "apiKey")
                // Schedule the API key check
                scheduleApiKeyCheck()
            }
            
            print("API Key updated: \(sanitizedApiKey)")
        }
    }
    @Published var apiKeyValidationState: ApiKeyValidationState = .unverified

    private var timer: AnyCancellable?
    private var apiKeyCheckTask: DispatchWorkItem?

    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        self.apiKeyValidationState = ApiKeyValidationState(rawValue: UserDefaults.standard.string(forKey: "apiKeyValidationState") ?? ApiKeyValidationState.unverified.rawValue) ?? .unverified
        if !self.apiKey.isEmpty {
            checkApiKey(self.apiKey)
        }
    }

    deinit {
        timer?.cancel()
        apiKeyCheckTask?.cancel()
    }

    private func scheduleApiKeyCheck() {
        print("Scheduling API Key check")
        apiKeyCheckTask?.cancel() // Cancel any existing task

        let task = DispatchWorkItem { [weak self] in
            self?.checkApiKey(self?.apiKey ?? "")
        }
        apiKeyCheckTask = task

        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: task) // Delay by 2 seconds
    }
    
    private func checkApiKey(_ key: String) {
        print("Checking API Key")

        let assistantCreator = GPTAssistantCreator()
        let assistantBaseName = "ShellMateSuggestCommands"
        let assistantCurrentVersion: String
        do {
            assistantCurrentVersion = try getAppVersionAndBuild()
        } catch {
            print("Error retrieving app version and build: \(error)")
            DispatchQueue.main.async {
                self.updateValidationState(.invalid)
                self.userValidatedOwnOpenAIAPIKey(isValid: false)
            }
            return
        }
        let assistantInstructions = GPTAssistantInstructions.getInstructions()

        Task {
            do {
                let assistantId = try await assistantCreator.getOrUpdateAssistant(
                    assistantBaseName: assistantBaseName,
                    assistantCurrentVersion: assistantCurrentVersion,
                    assistantInstructions: assistantInstructions
                )
                print("Assistant ID: \(assistantId)")

                DispatchQueue.main.async {
                    self.updateValidationState(.valid)
                    if key != getHardcodedOpenAIAPIKey() {
                        self.userValidatedOwnOpenAIAPIKey(isValid: true)
                    }
                }
            } catch {
                print("Error occurred while setting up GPT Assistant: \(error)")
                DispatchQueue.main.async {
                    self.updateValidationState(.invalid)
                    self.userValidatedOwnOpenAIAPIKey(isValid: false)
                }
            }
        }
    }

    private func userValidatedOwnOpenAIAPIKey(isValid: Bool) {
        print("User has validated their own OpenAI API Key. Valid: \(isValid)")
        NotificationCenter.default.post(name: .userValidatedOwnOpenAIAPIKey, object: nil, userInfo: ["isValid": isValid])
    }
    
    private func updateValidationState(_ state: ApiKeyValidationState) {
        self.apiKeyValidationState = state
        UserDefaults.standard.set(state.rawValue, forKey: "apiKeyValidationState")
    }
}
