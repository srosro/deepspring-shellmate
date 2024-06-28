//
//  GPTAssistantManager.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 02/06/24.
//

import Foundation

class GPTAssistantManager {
    let apiKey: String
    let assistantId: String
    let headers: [String: String]
    
    init(assistantId: String) {
        self.apiKey = retrieveOpenaiAPIKey()
        self.assistantId = assistantId
        self.headers = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)",
            "OpenAI-Beta": "assistants=v2",
        ]
    }
    
    func createThread(completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "https://api.openai.com/v1/threads")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        request.httpBody = "{}".data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            self.handleResponse(data: data, response: response, error: error, completion: completion)
        }.resume()
    }
    
    func createMessage(threadId: String, messageContent: String, completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        let payload = ["role": "user", "content": messageContent]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            self.handleResponse(data: data, response: response, error: error, completion: completion)
        }.resume()
    }
    
    func startRun(threadId: String, completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        let payload = ["assistant_id": assistantId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            self.handleResponse(data: data, response: response, error: error, completion: completion)
        }.resume()
    }
    
    func pollRunStatus(threadId: String, runId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs/\(runId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        
        func checkStatus() {
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
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                        checkStatus() // Recursively check after delay
                    }
                }
            }.resume()
        }
        
        checkStatus() // Initial call to start the polling
    }

    func fetchMessageResult(threadId: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data,
                let jsonData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to receive or parse data"])))
                return
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
                    completion(.success(valueDict))
                } else {
                    completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "JSON string in 'value' could not be parsed"])))
                }
            } else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse message content correctly or no content found"])))
            }
        }.resume()
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

    
    private func handleResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<String, Error>) -> Void) {
        if let error = error {
            completion(.failure(error))
            return
        }
        guard let data = data, let response = response as? HTTPURLResponse, response.statusCode == 200,
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = jsonObject["id"] as? String else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON or bad response"])))
            return
        }
        completion(.success(id))
    }

    func processMessageInThread(threadId: String, messageContent: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        createMessage(threadId: threadId, messageContent: messageContent) { result in
            switch result {
            case .success(let messageId):
                print("Message created successfully with ID: \(messageId)")
                self.startRun(threadId: threadId) { result in
                    switch result {
                    case .success(let runId):
                        print("Run started successfully with ID: \(runId)")
                        self.pollRunStatus(threadId: threadId, runId: runId) { result in
                            switch result {
                            case .success():
                                self.fetchMessageResult(threadId: threadId) { result in
                                    switch result {
                                    case .success(let messageData):
                                        print("GPT Response: \(messageData)")
                                        completion(.success(messageData))
                                    case .failure(let error):
                                        print("Error fetching message result: \(error.localizedDescription)")
                                        completion(.failure(error))
                                    }
                                }
                            case .failure(let error):
                                print("Error during run polling: \(error.localizedDescription)")
                                completion(.failure(error))
                            }
                        }
                    case .failure(let error):
                        print("Error starting run: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                print("Error creating message: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}
