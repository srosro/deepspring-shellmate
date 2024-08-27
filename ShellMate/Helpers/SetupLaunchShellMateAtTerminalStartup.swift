//
//  SetupLaunchShellMateAtTerminalStartup.swift
//  ShellMate
//
//  Created by Daniel Delattre on 14/08/24.
//

import Foundation

class SetupLaunchShellMateAtTerminalStartup {
  private let shellmateLine: String

  init(shellmateLine: String) {
    self.shellmateLine = shellmateLine
  }

  private func getShellProfile() -> String {
    if let shell = ProcessInfo.processInfo.environment["SHELL"] {
      if shell.contains("zsh") {
        return "\(NSHomeDirectory())/.zshrc"
      } else if shell.contains("bash") {
        return "\(NSHomeDirectory())/.bashrc"
      } else {
        return "\(NSHomeDirectory())/.zshrc"
      }
    } else {
      return "\(NSHomeDirectory())/.zshrc"
    }
  }

  func install(completion: @escaping (Bool) -> Void) {
    DispatchQueue.global().async {
      let shellProfile = self.getShellProfile()
      do {
        let fileContent = try String(contentsOfFile: shellProfile, encoding: .utf8)

        if fileContent.contains(self.shellmateLine) {
          print("ShellMate line already exists in \(shellProfile).")
          DispatchQueue.main.async {
            completion(true)
          }
        } else {
          print("Adding ShellMate line to \(shellProfile)...")
          try fileContent.appending("\(self.shellmateLine)\n").write(
            toFile: shellProfile, atomically: true, encoding: .utf8)
          print("ShellMate line added successfully.")
          DispatchQueue.main.async {
            completion(true)
          }
        }
      } catch {
        print("Error reading or writing to \(shellProfile): \(error.localizedDescription)")
        DispatchQueue.main.async {
          completion(false)
        }
      }
    }
  }

  func uninstall(completion: @escaping (Bool) -> Void) {
    DispatchQueue.global().async {
      let shellProfile = self.getShellProfile()
      do {
        var fileContent = try String(contentsOfFile: shellProfile, encoding: .utf8)

        if fileContent.contains(self.shellmateLine) {
          print("Removing ShellMate line from \(shellProfile)...")
          fileContent = fileContent.replacingOccurrences(of: "\(self.shellmateLine)\n", with: "")
          try fileContent.write(toFile: shellProfile, atomically: true, encoding: .utf8)
          print("ShellMate line removed successfully.")
          DispatchQueue.main.async {
            completion(true)
          }
        } else {
          print("ShellMate line not found in \(shellProfile).")
          DispatchQueue.main.async {
            completion(true)
          }
        }
      } catch {
        print("Error reading or writing to \(shellProfile): \(error.localizedDescription)")
        DispatchQueue.main.async {
          completion(false)
        }
      }
    }
  }
}

class CompanionModeManager: ObservableObject {
  static let shared = CompanionModeManager()
  var shouldInstallOnlyOnContinue: Bool = true
  private var initialSetup: Bool = true

  @Published var isCompanionModeEnabled: Bool = true {
    didSet {
      if initialSetup {
        return
      }

      if shouldInstallOnlyOnContinue {
        return
      }

      performCompanionModeActions()  // Perform the common actions
    }
  }


  let appName: String
  private let shellMateSetup: SetupLaunchShellMateAtTerminalStartup

  private init() {
    self.appName =
      Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "ShellMate"
    self.shellMateSetup = SetupLaunchShellMateAtTerminalStartup(
      shellmateLine: "open -a \(self.appName)")

    if UserDefaults.standard.object(forKey: "isCompanionModeEnabled") == nil {
      // First time the app is launched, set to true by default and wait for continue to be hit to install
      DispatchQueue.main.async {
        self.isCompanionModeEnabled = true
      }
    } else {
      // Initialize the isCompanionModeEnabled from UserDefaults
      self.isCompanionModeEnabled = UserDefaults.standard.bool(forKey: "isCompanionModeEnabled")
    }
    initialSetup = false
  }
  
  private func installShellMateAtTerminalStartup() {
    shellMateSetup.install { success in
      if !success {
        DispatchQueue.main.async {
          self.isCompanionModeEnabled = false  // Revert to the previous state
          print("Failed to install \(self.appName).")
        }
      }
    }
  }

  private func uninstallShellMateAtTerminalStartup() {
    shellMateSetup.uninstall { success in
      if !success {
        DispatchQueue.main.async {
          self.isCompanionModeEnabled = true  // Revert to the previous state
          print("Failed to uninstall \(self.appName).")
        }
      }
    }
  }
  
  func handleContinueAction() {
    if shouldInstallOnlyOnContinue {
      performCompanionModeActions()  // Perform the common actions
      enableInstantChange()
    } else {
    }
  }

  private func performCompanionModeActions() {
    UserDefaults.standard.set(isCompanionModeEnabled, forKey: "isCompanionModeEnabled")

    if isCompanionModeEnabled {
      installShellMateAtTerminalStartup()
      MixpanelHelper.shared.trackEvent(name: "autoOpenWithTerminalEnabled")
    } else {
      uninstallShellMateAtTerminalStartup()
      MixpanelHelper.shared.trackEvent(name: "autoOpenWithTerminalDisabled")
    }
  }

  func enableInstantChange() {
    shouldInstallOnlyOnContinue = false
  }
}
