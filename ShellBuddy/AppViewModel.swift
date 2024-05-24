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
    @Published var lastRecognizedText: String?
    @Published var ocrResults: [String: String] = [:]
    @Published var chatgptResponses: [String: String] = [:]
    @Published var recommendedCommands: [String: [String]] = [:]
    @Published var isPaused: Bool = false
    private var captureManager = CaptureManager()
    private var gptManager = GPTManager()
    private var logger = Logger()

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

        print("Requesting capture of images...")
        captureManager.captureWindows { [weak self] capturedImages in
            self?.processImages(capturedImages)
        }
    }
    
    func processImages(_ capturedImages: [(identifier: String, image: CGImage?)]) {
        var tempOcrResults: [String: String] = [:]
        var tempChatgptResponses: [String: String] = [:]
        var tempRecommendedCommands: [String: [String]] = [:]

        let dispatchGroup = DispatchGroup()

        for (identifier, image) in capturedImages {
            guard let image = image else {
                print("No image was captured for window \(identifier)!")
                continue
            }
            dispatchGroup.enter()
            
            saveImage(image, identifier: identifier)
            gptManager.sendImageToOpenAIVision(image: image, identifier: identifier) { text in
                let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                print("\nOCR Text Output for Window \(identifier): \n----------\n\(trimmedText)\n----------\n")
                
                self.processOCRResultWithChatGPT(for: identifier, text: trimmedText) { intention, command in
                    tempOcrResults[identifier] = trimmedText
                    tempChatgptResponses[identifier] = intention
                    tempRecommendedCommands[identifier] = [command]
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            // Atomically update all results at once
            self?.updateResults(newOcrResults: tempOcrResults, newChatgptResponses: tempChatgptResponses, newRecommendedCommands: tempRecommendedCommands)
        }
    }

    func processOCRResultWithChatGPT(for identifier: String, text: String, completion: @escaping (String, String) -> Void) {
        gptManager.sendOCRResultsToChatGPT(ocrResults: [identifier: text], highlight: "") { jsonStr in
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
        return [Logger.LogEntry(identifier: "dummy", startedAt: Date(), gptResponse: "To implement again", recommendedCommands: [])]
        //return logger.getRecentLogs()
    }
    
    deinit {
        captureTimer?.invalidate()
    }
}
