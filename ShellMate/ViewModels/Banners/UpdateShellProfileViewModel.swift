//
//  UpdateShellProfileViewModel.swift
//  ShellMate
//
//  Created by Daniel Delattre on 28/08/24.
//

import Foundation

class UpdateShellProfileViewModel: ObservableObject {
  @Published var shouldShowUpdateShellProfile: Bool = false
  @Published var fixSmCommandNotFoundSuggestionIndex: String?

  public let fixingCommand = "source " + getShellProfile()
  // Singleton Instance
  static let shared = UpdateShellProfileViewModel()

  // Private initializer to enforce singleton pattern
  private init() {}
}
