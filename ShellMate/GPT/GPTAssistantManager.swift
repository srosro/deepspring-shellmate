//
//  GPTAssistantManager.swift
//  ShellMate
//
//  Created by Daniel Delattre on 02/06/24.
//

import Foundation

class GPTAssistantManager {
  static let shared = GPTAssistantManager()

  var apiKey: String
  var assistantId: String
  var headers: [String: String]

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
    self.apiKey = retrieveOpenaiAPIKey()
    self.headers = [
      "Content-Type": "application/json",
      "Authorization": "Bearer \(apiKey)",
      "OpenAI-Beta": "assistants=v2",
    ]

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

    let (data, response) = try await URLSession.shared.dataWithTimeout(for: request)
    return try await handleResponse(data: data, response: response)
  }

  func createMessage(threadId: String, messageContent: String) async throws -> String {
    let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/messages")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.allHTTPHeaderFields = headers
    let payload = ["role": "user", "content": messageContent]
    request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

    let (data, response) = try await URLSession.shared.dataWithTimeout(for: request)
    return try await handleResponse(data: data, response: response)
  }

  func startRun(threadId: String) async throws -> String {
    // Check if assistantId is not empty
    guard !assistantId.isEmpty else {
      throw NSError(
        domain: "", code: 0,
        userInfo: [NSLocalizedDescriptionKey: "startRun - Assistant ID is empty"])
    }

    let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.allHTTPHeaderFields = headers
    let payload = ["assistant_id": assistantId]
    request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

    let (data, response) = try await URLSession.shared.dataWithTimeout(for: request)
    return try await handleResponse(data: data, response: response)
  }

  func pollRunStatusAsync(
    threadId: String,
    runId: String,
    successStates: [String] = ["completed"],  // Default success state is "completed"
    failureStates: [String] = ["failed", "cancelled", "expired", "incomplete"]  // Default failure states
  ) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      pollRunStatusWithCompletion(
        threadId: threadId, runId: runId, successStates: successStates, failureStates: failureStates
      ) { result in
        switch result {
        case .success():
          continuation.resume()
        case .failure(let error):
          continuation.resume(throwing: error)
        }
      }
    }
  }

  private func pollRunStatusWithCompletion(
    threadId: String,
    runId: String,
    successStates: [String],
    failureStates: [String],
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs/\(runId)")!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.allHTTPHeaderFields = headers

    // Create a URLSession with a custom timeout configuration
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 15.0  // 15 seconds timeout
    configuration.timeoutIntervalForResource = 15.0  // 15 seconds timeout
    let session = URLSession(configuration: configuration)
    let startTime = Date()  // Record the start time of polling

    func checkStatus() {
      let interval = pollingInterval
      session.dataTask(with: request) { data, response, error in
        if let error = error {
          completion(.failure(error))
          return
        }
        guard let data = data,
          let jsonData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let status = jsonData["status"] as? String
        else {
          completion(
            .failure(
              NSError(
                domain: "", code: 0,
                userInfo: [
                  NSLocalizedDescriptionKey: "PollRunStatus - Failed to parse JSON or bad response"
                ]
              )))
          return
        }
        print("Checking run status: \(status)")

        // Check if the status is one of the success states
        if successStates.contains(status) {
          print("Run completed successfully with status: \(status)")
          completion(.success(()))
          return
        }
        // Check if the status is one of the failure states
        else if failureStates.contains(status) {
          print("Run failed with status: \(status)")
          completion(
            .failure(
              NSError(
                domain: "", code: 0,
                userInfo: [
                  NSLocalizedDescriptionKey: "PollRunStatus - Run failed with status: \(status)"
                ]
              )))
          return
        }
        // Check if the status is 'cancelling' and if it has exceeded 10 seconds
        else if status == "cancelling" {
          let elapsedTime = Date().timeIntervalSince(startTime)
          if elapsedTime > 10.0 {
            print("Polling stopped: Run stuck in 'cancelling' state for more than 10 seconds.")
            completion(
              .failure(
                NSError(
                  domain: "GPTAssistantErrorDomain", code: 1002,
                  userInfo: [
                    NSLocalizedDescriptionKey:
                      "Run stuck in 'cancelling' state for more than 10 seconds",
                    "failureReason": "cancelling",
                  ]
                )))
            return
          }
        }
        // Poll again after a delay if neither success nor failure states are met
        else {
          DispatchQueue.global().asyncAfter(deadline: .now() + interval) {
            checkStatus()  // Recursively check after delay
          }
        }
      }.resume()
    }
    checkStatus()  // Initial call to start the polling
  }

  func fetchMessageResult(threadId: String) async throws -> [String: Any] {
    let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/messages")!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.allHTTPHeaderFields = headers

    let (data, _) = try await URLSession.shared.dataWithTimeout(for: request)
    guard let jsonData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw NSError(
        domain: "", code: 0,
        userInfo: [NSLocalizedDescriptionKey: "Failed to receive or parse data"])
    }

    // Print the entire raw JSON response for debugging
    print("Raw JSON response: \(jsonData)")

    if let messages = jsonData["data"] as? [[String: Any]],
      let firstResponse = messages.first,
      let contents = firstResponse["content"] as? [[String: Any]],
      let textContent = contents.first,
      let textDict = textContent["text"] as? [String: Any],
      let textValue = textDict["value"] as? String
    {
      if let valueDict = self.convertStringToDictionary(text: textValue) {
        print("Parsed GPT response: \(valueDict)")
        return valueDict
      } else {
        throw NSError(
          domain: "", code: 0,
          userInfo: [NSLocalizedDescriptionKey: "JSON string in 'value' could not be parsed"])
      }
    } else {
      throw NSError(
        domain: "", code: 0,
        userInfo: [
          NSLocalizedDescriptionKey: "Failed to parse message content correctly or no content found"
        ])
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
    // Log the raw response
    if let httpResponse = response as? HTTPURLResponse {
      print("HTTP Status Code: \(httpResponse.statusCode)")
      print("Headers: \(httpResponse.allHeaderFields)")
    } else {
      print("Unexpected response type: \(response)")
    }

    // Log the raw data received
    let responseDataString =
      String(data: data, encoding: .utf8) ?? "Unable to convert data to string"
    print("Response Data: \(responseDataString)")

    // Attempt to parse the JSON
    guard let httpResponse = response as? HTTPURLResponse,
      httpResponse.statusCode == 200
    else {
      throw NSError(
        domain: "", code: 0,
        userInfo: [NSLocalizedDescriptionKey: "HandleResponse - Non-200 HTTP response"])
    }

    do {
      guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw NSError(
          domain: "", code: 0,
          userInfo: [NSLocalizedDescriptionKey: "HandleResponse - Failed to parse JSON"])
      }

      // Log the parsed JSON object
      print("Parsed JSON: \(jsonObject)")

      guard let id = jsonObject["id"] as? String else {
        throw NSError(
          domain: "", code: 0,
          userInfo: [NSLocalizedDescriptionKey: "HandleResponse - 'id' key not found in JSON"])
      }

      return id
    } catch {
      print("JSON Parsing Error: \(error.localizedDescription)")
      throw NSError(
        domain: "", code: 0,
        userInfo: [
          NSLocalizedDescriptionKey:
            "HandleResponse - JSON Parsing Error: \(error.localizedDescription)"
        ])
    }
  }

  func getMostRecentRun(threadId: String) async throws -> [String: Any]? {
    let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs?limit=1&order=desc")!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.allHTTPHeaderFields = headers

    let (data, _) = try await URLSession.shared.dataWithTimeout(for: request)
    guard let jsonData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let runs = jsonData["data"] as? [[String: Any]],
      let mostRecentRun = runs.first
    else {
      return nil
    }
    return mostRecentRun
  }

  func processMessageInThread(terminalID: String, messageContent: String) async throws -> [String:
    Any]
  {
    // Fetch or create the threadId from GPTAssistantThreadIDManager
    let threadId = try await GPTAssistantThreadIDManager.shared.getOrCreateThreadId(for: terminalID)
    // Check if threadId is empty or nil (in case the manager returns an empty string)
    guard !threadId.isEmpty else {
      throw NSError(
        domain: "GPTAssistantErrorDomain", code: 1001,
        userInfo: [NSLocalizedDescriptionKey: "Thread ID is empty. Cannot proceed."])
    }

    // This is necessary to avoid the case where API is slow and execution got stuck
    // To avoid error: "Can't add messages to thread while a run run is active.",
    // Check if there is an active run in progress
    if let mostRecentRun = try await getMostRecentRun(threadId: threadId),
      let status = mostRecentRun["status"] as? String
    {

      // Define the active states that would prevent a new run
      let activeStates = ["queued", "in_progress", "requires_action", "cancelling"]

      if activeStates.contains(status) {
        // If there's an active run, simply return without proceeding
        print(
          "DANBUG: There is already an active run for thread \(threadId) with status \(status). Not proceeding with a new request."
        )
        MixpanelHelper.shared.trackEvent(
          name: "skippedNewRunDueToActiveRun",
          properties: ["status": status, "threadId": threadId]
        )
        return [:]  // Return without processing a new message
      }
    }

    let messageId = try await createMessage(threadId: threadId, messageContent: messageContent)
    print("Message created successfully with ID: \(messageId)")
    let runId = try await startRun(threadId: threadId)
    print("Run started successfully with ID: \(runId)")
    try await pollRunStatusAsync(threadId: threadId, runId: runId)
    let messageData = try await fetchMessageResult(threadId: threadId)
    return messageData
  }
}
