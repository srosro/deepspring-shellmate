//
//  App.swift
//  ShellMate
//
//  Created by Daniel Delattre on 26/06/24.
//

import SwiftUI
import Sparkle


@main
struct ShellMateApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) var appDelegate
    @StateObject private var viewModel = AppViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var showSettingsView = UserDefaults.standard.bool(forKey: "showSettingsView")

    private let updaterController: SPUStandardUpdaterController
    
    init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }
    
    var body: some Scene {
        WindowGroup {
            if showSettingsView {
                SettingsView(viewModel: settingsViewModel, onContinue: {
                    showSettingsView = false
                })
                .onAppear {
                    NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
                        showSettingsView = UserDefaults.standard.bool(forKey: "showSettingsView")
                    }
                }
            } else {
                ContentView(viewModel: viewModel)
                .onAppear {
                    NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
                        showSettingsView = UserDefaults.standard.bool(forKey: "showSettingsView")
                    }
                    appDelegate.initializeApp()
                }
            }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
    }
}
