//
//  Utils.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 04/06/24.
//

import Foundation
import ApplicationServices
import SQLite3

/// Retrieve the API key from environment variables
func retrieveOpenaiAPIKey() -> String {
    guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
        fatalError("API key not found in environment variables")
    }
    return apiKey
}


class AccessibilityChecker {
    static func isAppTrusted() -> Bool {
        return AXIsProcessTrusted()
    }

    static func isTerminalTrusted() -> Bool {
        let dbPath = "/Library/Application Support/com.apple.TCC/TCC.db"
        var db: OpaquePointer?

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Unable to open TCC database.")
            return false
        }

        defer {
            sqlite3_close(db)
        }

        let query = "SELECT auth_value FROM access WHERE service='kTCCServiceAccessibility' AND client='com.apple.Terminal'"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            print("Unable to prepare statement.")
            return false
        }

        defer {
            sqlite3_finalize(statement)
        }

        var isTrusted = false

        while sqlite3_step(statement) == SQLITE_ROW {
            let authValue = sqlite3_column_int(statement, 0)
            if authValue == 2 {
                isTrusted = true
                break
            }
        }

        if isTrusted {
            print("Terminal is trusted for accessibility.")
        } else {
            print("Terminal is not trusted for accessibility.")
        }

        return isTrusted
    }
}
