import Foundation
import AppKit
import CoreGraphics
import os

class GPTManager {
    private let apiKey: String
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "App", category: "GPTManager")

    init() {
        self.apiKey = retrieveOpenaiAPIKey()
    }

    /// Encode CGImage to Base64 string
    func encodeImageToBase64(image: CGImage) -> String? {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let imageData = bitmapRep.representation(using: .jpeg, properties: [:]) else {
            logger.error("Failed to encode image to JPEG data.")
            return nil
        }
        return imageData.base64EncodedString()
    }

    /// Send image to ChatGPT for OCR and further processing.
    func sendImageToOpenAIVision(image: CGImage, identifier: String, completion: @escaping (String) -> Void) {
        guard let base64Image = encodeImageToBase64(image: image) else {
            logger.error("Failed to encode image to Base64.")
            return
        }

        let prompt = """
            As a sysadmin bot, your task is to analyze a macOS terminal screenshot and extract relevant text, organizing it into a structured JSON format. Focus on the following components:

            {
                "highlighted": "All highlighted text in the terminal",
                "history": [
                    {
                        "command": "The executed command",
                        "output": "Output from the command"
                    }
                ],
                "messagesToAssistant": {
                    "sbMessages": "Commands starting with 'sb' directed to the assistant"
                },
                "mostRecent": {
                    "item": "Most recent item, which could be a command, error message, or 'sb' message"
                }
            }

            Extraction Rules:
            - Exclude any user and PC names from the output.
            - Separate commands and their outputs in the history.
            - Include only text that starts with 'sb' in the 'messagesToAssistant'.
            - Identify and log only the single most recent item (command, error, or 'sb' message) under 'mostRecent'.

            Ensure strict adherence to the JSON structure for compatibility with further processing.
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

        logger.debug("Sending image to OpenAI Vision for OCR.")
        sendRequest(json: json, apiKey: self.apiKey, completion: completion)
    }

    /// Execute the network request to the GPT API
    private func sendRequest(json: [String: Any], apiKey: String, completion: @escaping (String) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            logger.error("Invalid URL for sending request.")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        } catch {
            logger.error("Failed to serialize JSON: \(error.localizedDescription)")
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                self.logger.error("Error during request: \(error.localizedDescription)")
                return
            }

            guard let data = data, let rawJSON = String(data: data, encoding: .utf8) else {
                self.logger.error("No data received or failed to encode data as string.")
                return
            }

            // Log the raw JSON string for debugging
            self.logger.debug("Raw JSON received: \(rawJSON)")

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = jsonResponse["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(content)
                } else {
                    self.logger.error("Failed to parse JSON response.")
                }
            } catch {
                self.logger.error("Error parsing JSON response: \(error.localizedDescription)")
            }
        }

        task.resume()
    }
}

