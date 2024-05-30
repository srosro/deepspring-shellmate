//
//  Logger.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 22/05/24.
//

import Foundation

class Logger1 {
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
