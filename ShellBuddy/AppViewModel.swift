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

class AppViewModel: ObservableObject {
    var captureTimer: Timer?
    @Published var results: [String: (suggestionsCount: Int, gptResponses: [Dictionary<String, String>], updatedAt: Date)] = [:]
    @Published var isPaused: Bool = false
    @Published var updateCounter: Int = 0  // This counter will be incremented on every update

    private var captureManager = CaptureManager()
    private var gptManager = GPTManager()
    private var logger = Logger()
    private let suggestionsLimit: Int = 3  // Universal limit for suggestions across all windows
    private var currentImages: [String: CGImage] = [:]

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

    func areImagesIdentical(_ image1: CGImage, _ image2: CGImage) -> Bool {
        // Check basic image properties
        guard image1.width == image2.width && image1.height == image2.height else {
            return false
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // Set up the bitmap context for image 1
        guard let context1 = CGContext(data: nil,
                                       width: image1.width,
                                       height: image1.height,
                                       bitsPerComponent: image1.bitsPerComponent,
                                       bytesPerRow: image1.bytesPerRow,
                                       space: colorSpace,
                                       bitmapInfo: image1.bitmapInfo.rawValue),
              let context2 = CGContext(data: nil,
                                       width: image2.width,
                                       height: image2.height,
                                       bitsPerComponent: image2.bitsPerComponent,
                                       bytesPerRow: image2.bytesPerRow,
                                       space: colorSpace,
                                       bitmapInfo: image2.bitmapInfo.rawValue) else {
            return false
        }

        // Draw images onto their respective contexts
        context1.draw(image1, in: CGRect(x: 0, y: 0, width: image1.width, height: image1.height))
        context2.draw(image2, in: CGRect(x: 0, y: 0, width: image2.width, height: image2.height))

        // Compare pixel data
        guard let data1 = context1.data, let data2 = context2.data else {
            return false
        }
        
        let size = image1.height * image1.bytesPerRow
        return memcmp(data1, data2, size) == 0
    }

    
    func captureAndProcessImages() {
        guard !isPaused, !ApplicationMonitor.shared.isMinimized else {
            
            print("Capture is paused or terminal is minimized.")
            return
        }

        print("Requesting capture of images...")
        captureManager.captureWindows { [weak self] capturedImages in
            guard let self = self else { return }
            
            // Collect identifiers of all captured images
            let currentWindowIDs = Set(capturedImages.map { $0.identifier })

            // Update or initialize images in the dictionary
            capturedImages.forEach { capturedImage in
                if let newImage = capturedImage.image {
                    if let existingImage = self.currentImages[capturedImage.identifier] {
                        // Compare the new image with the existing one
                        if self.areImagesIdentical(existingImage, newImage) {
                            print("Image for identifier \(capturedImage.identifier) has not changed.")
                        } else {
                            print("Image for identifier \(capturedImage.identifier) has changed.")
                            // Update the image in the dictionary as it has changed
                            self.currentImages[capturedImage.identifier] = newImage
                            // Delete the current window identifier from the results dict as the image has changed
                            self.results.removeValue(forKey: capturedImage.identifier)
                            print("Removed results for identifier \(capturedImage.identifier) due to image change.")
                        }
                    } else {
                        // No existing image, so initialize
                        print("Initializing image for identifier \(capturedImage.identifier).")
                        self.currentImages[capturedImage.identifier] = newImage
                    }
                }
            }

            // Cleanup results before processing images
            self.cleanupResults(currentWindowIDs: currentWindowIDs)

            // Proceed to process images
            self.processImages(capturedImages)
        }
    }


    
    private func cleanupResults(currentWindowIDs: Set<String>) {
        for key in results.keys {
            if !currentWindowIDs.contains(key) {
                print("Removing results and images for window \(key) as it's no longer active.")
                results.removeValue(forKey: key)
                currentImages.removeValue(forKey: key)
            }
        }
        updateCounter += 1  // Update to trigger any observers of results changes
    }


    func processImages(_ capturedImages: [(identifier: String, image: CGImage?)]) {
        let dispatchGroup = DispatchGroup()
        
        for (identifier, image) in capturedImages {
            guard let image = image else {
                print("No image was captured for window \(identifier)!")
                continue
            }
            
            // Check if the current amount of suggestions for this identifier has reached the limit
            if let windowData = results[identifier], windowData.suggestionsCount >= suggestionsLimit {
                print("Suggestions limit reached for window \(identifier). Skipping processing.")
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
        let newEntry = ["gptResponse": response, "suggestedCommand": command]
        let currentTime = Date() // Get the current time

        if var windowInfo = results[identifier] {
            // Append new response to the existing array of responses
            windowInfo.gptResponses.append(newEntry)
            // Increment the suggestions count
            windowInfo.suggestionsCount += 1
            // Update the timestamp
            windowInfo.updatedAt = currentTime
            results[identifier] = windowInfo
        } else {
            // Initialize if this is the first entry for this identifier
            results[identifier] = (suggestionsCount: 1, gptResponses: [newEntry], updatedAt: currentTime)
        }
        updateCounter += 1  // Increment the counter to notify a change
    }

    func getRecentLogs() -> [Logger.LogEntry] {
        return [Logger.LogEntry(identifier: "dummy", startedAt: Date(), gptResponse: "To implement again", recommendedCommands: [])]
    }

    deinit {
        captureTimer?.invalidate()
    }
}


extension AppViewModel {
    var sortedResults: [String] {
        results.keys.sorted {
            results[$0]!.updatedAt < results[$1]!.updatedAt
        }
    }
}
