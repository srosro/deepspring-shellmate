//
//  Utils.swift
//  ShellMate
//
//  Created by Daniel Delattre on 04/06/24.
//

import Foundation
import ApplicationServices
import SQLite3
import Mixpanel
import AppKit
import CoreGraphics

/// Retrieve the API key from UserDefaults
func retrieveOpenaiAPIKey() -> String {
    guard let apiKey = UserDefaults.standard.string(forKey: "apiKey"), !apiKey.isEmpty else {
        fatalError("API key not found in UserDefaults or is empty")
    }
    return apiKey
}
    
func showPermissionsView() {
    UserDefaults.standard.set(true, forKey: "showPermissionsView")
}

func showContentView() {
    UserDefaults.standard.set(false, forKey: "showPermissionsView")
}


class AccessibilityChecker {
    private static var initialTrustStatus: Bool? = nil

    static func isAppTrusted() -> Bool {
        let currentStatus = AXIsProcessTrusted()
        
        // Check if the initial status has been set
        if let initialStatus = initialTrustStatus {
            // If the status has changed, fire an event
            if initialStatus != currentStatus {
                MixpanelHelper.shared.trackEvent(name: "permissionsGrantedChange", properties: [
                    "isAccessibilityGranted": currentStatus
                ])
                // Update the initial status to the current status
                initialTrustStatus = currentStatus
            }
        } else {
            // Set the initial status for the first time
            initialTrustStatus = currentStatus
        }
        
        return currentStatus
    }
}


class MixpanelHelper {
    static let shared = MixpanelHelper()
    
    private init() {
        // Initialize Mixpanel with your project token
        Mixpanel.initialize(token: "37cba6e38af4542dd68c2c20d812c9c3")
    }
    
    func trackEvent(name: String, properties: [String: MixpanelType]? = nil) {
        Mixpanel.mainInstance().track(event: name, properties: properties)
    }
}

func trackFirstLaunchAfterInstall() {
    let userDefaults = UserDefaults.standard
    let hasLaunchedKey = "hasLaunchedBefore"
    
    if !userDefaults.bool(forKey: hasLaunchedKey) {
        // This is the first launch
        MixpanelHelper.shared.trackEvent(name: "firstLaunchAfterInstall")
        // Set the flag to true
        userDefaults.set(true, forKey: hasLaunchedKey)
        userDefaults.synchronize()
    }
}


enum AppInfoError: Error {
    case missingVersion
    case missingBuild
}

func getAppVersionAndBuild() throws -> String {
    guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
        throw AppInfoError.missingVersion
    }
    
    guard let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
        throw AppInfoError.missingBuild
    }
    
    return "Version\(version)Build\(build)"
}


func setClipboardContent(text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

func sendKeyPress(keyCode: CGKeyCode, modifiers: CGEventFlags) {
    let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
    keyDown?.flags = modifiers
    keyDown?.post(tap: .cghidEventTap)

    let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
    keyUp?.flags = modifiers
    keyUp?.post(tap: .cghidEventTap)
}

func pasteClipboardContent() {
    let commandKey: CGEventFlags = .maskCommand
    sendKeyPress(keyCode: 9, modifiers: commandKey) // Assuming 'v' key has a key code of 9
}

// Function to get the complete path to shellMateCommandSuggestions.json
func getShellMateCommandSuggestionsFilePath() -> URL {
    let sharedTempDirectory = getSharedTemporaryDirectory()
    let filePath = sharedTempDirectory.appendingPathComponent("shellMateCommandSuggestions.json")
    return filePath
}

// Helper function to get the shared temporary directory
func getSharedTemporaryDirectory() -> URL {
    let tempDirectoryURL = FileManager.default.temporaryDirectory
    return tempDirectoryURL
}

// Function to load a command from JSON file
func loadCommandFromJSON(filePath: URL, key: String) -> String? {
    do {
        let data = try Data(contentsOf: filePath)
        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
            return json[key]
        }
    } catch {
        print("Error loading or parsing JSON: \(error)")
    }
    return nil
}


func obfuscateAuthTokens(in text: String) -> String {
    let pattern = "(?i)(token|key|auth|bearer)[\\s_-]([\\S]{16})"
    let regex = try? NSRegularExpression(pattern: pattern)
    
    let obfuscatedText = regex?.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count), withTemplate: "$1 ****************") ?? text
    
    return obfuscatedText
}

// Test function
func testObfuscateAuthTokens() {
    let testCases = [
        ("token 1234567890abcdef", "token ****************"),
        ("key_1234abcd5678efgh", "key ****************"),
        ("auth-1234567890abcd12", "auth ****************"),
        ("bearer 1234567890abcd12", "bearer ****************"),
        ("TOKEN 1234567890ABCD12", "TOKEN ****************"),
        ("KEY_1234abcd5678EFGH", "KEY ****************"),
        ("AUTH-1234567890ABCD12", "AUTH ****************"),
        ("BEARER 1234567890abcd12", "BEARER ****************"),
        ("token 1234abcd5678efgh", "token ****************"),
        ("key_!@#$%^&*()_+{}[]", "key ****************"),
        ("auth-<>,.?/;'\":123456", "auth ****************"),
        ("bearer_+=-~`|{}[]123456", "bearer ****************")
    ]
    
    for (input, expected) in testCases {
        let result = obfuscateAuthTokens(in: input)
        //print("\"\(input)\" -> \"\(result)\"")
        assert(result == expected, "Test failed for input: \"\(input)\". \nExpected: \"\(expected)\", but got: \"\(result)\"")
    }
    //print("All tests passed.")
}

