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
    @Published var results: [String: [Dictionary<String, String>]] = [:]
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
        let dispatchGroup = DispatchGroup()

        for (identifier, image) in capturedImages {
            guard let image = image else {
                print("No image was captured for window \(identifier)!")
                continue
            }
            
            // Enter dispatch group twice for two async tasks
            dispatchGroup.enter()
            dispatchGroup.enter()
            
            saveImage(image, identifier: identifier)
            
            
            // GPT Vision OCR processing
            gptManager.sendImageToOpenAIVision(image: image, identifier: identifier) { text in
                let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                print("\nOCR Text Output for Window \(identifier): \n----------\n\(trimmedText)\n----------\n")
                
                self.processOCRResultWithChatGPT(for: identifier, text: trimmedText) { intention, command in
                    self.appendResult(identifier: identifier, response: intention, command: command)
                    dispatchGroup.leave()
                }
            }

            // Local OCR processing
            performOCR(on: image) { extractedText in
                DispatchQueue.main.async {
                    self.processOCRResultWithChatGPT(for: identifier, text: extractedText) { intention, command in
                        self.appendResult(identifier: identifier, response: intention, command: command)
                        dispatchGroup.leave()
                    }
                }
            }
            
            
        }

        dispatchGroup.notify(queue: .main) {
            print("All processing complete.")
        }

    }

    func processOCRResultWithChatGPT(for identifier: String, text: String, completion: @escaping (String, String) -> Void) {
        gptManager.sendOCRResultsToChatGPT(ocrResults: [identifier: text], highlight: "") { jsonStr in
            DispatchQueue.main.async {
                self.handleJSONResponse(jsonStr, completion: completion)
            }
        }
    }

    private func handleJSONResponse(_ jsonStr: String, completion: (String, String) -> Void) {
        let cleanedJsonStr = jsonStr.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonData = cleanedJsonStr.data(using: .utf8),
              let dictionary = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let intention = dictionary["intention"] as? String,
              let command = dictionary["command"] as? String else {
            print("Failed to parse JSON or missing keys")
            return
        }
        completion(intention, command)
    }

    func appendResult(identifier: String, response: String, command: String) {
        let newEntry = ["gpt response": response, "suggested command": command]
        if var existingEntries = results[identifier] {
            existingEntries.append(newEntry)
            results[identifier] = existingEntries
        } else {
            results[identifier] = [newEntry]
        }
    }

    func getRecentLogs() -> [Logger.LogEntry] {
        return [Logger.LogEntry(identifier: "dummy", startedAt: Date(), gptResponse: "To implement again", recommendedCommands: [])]
    }

    deinit {
        captureTimer?.invalidate()
    }
}
