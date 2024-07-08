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
    @StateObject private var permissionsViewModel = PermissionsViewModel()
    @State private var showPermissionsView = UserDefaults.standard.bool(forKey: "showPermissionsView")

    private let updaterController: SPUStandardUpdaterController
    
    init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }
    
    var body: some Scene {
        WindowGroup {
            if showPermissionsView {
                PermissionsWindowView(viewModel: permissionsViewModel, onContinue: {
                    showPermissionsView = false
                    UserDefaults.standard.set(false, forKey: "showPermissionsView")
                })
                .onAppear {
                    NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
                        showPermissionsView = UserDefaults.standard.bool(forKey: "showPermissionsView")
                    }
                }
            } else {
                ContentView(viewModel: viewModel)
                .onAppear {
                    NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
                        showPermissionsView = UserDefaults.standard.bool(forKey: "showPermissionsView")
                    }
                    appDelegate.initializeApp()
                }
            }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
            CommandGroup(replacing: .appSettings) {
                Button("Permissions") {
                    ShellMate.showPermissionsView()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
