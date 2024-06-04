//
//  Utils.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 04/06/24.
//

import Foundation

/// Retrieve the API key from environment variables
func retrieveOpenaiAPIKey() -> String {
    guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
        fatalError("API key not found in environment variables")
    }
    return apiKey
}
