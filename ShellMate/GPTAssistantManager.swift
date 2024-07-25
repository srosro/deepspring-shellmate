//
//  GPTAssistantManager.swift
//  ShellMate
//
//  Created by Daniel Delattre on 02/06/24.
//

import Foundation

class GPTAssistantManager {
    let apiKey: String
    var assistantId: String
    let headers: [String: String]
    
    private let pollingInterval: Double = 0.5
    
    init() {
        self.apiKey = retrieveOpenaiAPIKey()
        self.assistantId = ""
        self.headers = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)",
            "OpenAI-Beta": "assistants=v2",
        ]
    }
    
    func setupAssistant() async -> Bool {
        let assistantCreator = GPTAssistantCreator()
        let assistantBaseName = "ShellMateSuggestCommands"
        let assistantCurrentVersion: String
        do {
            assistantCurrentVersion = try getAppVersionAndBuild()
        } catch {
            print("Error retrieving app version and build: \(error)")
            return false
        }
        let assistantInstructions = GPTAssistantInstructions.getInstructions()

        do {
            let assistantId = try await assistantCreator.getOrUpdateAssistant(
                assistantBaseName: assistantBaseName,
                assistantCurrentVersion: assistantCurrentVersion,
                assistantInstructions: assistantInstructions
            )
            print("Assistant ID: \(assistantId)")
            self.assistantId = assistantId
            return true
        } catch {
            print("Error occurred while setting up GPT Assistant: \(error.localizedDescription)")
            return false
        }
    }

    func createThread() async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/threads")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        request.httpBody = "{}".data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        return try await handleResponse(data: data, response: response)
    }
    
    func createMessage(threadId: String, messageContent: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        let payload = ["role": "user", "content": messageContent]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        return try await handleResponse(data: data, response: response)
    }
    
    func startRun(threadId: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        let payload = ["assistant_id": assistantId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        return try await handleResponse(data: data, response: response)
    }
    
    func pollRunStatus(threadId: String, runId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            pollRunStatus(threadId: threadId, runId: runId) { result in
                switch result {
                case .success():
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func pollRunStatus(threadId: String, runId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs/\(runId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        
        func checkStatus() {
            let interval = pollingInterval
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = data,
                      let jsonData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let status = jsonData["status"] as? String else {
                    completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON or bad response"])))
                    return
                }
                print("Checking run status: \(status)")
                if status == "completed" {
                    print("Run completed successfully.")
                    completion(.success(()))
                } else if status == "failed" || status == "cancelled" || status == "expired" {
                    completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Run did not complete successfully: \(status)"])))
                } else {
                    DispatchQueue.global().asyncAfter(deadline: .now() + interval) {
                        checkStatus() // Recursively check after delay
                    }
                }
            }.resume()
        }
        
        checkStatus() // Initial call to start the polling
    }

    func fetchMessageResult(threadId: String) async throws -> [String: Any] {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let jsonData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw  NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to receive or parse data"])
        }
        
        // Print the entire raw JSON response for debugging
        print("Raw JSON response: \(jsonData)")

        if let messages = jsonData["data"] as? [[String: Any]],
           let firstResponse = messages.first,
           let contents = firstResponse["content"] as? [[String: Any]],
           let textContent = contents.first,
           let textDict = textContent["text"] as? [String: Any],
           let textValue = textDict["value"] as? String {
            if let valueDict = self.convertStringToDictionary(text: textValue) {
                print("Parsed GPT response: \(valueDict)")
                return valueDict
            } else {
                throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "JSON string in 'value' could not be parsed"])
            }
        } else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse message content correctly or no content found"])
        }
    }
    
    private func convertStringToDictionary(text: String) -> [String: Any]? {
        // Strip markdown-like code block syntax if present
        let trimmedText = text.replacingOccurrences(of: "```json", with: "")
                              .replacingOccurrences(of: "```", with: "")
                              .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let data = trimmedText.data(using: .utf8) {
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                return json
            } catch {
                print("Failed to convert String to Dictionary: \(error)")
            }
        }
        return nil
    }

    private func handleResponse(data: Data, response: URLResponse) async throws -> String {
        guard let response = response as? HTTPURLResponse,
            response.statusCode == 200,
              let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = jsonObject["id"] as? String else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON or bad response"])
        }
        return id
    }
    
    func processMessageInThread(threadId: String, messageContent: String) async throws -> [String: Any] {
        let messageId = try await createMessage(threadId: threadId, messageContent: messageContent)
        print("Message created successfully with ID: \(messageId)")
        let runId = try await startRun(threadId: threadId)
        print("Run started successfully with ID: \(runId)")
        try await pollRunStatus(threadId: threadId, runId: runId)
        let messageData = try await fetchMessageResult(threadId: threadId)
        return messageData
    }
}
