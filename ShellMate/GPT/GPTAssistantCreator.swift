//
//  GPTAssistantCreator.swift
//  ShellMate
//
//  Created by daniel on 04/07/24.
//

import Foundation
import Sentry

class GPTAssistantCreator {
  let apiKey: String
  let headers: [String: String]

  init() {
    self.apiKey = retrieveOpenaiAPIKey()
    self.headers = [
      "Content-Type": "application/json",
      "Authorization": "Bearer \(apiKey)",
      "OpenAI-Beta": "assistants=v2",
    ]
  }

  func getOrUpdateAssistant(
    assistantBaseName: String, assistantCurrentVersion: String, assistantInstructions: String
  ) async throws -> String {
    let assistantCurrentName = "\(assistantBaseName)\(assistantCurrentVersion)"

    // List and print all assistants
    let assistants = try await listAssistants()
    printAssistants(assistants)

    // Check if the current assistant name is already present in the list
    if let existingAssistant = assistants.first(where: { $0.1 == assistantCurrentName }) {
      print(
        "Assistant with name \(assistantCurrentName) already exists with ID: \(existingAssistant.0)."
      )
      return existingAssistant.0
    }

    // Create new assistant
    return try await createNewAssistant(
      assistantCurrentName: assistantCurrentName, assistantInstructions: assistantInstructions)
  }

  private func printAssistants(_ assistants: [(String, String)]) {
    for assistant in assistants {
      print("Assistant ID: \(assistant.0), Name: \(assistant.1)")
      print("--------------------------------------------------")
    }
  }

  private func createNewAssistant(assistantCurrentName: String, assistantInstructions: String)
    async throws -> String
  {
    let url = URL(string: "https://api.openai.com/v1/assistants")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.allHTTPHeaderFields = headers
    let instructions = [
      "name": assistantCurrentName,
      "instructions": assistantInstructions,
      "model": "gpt-4o",  // Specify the GPT-4 model
    ]
    request.httpBody = try? JSONSerialization.data(withJSONObject: instructions)

    print("createAssistant - Request: \(request)")
    print("createAssistant - Instructions: \(instructions)")

    let (data, response) = try await URLSession.shared.dataWithTimeout(for: request)

    print("createAssistant - Response: \(response)")
    print("createAssistant - Data: \(String(data: data, encoding: .utf8) ?? "No data")")

    guard let response = response as? HTTPURLResponse, response.statusCode == 200,
      let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let assistantId = jsonObject["id"] as? String
    else {
      let error = NSError(
        domain: "GPTAssistantCreatorErrorDomain", code: 1001,
        userInfo: [
          NSLocalizedDescriptionKey: "Create Assistant - Failed to parse JSON or bad response"
        ])
      SentrySDK.capture(error: error)
      throw error
    }

    return assistantId
  }

  func listAssistants() async throws -> [(String, String)] {
    let url = URL(string: "https://api.openai.com/v1/assistants")!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.allHTTPHeaderFields = headers

    print("listAssistants - Request: \(request)")

    let (data, response) = try await URLSession.shared.dataWithTimeout(for: request)

    print("listAssistants - Response: \(response)")
    print("listAssistants - Data: \(String(data: data, encoding: .utf8) ?? "No data")")

    guard let response = response as? HTTPURLResponse, response.statusCode == 200,
      let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let assistants = jsonObject["data"] as? [[String: Any]]
    else {
      let error = NSError(
        domain: "GPTAssistantCreatorErrorDomain", code: 1002,
        userInfo: [
          NSLocalizedDescriptionKey: "Failed to list assistants or bad response",
          "HTTPStatusCode": (response as? HTTPURLResponse)?.statusCode ?? 0,
        ])
      SentrySDK.capture(error: error)
      throw error
    }

    var assistantList: [(String, String)] = []
    for assistant in assistants {
      if let id = assistant["id"] as? String, let name = assistant["name"] as? String {
        assistantList.append((id, name))
      }
    }

    return assistantList
  }

  func getOutdatedAssistants(
    assistants: [(String, String)], assistantBaseName: String, assistantCurrentName: String
  ) -> [String] {
    let regex = try! NSRegularExpression(
      pattern: "^\(NSRegularExpression.escapedPattern(for: assistantBaseName))")
    var outdatedAssistantIds: [String] = []

    for (id, name) in assistants {
      let range = NSRange(location: 0, length: name.utf16.count)
      if regex.firstMatch(in: name, options: [], range: range) != nil
        && name != assistantCurrentName
      {
        outdatedAssistantIds.append(id)
      }
    }
    return outdatedAssistantIds
  }
}
