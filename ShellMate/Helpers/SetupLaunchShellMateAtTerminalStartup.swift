//
//  SetupLaunchShellMateAtTerminalStartup.swift
//  ShellMate
//
//  Created by Daniel Delattre on 14/08/24.
//

import Foundation

class SetupLaunchShellMateAtTerminalStartup {
    // Property to hold the line to be added/removed
    private let shellmateLine: String
    
    // Initializer
    init(shellmateLine: String) {
        self.shellmateLine = shellmateLine
    }
    
    // Method to determine the user's shell profile
    private func getShellProfile() -> String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"] {
            if shell.contains("zsh") {
                return "\(NSHomeDirectory())/.zshrc"
            } else if shell.contains("bash") {
                return "\(NSHomeDirectory())/.bashrc"
            } else {
                // Default to zsh if shell cannot be determined
                return "\(NSHomeDirectory())/.zshrc"
            }
        } else {
            // Default to zsh if shell environment variable is not found
            return "\(NSHomeDirectory())/.zshrc"
        }
    }
    
    // Method to install the ShellMate line
    func install() throws {
        let shellProfile = getShellProfile()
        do {
            let fileContent = try String(contentsOfFile: shellProfile, encoding: .utf8)
            
            if fileContent.contains(shellmateLine) {
                print("ShellMate line already exists in \(shellProfile).")
            } else {
                print("Adding ShellMate line to \(shellProfile)...")
                try fileContent.appending("\n\(shellmateLine)\n").write(toFile: shellProfile, atomically: true, encoding: .utf8)
                print("ShellMate line added successfully.")
            }
        } catch {
            print("Error reading or writing to \(shellProfile): \(error.localizedDescription)")
            throw error // Propagate the error
        }
    }
    
    // Method to uninstall the ShellMate line
    func uninstall() throws {
        let shellProfile = getShellProfile()
        do {
            var fileContent = try String(contentsOfFile: shellProfile, encoding: .utf8)
            
            if fileContent.contains(shellmateLine) {
                print("Removing ShellMate line from \(shellProfile)...")
                fileContent = fileContent.replacingOccurrences(of: "\(shellmateLine)\n", with: "")
                try fileContent.write(toFile: shellProfile, atomically: true, encoding: .utf8)
                print("ShellMate line removed successfully.")
            } else {
                print("ShellMate line not found in \(shellProfile).")
            }
        } catch {
            print("Error reading or writing to \(shellProfile): \(error.localizedDescription)")
            throw error // Propagate the error
        }
    }
}
