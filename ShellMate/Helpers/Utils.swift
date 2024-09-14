//
//  Utils.swift
//  ShellMate
//
//  Created by Daniel Delattre on 04/06/24.
//

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Mixpanel

/// Retrieve the API key from UserDefaults
func getHardcodedOpenAIAPIKey() -> String {
  return "sk-proj"
}

func retrieveOpenaiAPIKey() -> String {
  if let apiKey = UserDefaults.standard.string(forKey: "apiKey"), !apiKey.isEmpty {
    return apiKey
  } else {
    return getHardcodedOpenAIAPIKey()
  }
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
        MixpanelHelper.shared.trackEvent(
          name: "permissionsGrantedChange",
          properties: [
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

    // Create unique identifier that lasts across sessions
    let mixpanelUserId = getOrCreateMixpanelUserId()
    print("Calling Mixpanel identify with id: \(mixpanelUserId)")
    Mixpanel.mainInstance().identify(distinctId: mixpanelUserId)
  }

  func getOrCreateMixpanelUserId() -> String {
    if let mixpanelUserId = UserDefaults.standard.string(forKey: "MixpanelUserId") {
      return mixpanelUserId
    } else {
      let newMixpanelUserId = UUID().uuidString
      UserDefaults.standard.set(newMixpanelUserId, forKey: "MixpanelUserId")
      return newMixpanelUserId
    }
  }

  func trackEvent(name: String, properties: [String: MixpanelType]? = nil) {
    Mixpanel.mainInstance().track(event: name, properties: properties)
  }

  func setPeopleProperties(properties: [String: MixpanelType]) {
    Mixpanel.mainInstance().people.set(properties: properties)
  }

  func incrementPeopleProperty(name: String, by number: Double) {
    Mixpanel.mainInstance().people.increment(property: name, by: number)
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

func getAppVersion() throws -> String {
  guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
    throw AppInfoError.missingVersion
  }
  return version
}

func getAppBuild() throws -> String {
  guard let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
    throw AppInfoError.missingBuild
  }
  return build
}

func getAppVersionAndBuild() throws -> String {
  let version = try getAppVersion()
  let build = try getAppBuild()
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
  sendKeyPress(keyCode: 9, modifiers: commandKey)  // Assuming 'v' key has a key code of 9
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
  // List of common separators
  let separators = "[\\s_\\-:;=.,/|\\\\]"

  // Updated pattern with the common separators
  let pattern = "(?i)(token|key|auth|bearer)" + separators + "([\\S]{8,64})"
  let regex = try? NSRegularExpression(pattern: pattern)

  let obfuscatedText =
    regex?.stringByReplacingMatches(
      in: text, options: [], range: NSRange(location: 0, length: text.utf16.count),
      withTemplate: "$1 ****************") ?? text

  return obfuscatedText
}

// Test function
func testObfuscateAuthTokens() {
  let testCases = [
    ("token 1234567890abcdef", "token ****************"),
    (
      "key_1234abcd5678efghijklmnopqrstuvwxyz1234567890abcdef1234567890abcd", "key ****************"
    ),
    ("auth-123456{]`0abcd12", "auth ****************"),
    ("bearer 1234567890abcd12", "bearer ****************"),
    ("TOKEN:12345678-0ABCD12", "TOKEN ****************"),
    ("KEY=1234abcd5678EFGH", "KEY ****************"),
    ("AUTH.12345!@890ABCD12", "AUTH ****************"),
    ("BEARER,1234567890abcd12", "BEARER ****************"),
    ("token;1234abcd5678efgh", "token ****************"),
    ("key/1234567890abcdef", "key ****************"),
    ("auth\\1234567890abcd12", "auth ****************"),
    ("bearer|1234abcd5678efgh", "bearer ****************"),
  ]

  for (input, expected) in testCases {
    let result = obfuscateAuthTokens(in: input)
    assert(
      result == expected,
      "Test failed for input: \"\(input)\". \nExpected: \"\(expected)\", but got: \"\(result)\"")
  }
  //print("All tests passed.")
}

func checkInternetConnection() async -> Bool {
  let url = URL(string: "https://www.google.com")!  // Replace with a reliable URL
  var request = URLRequest(url: url)
  request.timeoutInterval = 10.0  // 10 seconds timeout

  do {
    let (_, response) = try await URLSession.shared.data(for: request)
    if let httpResponse = response as? HTTPURLResponse {
      print("DEBUG: HTTP status code: \(httpResponse.statusCode)")
      // Consider 200 and 429 status codes as having an internet connection
      return httpResponse.statusCode == 200 || httpResponse.statusCode == 429
    } else {
      print("DEBUG: No valid HTTP response received")
      return false
    }
  } catch {
    print("DEBUG: Error during internet connection check: \(error.localizedDescription)")
    return false
  }
}

extension URLSession {
  func dataWithTimeout(for request: URLRequest, timeout: TimeInterval = 10.0) async throws -> (
    Data, URLResponse
  ) {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = timeout
    configuration.timeoutIntervalForResource = timeout
    let session = URLSession(configuration: configuration)
    return try await session.data(for: request)
  }
}

func getShellProfile() -> String {
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

func generateSuggestionViewElementID(batchIndex: Int, suggestionIndex: Int? = nil) -> String {
  if let index = suggestionIndex {
    return "suggestion-\(batchIndex)-\(index)"
  } else {
    return "suggestion-\(batchIndex)"
  }
}
