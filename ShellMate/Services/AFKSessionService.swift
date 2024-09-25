//
//  AFKSessionService.swift
//  ShellMate
//
//  Created by Daniel Delattre on 24/09/24.
//

import Foundation

class AFKSessionService {
  static let shared = AFKSessionService()

  var currentTerminalID: String? {
    didSet {
      if let terminalID = currentTerminalID {
        if afkPausedTerminals[terminalID] != true,
          !PauseSuggestionManager.shared.isSuggestionGenerationPaused(for: terminalID)
        {
          scheduleAFKTask(for: terminalID)
        }
      }
    }
  }

  private var afkPauseTask: DispatchWorkItem?
  private var afkPausedTerminals: [String: Bool] = [:]
  private let afkTimeInterval: TimeInterval = 4 * 60  // 4 minutes in seconds

  private init() {
    // Private initialization to ensure just one instance is created.
  }

  func scheduleAFKTask(for terminalID: String) {
    // Cancel any existing task
    afkPauseTask?.cancel()

    // Create a new DispatchWorkItem
    afkPauseTask = DispatchWorkItem { [weak self] in
      guard let self = self else { return }

      // Check if the current terminal ID matches the one passed as argument
      guard self.currentTerminalID == terminalID else {
        return
      }

      // Check if the terminal is not already paused
      if !PauseSuggestionManager.shared.isSuggestionGenerationPaused(for: terminalID) {
        // Pause the terminal and set the AFK flag
        PauseSuggestionManager.shared.setPauseSuggestionGeneration(for: terminalID, to: true)
        self.afkPausedTerminals[terminalID] = true
      }
    }

    // Schedule the task to run after 4 minutes
    DispatchQueue.main.asyncAfter(deadline: .now() + afkTimeInterval, execute: afkPauseTask!)
  }

  func handleKeyPress(for terminalID: String) {
    // Check if the terminal is paused due to AFK
    if afkPausedTerminals[terminalID] == true {
      // Unpause the terminal and remove the AFK flag
      PauseSuggestionManager.shared.setPauseSuggestionGeneration(for: terminalID, to: false)
      afkPausedTerminals[terminalID] = false
    }

    // Reschedule the AFK task
    scheduleAFKTask(for: terminalID)
  }

  func resetAFKPausedTerminal(for terminalID: String) {
    if afkPausedTerminals[terminalID] == true {
      afkPausedTerminals[terminalID] = false
    }
  }
}

class PauseSuggestionManager: ObservableObject {
  static let shared = PauseSuggestionManager()

  @Published private var pauseSuggestionGeneration: [String: Bool] = [:]

  private init() {
    // Private initialization to ensure just one instance is created.
  }

  func setPauseSuggestionGeneration(for terminalID: String, to pause: Bool) {
    DispatchQueue.main.async {
      self.pauseSuggestionGeneration[terminalID] = pause
    }
  }

  func isSuggestionGenerationPaused(for terminalID: String) -> Bool {
    return pauseSuggestionGeneration[terminalID] ?? false
  }

  func checkAndInitializePauseFlag(for terminalID: String) {
    if pauseSuggestionGeneration[terminalID] == nil {
      pauseSuggestionGeneration[terminalID] = false
    }
  }
}
