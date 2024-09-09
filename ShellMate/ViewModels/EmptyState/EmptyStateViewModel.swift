//
//  EmptyStateViewModel.swift
//  ShellMate
//
//  Created by Daniel Delattre on 31/08/24.
//

import Foundation

class EmptyStateViewModel {
  static let shared = EmptyStateViewModel()
  private var emptyStateMessages: [String: [String: String]] = [:]

  let emptyStateData: [[String: String]]

  private init() {
    self.emptyStateData = EmptyStateMessages.messages
  }

  func initializeEmptyStateMessage(for terminalWindowID: String) {
    if emptyStateMessages[terminalWindowID] == nil {
      emptyStateMessages[terminalWindowID] = getRandomMessage()
    }
  }

  func getRandomMessage() -> [String: String]? {
    return emptyStateData.randomElement()
  }

  func getEmptyStateMessage(for terminalWindowID: String) -> [String: String]? {
    return emptyStateMessages[terminalWindowID]
  }
}
