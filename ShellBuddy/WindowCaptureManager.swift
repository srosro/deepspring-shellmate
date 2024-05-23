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
    
    // Construct the prompt to analyze the terminal text with a nuanced directive
    var prompt = "You are a helpful sysadmin bot designed to assist users by analyzing the current text from their terminal. "
    prompt += "When a user submits the text, your task is to infer their intention and suggest the most appropriate command to help them achieve their goal. "
    prompt += "Focus primarily on the most recent command or the last error encountered. Review the history of commands to determine if they provide context that could inform your response to the current request. "
    prompt += "If there's no relevant connection between past commands and the current request, concentrate solely on the latest input. "
    prompt += "Your response must be in a strict JSON format, with keys `intention` and `command` clearly defined. "
    prompt += "Responses should be concise, ideally under 400 characters, and should provide only one command. Concatenate multiple steps into a single line command if necessary. "
    prompt += "Ensure your response is structured as follows: `{\"intention\": \"<intended action>\", \"command\": \"<suggested command>\"}`. "
    prompt += "This strict format is crucial as the system relies on this structured response for further processing.\n\n"

    // Add details from OCR results
    for (identifier, text) in ocrResults {
        prompt += "Terminal Window \(identifier): \(text)\n\n"
    }

    // Configure the request to OpenAI API
    let messages: [[String: String]] = [
        ["role": "system", "content": prompt],
        ["role": "user", "content": "Here is the output from my terminal, please analyze."]
    ]

    let json: [String: Any] = [
        "model": "gpt-4o",
        "messages": messages,
        "max_tokens": 400  // Adjust token limit if necessary
    ]

    // Create the URL and the request
    guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    // Serialize JSON request body
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
    } catch {
        print("Failed to serialize JSON: \(error)")
        return
    }

    // Execute the request
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error during request: \(error)")
            return
        }

        guard let data = data else {
            print("No data received")
            return
        }

        // Process the response
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



func sendImageToOpenAIVision(image: CGImage, identifier: String, completion: @escaping (String) -> Void) {
    guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
        fatalError("API key not found in environment variables")
    }
    
    let bitmapRep = NSBitmapImageRep(cgImage: image)
    guard let imageData = bitmapRep.representation(using: .jpeg, properties: [:]) else { return }
    let base64Image = imageData.base64EncodedString()

    let prompt = """
        You are a sysadmin bot tasked with analyzing a macOS terminal screenshot. Extract all text from the image and format it in the following JSON structure:

        {
          "extractedText": ["commands and outputs from terminal"],
          "highlighted": "highlighted text",
          "shellbuddyMessages": "shellbuddy messages",
          "intention": "intended action",
          "command": "suggested command"
        }

        Requirements:
        1. `extractedText`: String with commands and outputs from the terminal, excluding the user and PC name.
        2. `highlighted`: All highlighted text on the screen.
        3. `shellbuddyMessages`: All text that starts with 'sg' or 'SG'.
        4. `intention`: Inferred intention of the user based on the terminal text.
        5. `command`: Suggested command to help the user achieve their goal.

        Extraction Directive:
        1. If highlighted text is present, focus solely on solving the highlighted text.
        2. Infer the user's intention and suggest the most appropriate command.
        3. Consider 'sg' or 'SG' as direct user instructions.
        4. Review command history to provide context for your suggestion.
        5. When there is no highlighted text, concentrate on the most recent command or the last error if no relevant past context exists.

        Response Format:
        - Adhere strictly to the JSON format.
        - Keep `intention` concise (under 100 characters).
        - Provide only one suggested command, combining multiple steps into a single command if necessary.

        This strict format is crucial for further processing.
    """

    let messages: [[String: Any]] = [
        [
            "role": "user",
            "content": [
                [
                    "type": "text",
                    "text": prompt
                    
                    
                ],
                [
                    "type": "image_url",
                    "image_url": [
                        "url": "data:image/jpeg;base64,\(base64Image)"
                    ]
                ]
            ]
        ]
    ]

    let json: [String: Any] = [
        "model": "gpt-4o",
        "messages": messages,
        "max_tokens": 1000
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
