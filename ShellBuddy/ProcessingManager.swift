//
//  ProcessingManager.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 03/06/24.
//

import Foundation
import AppKit
import Vision
import ScreenCaptureKit
import os

class ProcessingManager {
    private let viewModel: AppViewModel
    private let processingQueue = DispatchQueue(label: "com.example.appviewmodel.processingqueue")
    private var processingStatus: [String: Bool] = [:]
    private var currentOCRTexts: [String: String] = [:]  // Store previous OCR texts by window identifier
    private var stateChange: [String: Bool] = [:]  // Store the change state of each window
    private var stateChangeTimestamps: [String: Date] = [:]  // Store the timestamps of state changes
    private var stateChangeEventID: [String: UUID] = [:]  // Store the event IDs of state changes
    private var globalHasChanged: [String: Bool] = [:]  // Store the global state of each window
    private var capturedImages: [String: CGImage] = [:]  // Store the captured images by window identifier
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "App", category: "ProcessingManager")
    private var processingTimer: Timer?
    private let ocrProcessingHandler: OCRProcessingHandler

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        self.ocrProcessingHandler = OCRProcessingHandler(viewModel: viewModel)
        deleteTmpFiles()
        startProcessing()
    }

    private func startProcessing() {
        processingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.processCurrentWindow()
        }
    }

    private func processCurrentWindow() {
        guard let windowID = viewModel.currentTerminalID else { return }

        if processingStatus[windowID] == true {
            logger.log("Window \(windowID) is already being processed.")
            return
        }

        processingStatus[windowID] = true

        findWindow(by: windowID) { [weak self] window in
            guard let self = self, let window = window else {
                self?.processingStatus[windowID] = false
                return
            }
            self.captureImage(for: window) { image in
                guard let image = image else {
                    self.processingStatus[windowID] = false
                    return
                }
                self.capturedImages[windowID] = image  // Store the captured image
                self.runOCR(on: image) { extractedText in
                    self.compareAndProcessOCRResult(for: windowID, newText: extractedText)
                    self.processingStatus[windowID] = false
                }
            }
        }
    }

    private func findWindow(by id: String, completion: @escaping (SCWindow?) -> Void) {
        SCShareableContent.getWithCompletionHandler { content, error in
            guard let content = content, error == nil else {
                self.logger.error("Failed to discover shareable content: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }

            let window = content.windows.first { "\($0.windowID)" == id }
            completion(window)
        }
    }

    private func captureImage(for window: SCWindow, completion: @escaping (CGImage?) -> Void) {
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.showsCursor = false

        let filter = SCContentFilter(desktopIndependentWindow: window)
        SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) { image, error in
            if let error = error {
                self.logger.error("Failed to capture screenshot for window \(window.windowID): \(error.localizedDescription)")
                completion(nil)
            } else {
                self.logger.log("Screenshot captured successfully for window \(window.windowID).")
                completion(image)
            }
        }
    }

    private func runOCR(on image: CGImage, completion: @escaping (String) -> Void) {
        let startTime = Date()

        let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil else {
                self.logger.error("Failed to perform OCR: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            if let observations = request.results as? [VNRecognizedTextObservation] {
                var extractedText = ""
                for observation in observations {
                    if let topCandidate = observation.topCandidates(1).first {
                        extractedText += topCandidate.string + "\n"
                    }
                }
                let endTime = Date()
                let timeInterval = endTime.timeIntervalSince(startTime)
                self.logger.log("Time taken for OCR: \(timeInterval) seconds")
                completion(extractedText)
            }
        }
        request.recognitionLevel = .accurate
        try? requestHandler.perform([request])
    }

    private func saveOCRResult(_ text: String, for identifier: String) {
        let tmpDir = FileManager.default.temporaryDirectory
        let timestamp = Date().timeIntervalSince1970
        let filePath = tmpDir.appendingPathComponent("\(identifier)_\(timestamp).txt")

        do {
            try text.write(to: filePath, atomically: true, encoding: .utf8)
            logger.log("Saved OCR result for \(identifier) to \(filePath.path)")
        } catch {
            logger.error("Failed to save OCR result for \(identifier): \(error.localizedDescription)")
        }
    }

    private func compareAndProcessOCRResult(for identifier: String, newText: String) {
        let startTime = Date()

        func alphanumericString(from text: String) -> String {
            let pattern = "[^a-zA-Z0-9]+"
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)
            let alphanumericText = regex?.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "") ?? ""
            return alphanumericText
        }

        let newAlphanumericText = alphanumericString(from: newText)
        var hasChanged = false
        let threshold = (stateChange[identifier] ?? false) ? 2 : 22

        if let previousText = currentOCRTexts[identifier] {
            let previousAlphanumericText = alphanumericString(from: previousText)
            let previousLength = previousAlphanumericText.count
            let newLength = newAlphanumericText.count
            let lengthDifference = abs(previousLength - newLength)

            logger.log("GlobalStatus: \(String(describing: self.globalHasChanged[identifier])). Tmp State: \(String(describing: self.stateChange[identifier])) | Length difference for img1 vs img2 \(identifier) is: \(lengthDifference).")

            if lengthDifference > threshold {
                logger.log("OCR text for identifier \(identifier) has changed.")
                hasChanged = true
                currentOCRTexts[identifier] = newText
                viewModel.results.removeValue(forKey: identifier) //Clear the screen when there is a change detected
                logger.log("Removed results for identifier \(identifier) due to OCR text change.")
                self.saveOCRResult(previousAlphanumericText, for: "img1")
                self.saveOCRResult(newAlphanumericText, for: "img2")
            } else {
                logger.log("OCR text for identifier \(identifier) has not changed.")
                triggerAdditionalCommandSuggestionIfNeeded(identifier: identifier)
                // RUN VERIFICATIONS TO TRIGGER THE GENERATION OF A NEW SUGGESTION UNTIL THE LIMIT
                // 1. Check if two initial prompts have executed. 
                //2. Check if the given identifier has a len(gptResponses) >= 1. AND len <= 6 (hardLimit of suggestions) viewModel @Published var results: [String: (suggestionsCount: Int, gptResponses: [Dictionary<String, String>], updatedAt: Date)] = [:]
                // Check if the processing for source 'additionalSuggestion' is being processed or not.
                // If all those conditions pass then trigger the execution of dummyProcess for now. Else do nothing
            }
        } else {
            logger.log("Initializing OCR text for identifier \(identifier).")
            currentOCRTexts[identifier] = newText
            hasChanged = true
        }

        let previousState = stateChange[identifier] ?? false
        
        if hasChanged {
            // Reflect the change immediately for changed to changed
            globalHasChanged[identifier] = hasChanged
            viewModel.currentStateText = "Detecting Changes"
            stateChangeEventID[identifier] = UUID()
            stateChangeTimestamps[identifier] = Date()
        } else if previousState && !hasChanged {
            logger.log("OCR text for identifier \(identifier) changed to unchanged. Triggering process...")
            triggerDelayedStateUpdate(for: identifier)
        }

        stateChange[identifier] = hasChanged

        let endTime = Date()
        let timeInterval = endTime.timeIntervalSince(startTime)
        logger.log("Time taken for compare and process OCR result: \(timeInterval) seconds")
    }
    
    private func triggerAdditionalCommandSuggestionIfNeeded(identifier: String) {
        // Check if two initial prompts have executed.
        guard self.ocrProcessingHandler.didFirstTwoPromptsRun(forIdentifier: identifier) else {
            self.logger.debug("Two initial prompts have not executed for identifier \(identifier).")
            return
        }
        
        // Check if the given identifier has at least one response and at most six responses.
        guard let resultInfo = viewModel.results[identifier], resultInfo.gptResponses.count > 0 && resultInfo.gptResponses.count <= 5 else {
            self.logger.debug("Identifier \(identifier) does not have at least one response or has more than six responses.")
            return
        }
        
        // Check if the processing for source 'additionalSuggestion' is being processed or not.
        guard !self.ocrProcessingHandler.isSourceExecuting(forIdentifier: identifier, source: "additionalSuggestion") else {
            self.logger.debug("Processing for 'additionalSuggestion' is already in progress for identifier \(identifier).")
            return
        }

        // All conditions passed, trigger the execution of dummyProcess
        self.logger.debug("All conditions passed for identifier \(identifier). Triggering dummy process.")
        dummyProcess()
        
        // Get the OCR results for this identifier
        guard let ocrResult = self.ocrProcessingHandler.ocrResults[identifier],
              let visionText = ocrResult["vision"],
              let localText = ocrResult["local"] else {
            self.logger.error("OCR results not found for identifier \(identifier).")
            return
        }

        // Extract suggested commands
        let suggestions = resultInfo.gptResponses.compactMap { $0["suggestedCommand"] }.joined(separator: ", ")

        // Prepare the message for additional suggestion
        let message = "This is the user terminal raw content: \(localText) and this is the structured terminal content: \(visionText). Based on that I already have these suggestions: \(suggestions). Can you provide a better alternative that will help the user better? Do not generate duplicated suggestion commands."

        // Trigger the execution of additional suggestion process
        self.ocrProcessingHandler.processOCRResults(threadId: self.ocrProcessingHandler.threadId, text: message, source: "additionalSuggestion", identifier: identifier) {
            self.logger.debug("Additional suggestion process completed for identifier \(identifier).")
        }
    }

    
    private func dummyProcess() {
        logger.log("Dummy process triggered.")
    }

    private func triggerDelayedStateUpdate(for identifier: String) {
        let eventID = UUID()
        stateChangeEventID[identifier] = eventID
        stateChangeTimestamps[identifier] = Date()

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            if let lastEventID = self.stateChangeEventID[identifier], lastEventID == eventID {
                self.globalHasChanged[identifier] = false
                self.viewModel.currentStateText = "No Changes on Terminal"
                self.logger.log("Global state updated to unchanged for identifier \(identifier).")
                
                self.ocrProcessingHandler.removeIdentifierFromOCRResults(identifier)
                self.ocrProcessingHandler.removeIdentifierFromSourceExecutionStatus(identifier)

                // Start new processing for the identifier
                if let image = self.capturedImages[identifier], let localText = self.currentOCRTexts[identifier] {
                    self.saveImage(image, for: identifier) // Save image to local file for debug purpose
                    self.ocrProcessingHandler.processImage(identifier: identifier, image: image, localText: localText) {
                        self.logger.log("Processing completed for identifier \(identifier).")
                    }
                }
            }
        }
    }
    
    private func saveImage(_ cgImage: CGImage, for identifier: String) {
        let tmpDir = FileManager.default.temporaryDirectory
        let timestamp = Date().timeIntervalSince1970
        let filePath = tmpDir.appendingPathComponent("\(identifier)_\(timestamp).png")

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            logger.error("Failed to convert image to PNG for \(identifier)")
            return
        }

        do {
            try pngData.write(to: filePath)
            logger.log("Saved image for \(identifier) to \(filePath.path)")
        } catch {
            logger.error("Failed to save image for \(identifier): \(error.localizedDescription)")
        }
    }

    
    func deleteTmpFiles() {
        let tmpDir = FileManager.default.temporaryDirectory
        do {
            let tmpFiles = try FileManager.default.contentsOfDirectory(atPath: tmpDir.path)
            for file in tmpFiles {
                try FileManager.default.removeItem(at: tmpDir.appendingPathComponent(file))
            }
            logger.log("Temporary files deleted.")
        } catch {
            logger.error("Failed to delete temporary files: \(error.localizedDescription)")
        }
    }
}
