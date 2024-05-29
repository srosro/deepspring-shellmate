//
//  WindowCaptureManager.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 15/05/24.
//

import AppKit
import Vision
import Foundation
import CoreGraphics


func performOCR(on image: CGImage, completion: @escaping (String) -> Void) {
    let startTime = Date()  // Start time

    let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
    let request = VNRecognizeTextRequest { (request, error) in
        guard error == nil else { return }
        if let observations = request.results as? [VNRecognizedTextObservation] {
            var extractedText = ""
            for observation in observations {
                if let topCandidate = observation.topCandidates(1).first {
                    extractedText += topCandidate.string + "\n"
                }
            }
            let endTime = Date()  // End time
            let timeInterval = endTime.timeIntervalSince(startTime)  // Calculate the duration
            print("Time taken for OCR: \(timeInterval) seconds")
            completion(extractedText)
        }
    }
    request.recognitionLevel = .accurate
    try? requestHandler.perform([request])
}


func deleteTmpFiles() {
    let fileManager = FileManager.default
    let directoryPath = NSTemporaryDirectory() + "shellbuddy/tmp"
    do {
        let files = try fileManager.contentsOfDirectory(atPath: directoryPath)
        for file in files {
            try fileManager.removeItem(atPath: "\(directoryPath)/\(file)")
        }
        print("Temporary files deleted successfully.")
    } catch {
        print("Failed to delete files: \(error)")
    }
}
