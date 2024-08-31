//
//  UpdateShellProfileViewModel.swift
//  ShellMate
//
//  Created by Daniel Delattre on 28/08/24.
//

import Foundation

class UpdateShellProfileViewModel: ObservableObject {
  // Singleton Instance
  static let shared = UpdateShellProfileViewModel()

  @Published var shouldShowUpdateShellProfile: [String: Bool] = [:]
  @Published var fixSmCommandNotFoundSuggestionIndex: String?

  public let fixingCommand: String
  private var currentTerminalID: String?

  // Private initializer to enforce singleton pattern
  private init() {
    self.fixingCommand = "source " + getShellProfile()
  }

  func updateCurrentTerminalID(_ terminalID: String) {
    self.currentTerminalID = terminalID
  }

  func updateShouldShowUpdateShellProfile(value: Bool) {
    guard let terminalID = currentTerminalID else {
      print("Error: Terminal ID is not set.")
      return
    }
    shouldShowUpdateShellProfile[terminalID] = value
  }

  func shouldShowUpdateShellProfileBanner() -> Bool {
    guard let terminalID = currentTerminalID else {
      print("Error: Terminal ID is not set.")
      return false
    }
    return shouldShowUpdateShellProfile[terminalID] ?? false
  }
}
