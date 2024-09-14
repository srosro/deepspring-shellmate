//
//  GPTAssistantThreadIDManager.swift
//  ShellMate
//
//  Created by Daniel Delattre on 09/09/24.
//

class GPTAssistantThreadIDManager {
  static let shared = GPTAssistantThreadIDManager()

  private var threadIdDict: [String: String] = [:]
  private var gptAssistantManager: GPTAssistantManager = GPTAssistantManager.shared

  private init() {}

  func getThreadId(for identifier: String) -> String? {
    return threadIdDict[identifier]
  }

  func setThreadId(_ threadId: String, for identifier: String) {
    threadIdDict[identifier] = threadId
  }

  func removeAllThreadIds() {
    threadIdDict.removeAll()
  }

  func getOrCreateThreadId(for identifier: String) async throws -> String {
    if let threadId = threadIdDict[identifier] {
      print("DEBUG: Found existing thread ID for identifier \(identifier): \(threadId)")
      return threadId
    }

    print("DEBUG: No existing thread ID for identifier \(identifier). Creating a new thread ID.")
    do {
      let createdThreadId = try await gptAssistantManager.createThread()
      threadIdDict[identifier] = createdThreadId
      print("DEBUG: Created new thread ID for identifier \(identifier): \(createdThreadId)")
      return createdThreadId
    } catch {
      print("DEBUG: Failed to create thread ID for identifier \(identifier) with error: \(error)")
      throw error
    }
  }
}
