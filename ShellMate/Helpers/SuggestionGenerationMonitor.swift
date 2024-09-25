//
//  SuggestionGenerationMonitor.swift
//  ShellMate
//
//  Created by daniel on 11/09/24.
//

import Foundation

class SuggestionGenerationMonitor: ObservableObject {
  static let shared = SuggestionGenerationMonitor()

  @Published private(set) var isGeneratingSuggestion: [String: [UUID: Bool]] = [:]

  private init() {}

  func setIsGeneratingSuggestion(for terminalID: String, stateID: UUID, to isGenerating: Bool) {
    DispatchQueue.main.async {
      if self.isGeneratingSuggestion[terminalID] == nil {
        self.isGeneratingSuggestion[terminalID] = [:]
      }

      if isGenerating {
        self.isGeneratingSuggestion[terminalID]?[stateID] = true
      } else {
        self.isGeneratingSuggestion[terminalID]?.removeValue(forKey: stateID)
      }
    }
  }

  func isCurrentlyGeneratingSuggestion(for terminalID: String) -> Bool {
    return isGeneratingSuggestion[terminalID]?.values.contains(true) ?? false
  }

  func resetAll() {
    DispatchQueue.main.async {
      self.isGeneratingSuggestion.removeAll()
    }
  }
}
