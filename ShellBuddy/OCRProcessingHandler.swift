//
//  OCRProcessingHandler.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 03/06/24.
//

import Foundation
import AppKit
import Vision
import os

class OCRProcessingHandler {
    private let gptManager = GPTManager()
    private let gptAssistantManager = GPTAssistantManager(assistantId: "asst_IQyOH1i0Qjs0agZsBE23nQrS")
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "App", category: "OCRProcessingHandler")
    private let viewModel: AppViewModel
    public var threadId: String?
    public var ocrResults: [String: [String: String]] = [:]
    public var sourceExecutionStatus: [String: [String: String]] = [:]

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        createAssistantThread()
    }
    
    func removeIdentifierFromOCRResults(_ identifier: String) {
        ocrResults.removeValue(forKey: identifier)
    }
    
    func removeIdentifierFromSourceExecutionStatus(_ identifier: String) {
        sourceExecutionStatus.removeValue(forKey: identifier)
    }
    
    func isSourceExecuting(forIdentifier identifier: String, source: String) -> Bool {
        let lowercaseSource = source.lowercased()
        guard let executionStatus = sourceExecutionStatus[identifier], let status = executionStatus[lowercaseSource] else {
            // Source not present in the dictionary, indicating it's not executing
            return false
        }
        return status == "executing"
    }
    
    func didFirstTwoPromptsRun(forIdentifier identifier: String) -> Bool {
        guard let resultDict = ocrResults[identifier] else {
            return false
        }
        return resultDict.keys.contains("vision") && resultDict.keys.contains("local")
    }

    private func createAssistantThread() {
        gptAssistantManager.createThread { [weak self] result in
            switch result {
            case .success(let createdThreadId):
                self?.threadId = createdThreadId
                self?.logger.debug("GPT Assistant thread created successfully with ID: \(createdThreadId)")
            case .failure(let error):
                self?.logger.error("Failed to create GPT Assistant thread: \(error.localizedDescription)")
            }
        }
    }
    
    func processImage(identifier: String, image: CGImage, localText: String, completion: @escaping () -> Void) {
        // Local OCR processing
        logger.debug("Starting local OCR processing for identifier \(identifier).")
        runLocalOCR(on: image) { [weak self] extractedText in
            guard let self = self else { return }
            self.logger.debug("Local OCR Text Output for Window \(identifier): \n----------\n\(extractedText)\n----------\n")
            self.processOCRResults(threadId: self.threadId, text: extractedText, source: "local", identifier: identifier, completion: completion)
        }

        // GPT Vision OCR processing
        logger.debug("Starting GPT Vision OCR processing for identifier \(identifier).")
        gptManager.sendImageToOpenAIVision(image: image, identifier: identifier) { [weak self] text in
            guard let self = self else { return }
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            self.logger.debug("GPT Vision OCR Text Output for Window \(identifier): \n----------\n\(trimmedText)\n----------\n")
            self.processOCRResults(threadId: self.threadId, text: trimmedText, source: "vision", identifier: identifier, completion: completion)
        }
    }

    func processOCRResults(threadId: String?, text: String, source: String, identifier: String, completion: @escaping () -> Void) {
        guard let threadId = threadId else {
            self.logger.error("No GPT Assistant thread available to process OCR results.")
            completion()
            return
        }

        // Update source execution status
        var executionStatusDict = sourceExecutionStatus[identifier] ?? [:]
        executionStatusDict[source.lowercased()] = "executing"
        sourceExecutionStatus[identifier] = executionStatusDict
        
        // Store OCR result
        var resultDict = ocrResults[identifier] ?? [:]
        resultDict[source.lowercased()] = text
        ocrResults[identifier] = resultDict
        
        gptAssistantManager.processMessageInThread(threadId: threadId, messageContent: text) { result in
            // Update source execution status
            var executionStatusDict = self.sourceExecutionStatus[identifier] ?? [:]
            executionStatusDict[source.lowercased()] = "not executing"
            self.sourceExecutionStatus[identifier] = executionStatusDict
            
            switch result {
            case .success(let response):
                self.appendResult(identifier: identifier, response: response["intention"] as? String ?? "", command: response["command"] as? String ?? "")
                completion()
            case .failure(let error):
                self.logger.error("\(source) OCR result processing failed with GPT Assistant: \(error.localizedDescription)")
                completion()
            }
        }
    }

    private func runLocalOCR(on image: CGImage, completion: @escaping (String) -> Void) {
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
                completion(extractedText)
            }
        }
        request.recognitionLevel = .accurate
        try? requestHandler.perform([request])
    }

    private func appendResult(identifier: String, response: String, command: String) {
        let newEntry = ["gptResponse": response, "suggestedCommand": command]
        let currentTime = Date() // Get the current time

        DispatchQueue.main.async {
            self.logger.debug("Appending result for identifier \(identifier). Response: \(response), Command: \(command)")
            if var windowInfo = self.viewModel.results[identifier] {
                // Append new response to the existing array of responses
                windowInfo.gptResponses.append(newEntry)
                // Increment the suggestions count
                windowInfo.suggestionsCount += 1
                // Update the timestamp
                windowInfo.updatedAt = currentTime
                self.viewModel.results[identifier] = windowInfo
            } else {
                // Initialize if this is the first entry for this identifier
                self.viewModel.results[identifier] = (suggestionsCount: 1, gptResponses: [newEntry], updatedAt: currentTime)
            }
            self.viewModel.updateCounter += 1  // Increment the counter to notify a change
        }
    }
}
