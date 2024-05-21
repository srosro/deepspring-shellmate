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
    @Published var chatgptResponses: [String: String] = [:]  // Dictionary to store ChatGPT responses for each window
    @Published var recommendedCommands: [String: [String]] = [:]  // Dictionary to store recommended commands for each window
    private var logger = Logger()  // Instantiate the Logger

    
    init() {
        deleteTmpFiles()
        startCapturing()
    }
    
    func startCapturing() {
        print("\nStarting capture...")
        captureTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.captureAndProcessImages()
        }
    }
    
    func captureAndProcessImages() {
        var tempOcrResults: [String: String] = [:]
        var tempChatgptResponses: [String: String] = [:]
        var tempRecommendedCommands: [String: [String]] = [:]
        print("Capturing and processing images...")
        
        captureAllTerminalWindows { windowImages in
            let dispatchGroup = DispatchGroup()

            for (identifier, image) in windowImages {
                if let image = image {
                    dispatchGroup.enter()
                    saveImage(image, identifier: identifier)
                    self.logger.logCapture(identifier: identifier)  // Log capture
                    performOCR(on: image) { text in
                        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        tempOcrResults[identifier] = trimmedText
                        self.logger.logOCR(identifier: identifier, result: trimmedText)  // Log OCR
                        print("\nOCR Text Output for Window \(identifier): \n----------\n\(trimmedText)\n----------\n")
                        
                        // Send the OCR result to ChatGPT for this identifier
                        self.processOCRResultWithChatGPT(for: identifier, text: trimmedText) { response in
                            tempChatgptResponses[identifier] = response
                            let commands = self.extractCommands(from: response)
                            tempRecommendedCommands[identifier] = commands
                            self.logger.logGPT(identifier: identifier, response: response, commands: commands)  // Log GPT
                            dispatchGroup.leave()
                        }
                    }
                } else {
                    print("No image was captured for window \(identifier)!")
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                self.updateResults(newOcrResults: tempOcrResults, newChatgptResponses: tempChatgptResponses, newRecommendedCommands: tempRecommendedCommands)
            }
        }
    }

    func processOCRResultWithChatGPT(for identifier: String, text: String, completion: @escaping (String) -> Void) {
        sendOCRResultsToChatGPT(ocrResults: [identifier: text], highlight: "") { response in
            DispatchQueue.main.async {
                completion(response)
            }
        }
    }

    func extractCommands(from response: String) -> [String] {
        // Find all lines starting with $ and extract the commands
        var commands: [String] = []
        let lines = response.split(separator: "\n")
        for line in lines {
            if let range = line.range(of: "$") {
                let command = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                commands.append(command)
            }
        }
        return commands
    }

    func updateResults(newOcrResults: [String: String], newChatgptResponses: [String: String], newRecommendedCommands: [String: [String]]) {
        self.ocrResults = newOcrResults
        self.chatgptResponses = newChatgptResponses
        self.recommendedCommands = newRecommendedCommands
        print("Updated OCR Results: \(self.ocrResults)")
        print("Updated ChatGPT Responses: \(self.chatgptResponses)")
        print("Updated Recommended Commands: \(self.recommendedCommands)")
    }

    deinit {
        captureTimer?.invalidate()
    }
}



