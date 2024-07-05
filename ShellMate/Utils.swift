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
