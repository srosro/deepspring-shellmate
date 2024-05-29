//
//  AppViewModel.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 15/05/24.
//

import Foundation
import AppKit
import Combine
import CoreGraphics

class AppViewModel1: ObservableObject {
    var captureTimer: Timer?
    @Published var results: [String: (suggestionsCount: Int, gptResponses: [Dictionary<String, String>], updatedAt: Date)] = [:]
    private var captureManager = CaptureManager()
    private var gptManager = GPTManager()
    
    
    @Published var isPaused: Bool = false
    @Published var updateCounter: Int = 0  // This counter will be incremented on every update
    @Published var processingStatus: [String: Bool] = [:]  // Track processing status for each window identifier
    private var logger = Logger()
    private let suggestionsLimit: Int = 3  // Universal limit for suggestions across all windows
    private var currentOCRTexts: [String: String] = [:]
    
    init() {
        deleteTmpFiles()
        startCapturing()
    }

    func startCapturing() {
        print("\nStarting capture...")
        captureTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.captureAndProcessImages()
        }
    }

    
    func captureAndProcessImages() {
        guard !isPaused, !ApplicationMonitor.shared.isMinimized else {
            
            print("Capture is paused or terminal is minimized.")
            return
        }

        print("Requesting capture of images...")
        captureManager.captureWindows(processingStatus: processingStatus) { [weak self] capturedImages in
            guard let self = self else { return }
            
            // Collect identifiers of all captured images
            let currentWindowIDs = Set(capturedImages.map { $0.identifier })

            // Update or initialize OCR texts in the dictionary
            capturedImages.forEach { capturedImage in
                if let newImage = capturedImage.image {
                    // Proceed to process images
                    self.processImage(capturedImage.identifier, newImage)
                }
            }

            // Cleanup results before processing images
            self.cleanupResults(currentWindowIDs: currentWindowIDs)
        }
    }

    func processImage(_ identifier: String, _ image: CGImage) {
        if processingStatus[identifier] == true {
            print("Processing for window \(identifier) is already running. Skipping this cycle.")
            return
        }

        // Mark processing as started
        processingStatus[identifier] = true

        let dispatchGroup = DispatchGroup()
        
        // Check if the current amount of suggestions for this identifier has reached the limit
        if let windowData = results[identifier], windowData.suggestionsCount >= suggestionsLimit {
            print("Suggestions limit reached for window \(identifier). Skipping processing.")
            processingStatus[identifier] = false  // Mark processing as finished
            return
        }

        // Measure start time
        let startTime = Date()
        
        // Enter dispatch group for async tasks
        dispatchGroup.enter()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            performOCR(on: image) { extractedText in
                DispatchQueue.main.async {
                    //let trimmedText = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
                    //print("\nOCR Text Output for Window \(identifier): \n----------\n\(trimmedText)\n----------\n")
                    //self.compareAndProcessOCRResult(for: identifier, newText: trimmedText)
                    // Measure end time and calculate duration
                    let endTime = Date()
                    let duration = endTime.timeIntervalSince(startTime)
                    print(String(format: "Levenshtein processing for window \(identifier) took %.2f seconds.", duration))
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            print("All processing complete for window \(identifier).")
            self.processingStatus[identifier] = false  // Mark processing as finished
        }
    }
    
    private func cleanupResults(currentWindowIDs: Set<String>) {
        for key in results.keys {
            if !currentWindowIDs.contains(key) {
                print("Removing results and OCR texts for window \(key) as it's no longer active.")
                results.removeValue(forKey: key)
                currentOCRTexts.removeValue(forKey: key)
            }
        }
        updateCounter += 1  // Update to trigger any observers of results changes
    }

    func saveOCRResult(_ text: String, for identifier: String) {
        let tmpDir = FileManager.default.temporaryDirectory
        let timestamp = Date().timeIntervalSince1970
        let filePath = tmpDir.appendingPathComponent("\(identifier)_\(timestamp).txt")

        do {
            try text.write(to: filePath, atomically: true, encoding: .utf8)
            print("Saved OCR result for \(identifier) to \(filePath.path)")
        } catch {
            print("Failed to save OCR result for \(identifier): \(error)")
        }
    }
    
    func appendResult(identifier: String, response: String, command: String) {
        var windowData = results[identifier] ?? (suggestionsCount: 0, gptResponses: [], updatedAt: Date())
        windowData.suggestionsCount += 1
        windowData.gptResponses.append(["response": response, "command": command])
        windowData.updatedAt = Date()
        results[identifier] = windowData
    }

    func deleteTmpFiles() {
        let tmpDir = FileManager.default.temporaryDirectory
        do {
            let tmpFiles = try FileManager.default.contentsOfDirectory(atPath: tmpDir.path)
            for file in tmpFiles {
                try FileManager.default.removeItem(at: tmpDir.appendingPathComponent(file))
            }
            print("Temporary files deleted.")
        } catch {
            print("Failed to delete temporary files: \(error)")
        }
    }
    
    
    func compareAndProcessOCRResult(for identifier: String, newText: String) {
        let startTime = Date()  // Start time

        func alphanumericString(from text: String) -> String {
            // Replace all non-alphanumeric characters with an empty string
            let pattern = "[^a-zA-Z0-9]+"
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)
            let alphanumericText = regex?.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "") ?? ""
            return alphanumericText
        }

        let newAlphanumericText = alphanumericString(from: newText)
        
        if let previousText = currentOCRTexts[identifier] {
            let previousAlphanumericText = alphanumericString(from: previousText)
            
            let previousLength = previousAlphanumericText.count
            let newLength = newAlphanumericText.count
            
            let lengthDifference = abs(previousLength - newLength)
            let threshold = 10  // Set your threshold here

            // Print the calculated length difference
            print("Length difference for img1 vs img2 \(identifier) is: \(lengthDifference)")

            if lengthDifference <= threshold {
                print("OCR text for identifier \(identifier) has not changed.")
            } else {
                print("OCR text for identifier \(identifier) has changed.")
                // Update the OCR text in the dictionary as it has changed
                currentOCRTexts[identifier] = newText
                // Delete the current window identifier from the results dict as the OCR text has changed
                results.removeValue(forKey: identifier)
                print("Removed results for identifier \(identifier) due to OCR text change.")
                self.saveOCRResult(previousAlphanumericText, for: "img1")
                self.saveOCRResult(newAlphanumericText, for: "img2")
            }
        } else {
            // No existing OCR text, so initialize
            print("Initializing OCR text for identifier \(identifier).")
            currentOCRTexts[identifier] = newText
        }

        let endTime = Date()  // End time
        let timeInterval = endTime.timeIntervalSince(startTime)  // Calculate the duration
        print("Time taken for compare and process OCR result: \(timeInterval) seconds")
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

    func getRecentLogs() -> [Logger.LogEntry] {
        return [Logger.LogEntry(identifier: "dummy", startedAt: Date(), gptResponse: "To implement again", recommendedCommands: [])]
    }

    deinit {
        captureTimer?.invalidate()
    }
}

class AppViewModel: ObservableObject {
    @Published var results: [String: (suggestionsCount: Int, gptResponses: [Dictionary<String, String>], updatedAt: Date)] = [:]

}



extension AppViewModel {
    
    var sortedResults: [String] {
        results.keys.sorted {
            results[$0]!.updatedAt < results[$1]!.updatedAt
        }
    }
}
