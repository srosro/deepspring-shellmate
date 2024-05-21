//
//  WindowCaptureManager.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 15/05/24.
//

import Cocoa
import AppKit
import Vision
import Foundation
import CoreGraphics
import ScreenCaptureKit


func captureAllTerminalWindows(completion: @escaping ([(identifier: String, image: CGImage?)]) -> Void) {
    // Asynchronously discover all shareable content for the current process
    SCShareableContent.getWithCompletionHandler { content, error in
        guard let content = content, error == nil else {
            print("Failed to discover shareable content: \(error?.localizedDescription ?? "Unknown error")")
            completion([])
            return
        }
        
        CGMainDisplayID() // Necessary to avoid problems: https://forums.developer.apple.com/forums/thread/743615
        // Filter windows to find any window belonging to the Terminal application with a non-empty title
        let terminalWindows = content.windows.filter { window in
            if let app = window.owningApplication, app.applicationName == "Terminal" {
                // Check if the window is visible on screen
                if window.isOnScreen {
                    // Check window size to filter out small auxiliary windows
                    let minSize: CGFloat = 40
                    if window.frame.width > minSize && window.frame.height > minSize {
                        return window.title?.isEmpty == false
                    }
                }
            }
            return false
        }
        
        print("Terminal windows found: \(terminalWindows.count)")
        terminalWindows.forEach { window in
            print("Window title: \(window.title ?? "Unknown")")
        }
        
        var results: [(identifier: String, image: CGImage?)] = []
        let group = DispatchGroup()
        
        for window in terminalWindows {
            group.enter()
            
            let config = SCStreamConfiguration()
            config.width = Int(window.frame.width)
            config.height = Int(window.frame.height)
            
            let filter = SCContentFilter(desktopIndependentWindow: window)
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) { image, error in
                if let error = error {
                    print("Failed to capture screenshot for window \(window.windowID): \(error.localizedDescription)")
                } else {
                    let identifier = "\(window.windowID)_\(window.title ?? "unknown")"
                    print("Screenshot captured successfully for window \(identifier).")
                    results.append((identifier: identifier, image: image))
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(results)
        }
    }
}


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



func sendOCRResultsToChatGPT(ocrResults: [String: String], highlight: String = "", completion: @escaping (String) -> Void) {
    guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
        fatalError("API key not found in environment variables")
    }    
    var prompt = "Analyze the following terminal session (paying attention to "

    if highlight.isEmpty {
        prompt += "the last command or line):\n"
    } else {
        prompt += "the words \"\(highlight)\"):\n"
    }

    for (identifier, text) in ocrResults {
        prompt += "Terminal Window \(identifier):\n\(text)\n\n"
    }
    prompt += "What am I trying to do, and what would be a better command if there is an error?"

    let systemMessage = """
    You are a helpful, knowledgeable, and concise sysadmin assistant. When useful, you return one shell command at a time, bracketed by three backticks (```). Each command should begin with $ with the output formatted as a list of commands:
    ```bash
    $command1
    $command2
    ```
    It is mandatory that all commands should be formatted following the guidelines.
    """
    
    let messages: [[String: String]] = [
        ["role": "system", "content": systemMessage],
        ["role": "user", "content": "I'm using terminal on MacOS. I'd like to share my output with you and get your advice."],
        ["role": "assistant", "content": "Sure! Let me see it."],
        ["role": "user", "content": prompt]
    ]
    
    let json: [String: Any] = [
        "model": "gpt-3.5-turbo",
        "messages": messages,
        "max_tokens": 100
    ]

    guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
    } catch {
        print("Failed to serialize JSON: \(error)")
        return
    }

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error during request: \(error)")
            return
        }

        guard let data = data else {
            print("No data received")
            return
        }

        do {
            if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = jsonResponse["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                completion(content)
            } else {
                print("Failed to parse JSON response")
            }
        } catch {
            print("Error parsing response: \(error)")
        }
    }

    task.resume()
}


class Logger {
    struct LogEntry: Codable {
        let identifier: String
        let startedAt: Date
        var ocrDurationSeconds: TimeInterval?
        var gptDurationSeconds: TimeInterval?
        var ocrResult: String?
        var gptResponse: String?
        var recommendedCommands: [String]?
    }

    private var logs: [String: LogEntry] = [:]
    private var recentLogs: [LogEntry] = []
    private let maxRecentLogs = 10  // Change this value to set the desired buffer size
    private let dateFormatter: DateFormatter
    private let logFileURL: URL

    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        let directoryPath = NSTemporaryDirectory() + "shellbuddy/tmp"
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: directoryPath) {
            do {
                try fileManager.createDirectory(atPath: directoryPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Failed to create directory: \(error)")
            }
        }
        
        logFileURL = URL(fileURLWithPath: "\(directoryPath)/logs.json")
    }

    func logCapture(identifier: String) {
        let startedAt = Date()
        let logEntry = LogEntry(identifier: identifier, startedAt: startedAt)
        logs[identifier] = logEntry
        print("Capture logged for \(identifier) at \(dateFormatter.string(from: startedAt))")
    }

    func logOCR(identifier: String, result: String) {
        if var logEntry = logs[identifier] {
            let ocrFinishTime = Date()
            logEntry.ocrDurationSeconds = ocrFinishTime.timeIntervalSince(logEntry.startedAt)
            logEntry.ocrResult = result
            logs[identifier] = logEntry
            print("OCR logged for \(identifier) with duration: \(logEntry.ocrDurationSeconds!) seconds and result: \(result)")
        } else {
            print("Error: No capture log found for \(identifier) to log OCR")
        }
    }

    func logGPT(identifier: String, response: String, commands: [String]) {
        if var logEntry = logs[identifier] {
            let gptFinishTime = Date()
            logEntry.gptDurationSeconds = gptFinishTime.timeIntervalSince(logEntry.startedAt) - (logEntry.ocrDurationSeconds ?? 0)
            logEntry.gptResponse = response
            logEntry.recommendedCommands = commands
            logs[identifier] = logEntry
            saveLogEntryToFile(logEntry)
            addLogEntryToRecent(logEntry)  // Add log entry to recent logs
            print("GPT logged for \(identifier) with duration: \(logEntry.gptDurationSeconds!) seconds, response: \(response) and commands: \(commands)")
        } else {
            print("Error: No OCR log found for \(identifier) to log GPT")
        }
    }

    func getLogs() -> [LogEntry] {
        return Array(logs.values)
    }


    func printLogFilePath() {
        print("Log file path: \(logFileURL.path)")
    }

    func getRecentLogs() -> [LogEntry] {
        return recentLogs
    }

    private func addLogEntryToRecent(_ logEntry: LogEntry) {
        if recentLogs.count >= maxRecentLogs {
            recentLogs.removeFirst()
        }
        recentLogs.append(logEntry)
        print("Recent Logs: \(recentLogs)") // Debugging print statement

    }

    private func saveLogEntryToFile(_ logEntry: LogEntry) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let logData = try encoder.encode(logEntry)
            if let logString = String(data: logData, encoding: .utf8) {
                let logLine = logString + "\n"
                if let handle = try? FileHandle(forWritingTo: logFileURL) {
                    handle.seekToEndOfFile()
                    if let logData = logLine.data(using: .utf8) {
                        handle.write(logData)
                    }
                    handle.closeFile()
                } else {
                    try logLine.write(to: logFileURL, atomically: true, encoding: .utf8)
                }
                print("Log saved to file: \(logFileURL.path)")
            }
        } catch {
            print("Failed to save log entry to file: \(error)")
        }
    }
}
