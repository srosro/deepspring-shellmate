//
//  GPTManager.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 24/05/24.
//

import Foundation
import AppKit
import CoreGraphics

class GPTManager {

    /// Retrieve the API key from environment variables
    func retrieveAPIKey() -> String {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            fatalError("API key not found in environment variables")
        }
        return apiKey
    }

    /// Encode CGImage to Base64 string
    func encodeImageToBase64(image: CGImage) -> String? {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let imageData = bitmapRep.representation(using: .jpeg, properties: [:]) else { return nil }
        return imageData.base64EncodedString()
    }

    /// Send OCR results to ChatGPT for processing and command suggestion.
    func sendOCRResultsToChatGPT(ocrResults: [String: String], highlight: String = "", completion: @escaping (String) -> Void) {
        let apiKey = retrieveAPIKey()

        var prompt = """
            You are a helpful sysadmin bot designed to assist users by analyzing the current text from their terminal.
            When a user submits the text, your task is to infer their intention and suggest the most appropriate command
            to help them achieve their goal. Focus primarily on the most recent command or the last error encountered.
            Review the history of commands to determine if they provide context that could inform your response to the
            current request. If there's no relevant connection between past commands and the current request, concentrate
            solely on the latest input. If any information is highlighted, then this should be the main focus, to help with
            the user's immediate needs. Highlighted information should be considered a key area of focus or a problem area
            that needs direct attention. Your response must be in a strict JSON format, with keys 'intention' and 'command'
            clearly defined. Responses should be concise, ideally under 400 characters, and should provide only one command.
            Concatenate multiple steps into a single line command if necessary. Ensure your response is structured as follows:
            `{"intention": "<intended action>", "command": "<suggested command>"}`. This strict format is crucial as the
            system relies on this structured response for further processing.
        """
        for (identifier, text) in ocrResults {
            prompt += "Terminal Window \(identifier): \(text)\n\n"
        }

        let messages: [[String: String]] = [
            ["role": "system", "content": prompt],
            ["role": "user", "content": "Here is the output from my terminal, please analyze."]
        ]

        let json: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "max_tokens": 400  // Adjust token limit if necessary
        ]

        sendRequest(json: json, apiKey: apiKey, completion: completion)
    }

    /// Send image to ChatGPT for OCR and further processing.
    func sendImageToOpenAIVision(image: CGImage, identifier: String, completion: @escaping (String) -> Void) {
        let apiKey = retrieveAPIKey()
        guard let base64Image = encodeImageToBase64(image: image) else {
            print("Failed to encode image to Base64.")
            return
        }

        let prompt = """
            You are a sysadmin bot tasked with analyzing a macOS terminal screenshot. Extract all text from the image and format it in the following JSON structure:

            {
              "extractedText": ["commands and outputs from terminal"],
              "highlighted": "highlighted text",
              "shellbuddyMessages": "shellbuddy messages",
            }

            Requirements:
            1. `extractedText`: String with commands and outputs from the terminal, excluding the user and PC name.
            2. `highlighted`: All highlighted text on the screen.
            3. `shellbuddyMessages`: All text that starts with 'sb' or 'SB'.

            Response Format:
            - Adhere strictly to the JSON format, this format is crucial for further processing.
        """


        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
                ]
            ]
        ]

        let json: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "max_tokens": 1000
        ]

        sendRequest(json: json, apiKey: apiKey, completion: completion)
    }

    /// Execute the network request to the GPT API
    private func sendRequest(json: [String: Any], apiKey: String, completion: @escaping (String) -> Void) {
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

            guard let data = data, let rawJSON = String(data: data, encoding: .utf8) else {
                print("No data received or failed to encode data as string")
                return
            }

            // Print the raw JSON string for debugging
            print("Raw JSON received: \(rawJSON)")

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
                print("Error parsing JSON response: \(error)")
            }
        }

        task.resume()
    }

}

