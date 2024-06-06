//
//  main.swift
//  ShellBuddyCLI
//
//  Created by Daniel Delattre on 05/06/24.
//

import Foundation
import AppKit

// Function to get the Downloads directory
func getDownloadsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
    return paths[0]
}

// Function to load a command from JSON file
func loadCommandFromJSON(filePath: URL, key: String) -> String? {
    do {
        let data = try Data(contentsOf: filePath)
        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
            return json[key]
        }
    } catch {
        print("Error loading or parsing JSON: \(error)")
    }
    return nil
}

// Function to copy text to clipboard
func copyToClipboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

// Function to start the paste process
func startPasteProcess() {
    let task = Process()
    task.launchPath = "~/shellbuddy/sb_paste"
    task.launch()
}

// Function to process command ID
func processCommandID(_ key: String, filePath: URL) {
    // Load the command from JSON using the key
    if let command = loadCommandFromJSON(filePath: filePath, key: key) {
        copyToClipboard(command)
        // Start the paste process
        startPasteProcess()
    } else {
        print("Failed to load command for key \(key)")
    }
}

// Main function
func sbCLIMain() {
    // Get the path to the Downloads directory
    let downloadsDirectory = getDownloadsDirectory()
    let filePath = downloadsDirectory.appendingPathComponent("shellBuddyCommandSuggestions.json")
    
    // Verify the file exists
    guard FileManager.default.fileExists(atPath: filePath.path) else {
        print("JSON file does not exist at path: \(filePath.path)")
        return
    }
    
    // Get the arguments passed to the script
    let arguments = CommandLine.arguments
    
    // Check if the correct number of arguments is provided
    guard arguments.count == 2 else {
        print("""
        Wrong Usage:
        For command suggestions:
            sb <number> (e.g., sb 2; sb 1.5)

        For message requests:
            sb "insert your message with quotations" (e.g., sb "How can I find my external IP address?")\n
        """)
        return
    }
    
    // Get the argument
    let argument = arguments[1]
    
    // Check if the argument can be cast to a float
    if let _ = Float(argument) {
        // Process as command ID
        processCommandID(argument, filePath: filePath)
    } else {
        // Process as user message (return without printing anything)
        return
    }
}

// Usage
sbCLIMain()
