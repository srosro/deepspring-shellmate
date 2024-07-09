//
//  SettingsViewModel.swift
//  ShellMate
//
//  Created by daniel on 08/07/24.
//

import Foundation

class AboutViewModel: ObservableObject {
    @Published var appVersion: String = ""
    @Published var appBuild: String = ""
    
    init() {
        do {
            appVersion = try getAppVersion()
            appBuild = try getAppBuild()
        } catch {
            appVersion = "Version info not available"
            appBuild = "Build info not available"
        }
    }
}
