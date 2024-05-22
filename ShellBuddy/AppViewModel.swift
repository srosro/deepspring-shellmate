//
//  AppViewModel.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 15/05/24.
//

import SwiftUI
import Combine

class AppViewModel: ObservableObject {
    var captureTimer: Timer?
    @Published var lastRecognizedText: String?  // This will store the last OCR result
    @Published var ocrResults: [String: String] = [:]  // Dictionary to store OCR results for each window
    @Published var chatgptResponses: [String: String] = [:]  // Dictionary to store ChatGPT intentions for each window
    @Published var recommendedCommands: [String: [String]] = [:]  // Dictionary to store recommended commands for each window
    @Published var isPaused: Bool = false  // Indicates if the execution is paused
    private var logger = Logger()  // Instantiate the Logger

    init() {
        deleteTmpFiles()
        startCapturing()
    }
    
    func startCapturing() {
        print("\nStarting capture...")
        captureTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.captureAndProcessImages()
        }
    }
    
    func captureAndProcessImages() {
        guard !isPaused else {
            print("Capture is paused.")
            return
        }

        var tempOcrResults: [String: String] = [:]
        var tempChatgptResponses: [String: String] = [:]
        var tempRecommendedCommands: [String: [String]] = [:]
        print("Capturing and processing images...")

        captureAllTerminalWindows { windowImages in
            let dispatchGroup = DispatchGroup()

            for (windowIdentifier, image) in windowImages {
                if let image = image {
                    dispatchGroup.enter()
                    let uniqueIdentifier = "\(windowIdentifier)_\(UUID().uuidString)"  // Generate unique identifier with window identifier and UUID
                    saveImage(image, identifier: uniqueIdentifier)
                    self.logger.logCapture(identifier: uniqueIdentifier)  // Log capture
                    performOCR(on: image) { text in
                        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        tempOcrResults[uniqueIdentifier] = trimmedText
                        self.logger.logOCR(identifier: uniqueIdentifier, result: trimmedText)  // Log OCR
                        print("\nOCR Text Output for Window \(uniqueIdentifier): \n----------\n\(trimmedText)\n----------\n")

                        // Send the OCR result to ChatGPT for this identifier
                        self.processOCRResultWithChatGPT(for: uniqueIdentifier, text: trimmedText) { intention, command in
                            tempChatgptResponses[uniqueIdentifier] = intention
                            tempRecommendedCommands[uniqueIdentifier] = [command]
                            self.logger.logGPT(identifier: uniqueIdentifier, response: intention, commands: [command])  // Log GPT
                            dispatchGroup.leave()
                        }
                    }
                } else {
                    print("No image was captured for window \(windowIdentifier)!")
                }
            }

            dispatchGroup.notify(queue: .main) {
                self.updateResults(newOcrResults: tempOcrResults, newChatgptResponses: tempChatgptResponses, newRecommendedCommands: tempRecommendedCommands)
            }
        }
    }

    func processOCRResultWithChatGPT(for identifier: String, text: String, completion: @escaping (String, String) -> Void) {
        sendOCRResultsToChatGPT(ocrResults: [identifier: text], highlight: "") { jsonStr in
            DispatchQueue.main.async {
                // First, remove the triple backticks if they exist
                let cleanedJsonStr = jsonStr.replacingOccurrences(of: "```json", with: "")
                                      .replacingOccurrences(of: "```", with: "")
                                      .trimmingCharacters(in: .whitespacesAndNewlines)

                // Convert string to data
                guard let jsonData = cleanedJsonStr.data(using: .utf8) else {
                    print("Failed to convert string to data")
                    return
                }

                // Parse JSON data
                do {
                    if let dictionary = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
                       let intention = dictionary["intention"] as? String,
                       let command = dictionary["command"] as? String {
                        completion(intention, command)
                    } else {
                        print("Failed to parse JSON as dictionary or missing expected keys")
                    }
                } catch {
                    print("JSON parsing error: \(error)")
                    print("Received string: \(cleanedJsonStr)")
                }
            }
        }
    }


    func updateResults(newOcrResults: [String: String], newChatgptResponses: [String: String], newRecommendedCommands: [String: [String]]) {
        self.ocrResults = newOcrResults
        self.chatgptResponses = newChatgptResponses
        self.recommendedCommands = newRecommendedCommands
        print("Updated OCR Results: \(self.ocrResults)")
        print("Updated ChatGPT Responses: \(self.chatgptResponses)")
        print("Updated Recommended Commands: \(self.recommendedCommands)")
    }

    func getRecentLogs() -> [Logger.LogEntry] {
        return logger.getRecentLogs()
    }
    
    deinit {
        captureTimer?.invalidate()
    }
}
