//
//  App.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 26/06/24.
//

import SwiftUI


@main
struct ShellBuddyApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) var appDelegate
    @StateObject private var viewModel = AppViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var showSettingsView = UserDefaults.standard.bool(forKey: "showSettingsView")

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
                .onDisappear {
                    if settingsViewModel.isAppTrusted && settingsViewModel.isTerminalTrusted {
                        appDelegate.initializeApp()
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
    }
}
