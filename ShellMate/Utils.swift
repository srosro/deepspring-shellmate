//
//  Utils.swift
//  ShellMate
//
//  Created by Daniel Delattre on 04/06/24.
//

import Foundation
import ApplicationServices
import SQLite3

/// Retrieve the API key from environment variables
func retrieveOpenaiAPIKey() -> String {
    //guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
    //    fatalError("API key not found in environment variables")
    //}
    let apiKey = "sk-proj-QJTEXwwbbp2LhwahZ2F3T3BlbkFJeLNulBYi20omTgB7wk3l";
    return apiKey
}
    
func showSettingsView() {
    UserDefaults.standard.set(true, forKey: "showSettingsView")
}

func showContentView() {
    UserDefaults.standard.set(false, forKey: "showSettingsView")
}

class AccessibilityChecker {
    static func isAppTrusted() -> Bool {
        return AXIsProcessTrusted()
    }
}
