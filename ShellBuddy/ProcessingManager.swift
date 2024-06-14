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
import Cocoa

class ProcessingManager {
    private let viewModel: AppViewModel
    private let processingQueue = DispatchQueue(label: "com.example.appviewmodel.processingqueue")
    private var processingStatus: [String: Bool] = [:]
    private var currentOCRTexts: [String: String] = [:]
    private var currentHighlightedTexts: [String: String] = [:]
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
        processingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
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

                var fullImageOCRText: String?
                var highlightedTextOCR: String?

                let dispatchGroup = DispatchGroup()

                // Run OCR over the entire image
                dispatchGroup.enter()
                self.runOCR(on: image) { extractedText in
                    fullImageOCRText = extractedText
                    dispatchGroup.leave()
                }

                // Run highlight detection and OCR over the cropped image if highlight is present
                dispatchGroup.enter()
                self.handleHighlightDetectionAndOCR(image: image, identifier: windowID) { highlightedText in
                    highlightedTextOCR = highlightedText
                    dispatchGroup.leave()
                }

                dispatchGroup.notify(queue: .main) {
                    if let fullImageOCRText = fullImageOCRText, let highlightedTextOCR = highlightedTextOCR {
                        self.compareAndProcessOCRResult(for: windowID, newText: fullImageOCRText, newHighlightedText: highlightedTextOCR)
                    }
                    self.processingStatus[windowID] = false
                }

                self.capturedImages[windowID] = image  // Store the captured image
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
                completion("") // Return an empty string in case of error
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

    private func compareAndProcessOCRResult(for identifier: String, newText: String, newHighlightedText: String) {
        let startTime = Date()
        let newAlphanumericText = alphanumericString(from: newText)
        let newAlphanumericHighlightedText = alphanumericString(from: newHighlightedText)
        var hasTerminalTextChanged = false
        var hasHighlightedTextChanged = false

        // Run processExistingOCRText for normal OCR text
        if let previousText = currentOCRTexts[identifier] {
            hasTerminalTextChanged = processExistingOCRText(identifier: identifier, newAlphanumericText: newAlphanumericText, previousText: previousText, newText: newText)
        } else {
            initializeOCRText(for: identifier, newText: newText)
            hasTerminalTextChanged = true
        }

        // Run processExistingHighlightedText for highlighted text if it is not an empty string
        if newHighlightedText != "" {
            if let previousHighlightedText = currentHighlightedTexts[identifier] {
                hasHighlightedTextChanged = processExistingHighlightedText(identifier: identifier, newAlphanumericText: newAlphanumericHighlightedText, previousText: previousHighlightedText, newText: newHighlightedText)
            } else {
                initializeHighlightedText(for: identifier, newText: newHighlightedText)
                hasHighlightedTextChanged = true
            }
        } else {
            currentHighlightedTexts[identifier] = ""
        }

        // Combine the change statuses
        let hasChanged = hasTerminalTextChanged || hasHighlightedTextChanged

        handleStateChange(identifier: identifier, hasChanged: hasChanged)

        let endTime = Date()
        logTimeInterval(startTime: startTime, endTime: endTime)
    }

    private func initializeHighlightedText(for identifier: String, newText: String) {
        logger.log("Initializing highlighted text for identifier \(identifier).")
        currentHighlightedTexts[identifier] = newText
    }

    private func alphanumericString(from text: String) -> String {
        let pattern = "[^a-zA-Z0-9]+"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: text.utf16.count)
        let alphanumericText = regex?.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "") ?? ""
        return alphanumericText
    }

    private func processExistingOCRText(identifier: String, newAlphanumericText: String, previousText: String, newText: String) -> Bool {
        let previousAlphanumericText = alphanumericString(from: previousText)
        let lengthDifference = abs(previousAlphanumericText.count - newAlphanumericText.count)
        let threshold = (stateChange[identifier] ?? false) ? 2 : 20

        logger.log("GlobalStatus: \(String(describing: self.globalHasChanged[identifier])). Tmp State: \(String(describing: self.stateChange[identifier])) | Length difference for img1 vs img2 \(identifier) is: \(lengthDifference).")

        if lengthDifference > threshold {
            logger.log("OCR text for identifier \(identifier) has changed.")
            currentOCRTexts[identifier] = newText
            //saveOCRResult(previousAlphanumericText, for: "img1")
            //saveOCRResult(newAlphanumericText, for: "img2")
            return true
        } else {
            logger.log("OCR text for identifier \(identifier) has not changed.")
            triggerAdditionalCommandSuggestionIfNeeded(identifier: identifier)
            return false
        }
    }

    private func processExistingHighlightedText(identifier: String, newAlphanumericText: String, previousText: String, newText: String) -> Bool {
        let previousAlphanumericText = alphanumericString(from: previousText)
        let lengthDifference = abs(previousAlphanumericText.count - newAlphanumericText.count)
        let threshold = 5

        logger.log("GlobalStatus: \(String(describing: self.globalHasChanged[identifier])). Tmp State: \(String(describing: self.stateChange[identifier])) | Highlighted text length difference for img1 vs img2 \(identifier) is: \(lengthDifference).")

        if lengthDifference > threshold {
            logger.log("Highlighted text for identifier \(identifier) has changed.")
            currentHighlightedTexts[identifier] = newText
            //saveOCRResult(previousAlphanumericText, for: "highlight1")
            //saveOCRResult(newAlphanumericText, for: "highlight2")
            return true
        } else {
            logger.log("Highlighted text for identifier \(identifier) has not changed.")
            triggerAdditionalCommandSuggestionIfNeeded(identifier: identifier)
            return false
        }
    }


    private func initializeOCRText(for identifier: String, newText: String) {
        logger.log("Initializing OCR text for identifier \(identifier).")
        currentOCRTexts[identifier] = newText
    }

    private func initializeNewBatchForSuggestionsHistory(identifier: String) {
        if var result = viewModel.results[identifier] {
            result.suggestionsHistory.append([])
            viewModel.results[identifier] = result
        }
        logger.log("Initialized a new batch of items in suggestionsHistory for identifier \(identifier) due to OCR text change.")
    }

    private func handleStateChange(identifier: String, hasChanged: Bool) {
        let previousState = stateChange[identifier] ?? false

        if hasChanged {
            initializeNewBatchForSuggestionsHistory(identifier: identifier)
            globalHasChanged[identifier] = hasChanged
            viewModel.currentStateText = "Detecting changes..."
            stateChangeEventID[identifier] = UUID()
            stateChangeTimestamps[identifier] = Date()
        } else if previousState && !hasChanged {
            logger.log("OCR text for identifier \(identifier) changed to unchanged. Triggering process...")
            triggerDelayedStateUpdate(for: identifier)
        }

        stateChange[identifier] = hasChanged
    }
    
    private func logTimeInterval(startTime: Date, endTime: Date) {
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
        guard let resultInfo = viewModel.results[identifier],
              let lastBatch = resultInfo.suggestionsHistory.last,
              lastBatch.count > 0 && lastBatch.count < 4 else {
            self.logger.debug("Identifier \(identifier) does not have at least one response or has more than 4 responses in the last batch.")
            return
        }
        
        // Check if the processing for source 'additionalSuggestion' is being processed or not.
        guard !self.ocrProcessingHandler.isSourceExecuting(forIdentifier: identifier, source: "additionalSuggestion") else {
            self.logger.debug("Processing for 'additionalSuggestion' is already in progress for identifier \(identifier).")
            return
        }
        
        // All conditions passed, trigger the execution of dummyProcess
        self.logger.debug("All conditions passed for identifier \(identifier)")
        
        // Get the OCR results for this identifier
        guard let ocrResult = self.ocrProcessingHandler.ocrResults[identifier],
              let localText = ocrResult["local"] else {
            self.logger.error("OCR results not found for identifier \(identifier).")
            return
        }
        
        // Declare suggestions variable outside the scope
        var suggestions = ""
        // Extract suggested commands from the last batch
        if let lastBatch = resultInfo.suggestionsHistory.last {
            suggestions = lastBatch.compactMap { $0["suggestedCommand"] }.joined(separator: ", ")
        }
        
        // Extract highlighted text
        let highlightedText = self.currentHighlightedTexts[identifier] ?? ""
        
        // Create message content
        let messageContent = highlightedText.isEmpty ? localText : "\(localText)\nHighlighted text by user: \(highlightedText)"
        
        // Prepare the message for additional suggestion
        let message = "This is the user terminal raw content: \(messageContent). Based on that I already have these suggestions: \(suggestions). Can you provide a better alternative that will help the user better? Do not generate duplicated suggestion commands."
        
        // Trigger the execution of additional suggestion process
        self.ocrProcessingHandler.processOCRResults(text: message, highlightedText: highlightedText,source: "additionalSuggestion", identifier: identifier) {
            self.logger.debug("Additional suggestion process completed for identifier \(identifier).")
        }
    }


    private func triggerDelayedStateUpdate(for identifier: String) {
        let eventID = UUID()
        stateChangeEventID[identifier] = eventID
        stateChangeTimestamps[identifier] = Date()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            if let lastEventID = self.stateChangeEventID[identifier], lastEventID == eventID {
                self.globalHasChanged[identifier] = false
                self.viewModel.currentStateText = "No Changes on Terminal"
                self.logger.log("Global state updated to unchanged for identifier \(identifier).")
                
                self.ocrProcessingHandler.removeIdentifierFromOCRResults(identifier)
                self.ocrProcessingHandler.removeIdentifierFromSourceExecutionStatus(identifier)

                // Start new processing for the identifier
                if let image = self.capturedImages[identifier], let localText = self.currentOCRTexts[identifier], let highlightedText = self.currentHighlightedTexts[identifier] {
                    self.saveImage(image, for: identifier) // Save image to local file for debug purpose
                    self.ocrProcessingHandler.processImage(identifier: identifier, image: image, localText: localText, highlightedText: highlightedText) {
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
    
    
    
    
    // NEW CODE
    

    func encodeImageToBase64(image: CGImage) -> String? {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let imageData = bitmapRep.representation(using: .jpeg, properties: [:]) else {
            logger.error("Failed to encode image to JPEG data.")
            return nil
        }
        return imageData.base64EncodedString()
    }

    func saveImageToDisk(imageData: Data, identifier: String) -> String? {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsDirectory = urls.first else {
            logger.error("Failed to access documents directory.")
            return nil
        }
        let fileName = "processed_\(identifier).jpeg"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        do {
            try imageData.write(to: fileURL)
            logger.info("Saved processed image to \(fileURL.path)")
            return fileURL.path
        } catch {
            logger.error("Failed to save image: \(error)")
            return nil
        }
    }

    func sendImageToFastAPIServer(image: CGImage, identifier: String, completion: @escaping (CGImage?, Bool?) -> Void) {
        guard let base64Image = encodeImageToBase64(image: image) else {
            completion(nil, nil)
            return
        }
        
        let url = URL(string: "http://localhost:8000/upload-image/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let json: [String: Any] = ["image": base64Image]
        let jsonData = try! JSONSerialization.data(withJSONObject: json, options: [])
        request.httpBody = jsonData
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                self.logger.error("Failed to send image to FastAPI server: \(String(describing: error))")
                completion(nil, nil)
                return
            }
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let base64CroppedImage = jsonResponse["cropped_image"] as? String,
                   let croppedImageData = Data(base64Encoded: base64CroppedImage),
                   let isHighlightPresent = jsonResponse["is_highlight_present"] as? Bool {
                    
                    // Create CGImage from the Base64 encoded cropped image data
                    let croppedImage = self.createImage(from: croppedImageData)
                    completion(croppedImage, isHighlightPresent)
                    
                } else {
                    self.logger.error("Invalid response from FastAPI server.")
                    completion(nil, nil)
                }
            } catch {
                self.logger.error("Failed to decode JSON response: \(error)")
                completion(nil, nil)
            }
        }
        task.resume()
    }

    // Helper function to create CGImage from Data
    private func createImage(from data: Data) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    }

    
    private func handleHighlightDetectionAndOCR(image: CGImage, identifier: String, completion: @escaping (String) -> Void) {
        sendImageToFastAPIServer(image: image, identifier: identifier) { [weak self] croppedImage, isHighlightPresent in
            guard let self = self else { return }

            if let isHighlightPresent = isHighlightPresent {
                self.logger.info("Highlight present: \(isHighlightPresent)")

                // If highlight is present, run OCR on the cropped image
                if let croppedImage = croppedImage {
                    self.logger.info("Running OCR on cropped image")

                    self.runOCR(on: croppedImage) { extractedText in
                        self.logger.info("Extracted text from highlighted region for identifier \(identifier): \(extractedText)")
                        completion(extractedText)
                    }
                } else {
                    self.logger.error("Failed to create cropped image for identifier \(identifier).")
                    completion("")
                }
            } else {
                self.logger.error("Highlight was not present for identifier \(identifier).")
                completion("")
            }
        }
    }

    
}


