//
//  SuggestionGenerationMonitor.swift
//  ShellMate
//
//  Created by daniel on 11/09/24.
//

import Foundation

class SuggestionGenerationMonitor: ObservableObject {
  static let shared = SuggestionGenerationMonitor()

  @Published private(set) var isGeneratingSuggestion: [String: Bool] = [:]

  private init() {}

  func setIsGeneratingSuggestion(for terminalID: String, to isGenerating: Bool) {
    DispatchQueue.main.async {
      self.isGeneratingSuggestion[terminalID] = isGenerating
    }
  }

  func isCurrentlyGeneratingSuggestion(for terminalID: String) -> Bool {
    return isGeneratingSuggestion[terminalID] ?? false
  }

  func resetAll() {
    DispatchQueue.main.async {
      self.isGeneratingSuggestion.removeAll()
    }
  }
}
