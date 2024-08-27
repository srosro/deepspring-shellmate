//
//  App.swift
//  ShellMate
//
//  Created by Daniel Delattre on 26/06/24.
//

import Sparkle
import SwiftUI

@main
struct ShellMateApp: App {
  @NSApplicationDelegateAdaptor(ApplicationDelegate.self) var appDelegate
  @StateObject private var viewModel = AppViewModel()
  @StateObject private var permissionsViewModel = PermissionsViewModel()
  @StateObject private var licenseViewModel = LicenseViewModel.shared
  @StateObject private var generalViewModel = GeneralViewModel()
  @State private var showPermissionsView = UserDefaults.standard.bool(forKey: "showPermissionsView")

  private let updaterController: SPUStandardUpdaterController

  init() {
    updaterController = SPUStandardUpdaterController(
      startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
  }

  var body: some Scene {
    WindowGroup {
      if showPermissionsView {
        PermissionsWindowView(
          appViewModel: viewModel, permissionsViewModel: permissionsViewModel,
          licenseViewModel: licenseViewModel,
          onContinue: {
            showPermissionsView = false
            UserDefaults.standard.set(false, forKey: "showPermissionsView")
          }
        )
        .frame(minWidth: 350)
        .onAppear {
          NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
          ) { _ in
            showPermissionsView = UserDefaults.standard.bool(forKey: "showPermissionsView")
          }
        }
      } else {
        ContentView(viewModel: viewModel)
          .frame(minWidth: 350)
          .onAppear {
            NotificationCenter.default.addObserver(
              forName: UserDefaults.didChangeNotification, object: nil, queue: .main
            ) { _ in
              showPermissionsView = UserDefaults.standard.bool(forKey: "showPermissionsView")
            }
          }
      }
    }
    .commands {
      CommandGroup(after: .appInfo) {
        CheckForUpdatesView(updater: updaterController.updater)
      }
      CommandGroup(after: .appSettings) {
        Button("Send Feedback") {
          sendFeedbackEmail()
        }
        .keyboardShortcut("F", modifiers: .command)
      }
    }

    Settings {
      SettingsView(
        appViewModel: viewModel, licenseViewModel: licenseViewModel,
        generalViewModel: generalViewModel
      )
      .onAppear {
        MixpanelHelper.shared.trackEvent(name: "settingsViewOpened")
      }
    }
  }
}
