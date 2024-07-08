//
//  PermissionsViewModel.swift
//  ShellMate
//
//  Created by Daniel Delattre on 26/06/24.
//

import Foundation
import Combine
import AppKit

enum ApiKeyValidationState: String {
    case unverified
    case valid
    case invalid
}

class PermissionsViewModel: ObservableObject {
    @Published var isAppTrusted = false
    @Published var apiKey: String {
        didSet {
            let sanitizedApiKey = apiKey.replacingOccurrences(of: " ", with: "")
            print("API Key updated: \(sanitizedApiKey)")
            UserDefaults.standard.set(sanitizedApiKey, forKey: "apiKey")
            scheduleApiKeyCheck()
        }
    }
    @Published var apiKeyValidationState: ApiKeyValidationState = .unverified

    private var timer: AnyCancellable?
    private var apiKeyCheckTask: DispatchWorkItem?

    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        self.apiKeyValidationState = ApiKeyValidationState(rawValue: UserDefaults.standard.string(forKey: "apiKeyValidationState") ?? ApiKeyValidationState.unverified.rawValue) ?? .unverified
        if !self.apiKey.isEmpty && self.apiKeyValidationState == .unverified {
            checkApiKey(self.apiKey)
        }
        checkAccessibilityPermissions()
        startTimer()
    }

    deinit {
        timer?.cancel()
        apiKeyCheckTask?.cancel()
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
        print("Checking API Key: \(key)")

        // Create the URL for the request
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            print("Invalid URL")
            updateValidationState(.invalid)
            return
        }

        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        // Perform the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error making request: \(error)")
                DispatchQueue.main.async {
                    self.updateValidationState(.invalid)
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response")
                DispatchQueue.main.async {
                    self.updateValidationState(.invalid)
                }
                return
            }

            if httpResponse.statusCode == 200 {
                print("API key is valid")
                DispatchQueue.main.async {
                    self.updateValidationState(.valid)
                }
            } else {
                print("API key is invalid")
                DispatchQueue.main.async {
                    self.updateValidationState(.invalid)
                }
            }
        }
        task.resume()
    }
    
    private func updateValidationState(_ state: ApiKeyValidationState) {
        self.apiKeyValidationState = state
        UserDefaults.standard.set(state.rawValue, forKey: "apiKeyValidationState")
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
