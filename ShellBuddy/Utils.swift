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
            completion(extractedText)
        }
    }
    try? requestHandler.perform([request])
}

func saveImage(_ image: CGImage, identifier: String) {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyyMMddHHmmss"
    let timestamp = dateFormatter.string(from: Date())
    let directoryPath = NSTemporaryDirectory() + "shellbuddy/tmp"
    let filePath = "\(directoryPath)/screenshot_\(identifier)_\(timestamp).png"
    
    let fileManager = FileManager.default
    if (!fileManager.fileExists(atPath: directoryPath)) {
        do {
            try fileManager.createDirectory(atPath: directoryPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Failed to create directory: \(error)")
            return
        }
    }
    
    let bitmapRep = NSBitmapImageRep(cgImage: image)
    guard let data = bitmapRep.representation(using: .png, properties: [:]) else { return }
    do {
        try data.write(to: URL(fileURLWithPath: filePath))
        print("Saved image to \(filePath)")
    } catch {
        print("Failed to save image: \(error)")
    }
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
