//
//  SettingsView.swift
//  ShellMate
//
//  Created by daniel on 08/07/24.
//

import SwiftUI
import LaunchAtLogin

struct SettingsView: View {
    @ObservedObject var appViewModel: AppViewModel
    @ObservedObject var licenseViewModel: LicenseViewModel
    @ObservedObject var generalViewModel: GeneralViewModel
    
    var body: some View {
        TabView {
            GeneralView(appViewModel: appViewModel, licenseViewModel: licenseViewModel, generalViewModel: generalViewModel)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 550, height: 265) // Adjust the frame size as needed
    }
}

struct GeneralView: View {
    @ObservedObject var appViewModel: AppViewModel
    @ObservedObject var licenseViewModel: LicenseViewModel
    @ObservedObject var generalViewModel: GeneralViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer().frame(height: 10)
            StartupView()
            TerminalLaunchView()
            WindowPositionView(generalViewModel: generalViewModel)
            ApiKeyView(appViewModel: appViewModel, licenseViewModel: licenseViewModel)
            Spacer()
        }
        .padding()
    }
}

struct StartupView: View {
    var body: some View {
        HStack {
            Text("Startup")
                .frame(width: 150, alignment: .trailing)
            LaunchAtLogin.Toggle {
                Text("Open ShellMate at login")
                    .font(.body)
            }
        }
    }
}

struct TerminalLaunchView: View {
    @AppStorage("launchShellMateAtTerminalStartup") private var launchAtTerminalStartup = false
    @State private var isProcessing = false

    // Dynamically retrieve the app name
    private let appName: String
    private let shellMateSetup: SetupLaunchShellMateAtTerminalStartup

    init() {
        self.appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "ShellMate"
        self.shellMateSetup = SetupLaunchShellMateAtTerminalStartup(shellmateLine: "open -a \(self.appName)")
    }

    var body: some View {
        HStack {
            Text("Terminal Integration")
                .frame(width: 150, alignment: .trailing)
            Toggle(isOn: $launchAtTerminalStartup) {
                Text("Run \(appName) with terminal launch")
                    .font(.body)
            }
            .toggleStyle(CheckboxToggleStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(isProcessing)  // Disable the toggle while processing
            .onChange(of: launchAtTerminalStartup) { oldValue, newValue in
                if newValue {
                    installShellMateAtTerminalStartup()
                    MixpanelHelper.shared.trackEvent(name: "autoOpenWithTerminalEnabled")
                } else {
                    uninstallShellMateAtTerminalStartup()
                    MixpanelHelper.shared.trackEvent(name: "autoOpenWithTerminalDisabled")
                }
            }
        }
    }

    // Functions for installing/uninstalling ShellMate at terminal launch
    private func installShellMateAtTerminalStartup() {
        isProcessing = true
        DispatchQueue.global().async {
            do {
                try self.shellMateSetup.install()
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.launchAtTerminalStartup = false // Revert to the previous state
                    print("Failed to install \(self.appName): \(error.localizedDescription)")
                }
            }
        }
    }

    private func uninstallShellMateAtTerminalStartup() {
        isProcessing = true
        DispatchQueue.global().async {
            do {
                try self.shellMateSetup.uninstall()
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.launchAtTerminalStartup = true // Revert to the previous state
                    print("Failed to uninstall \(self.appName): \(error.localizedDescription)")
                }
            }
        }
    }
}


struct WindowPositionView: View {
    @ObservedObject var generalViewModel: GeneralViewModel
    
    var body: some View {
        HStack {
            Text("Window Position")
                .frame(width: 150, alignment: .trailing)
            Picker(selection: $generalViewModel.windowAttachmentPosition, label: HStack {
                switch generalViewModel.windowAttachmentPosition {
                case .right:
                    Image(systemName: "arrow.right")
                    Text("Pin To The Right")
                case .left:
                    Image(systemName: "arrow.left")
                    Text("Pin To The Left")
                case .float:
                    Image(systemName: "arrow.up.and.down")
                    Text("Float")
                }
            }) {
                HStack {
                    Image(systemName: "square.righthalf.fill")
                    Text("Pin To The Right")
                }.tag(WindowAttachmentPosition.right)
                HStack {
                    Image(systemName: "square.lefthalf.fill")
                    Text("Pin To The Left")
                }.tag(WindowAttachmentPosition.left)
                HStack {
                    Image(systemName: "square.fill")
                    Text("Float")
                }.tag(WindowAttachmentPosition.float)
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .padding(.trailing, 60)
            .onChange(of: generalViewModel.windowAttachmentPosition) {
                generalViewModel.updateWindowAttachmentPosition(source: "config")
            }
        }
    }
}

struct ApiKeyView: View {
    @ObservedObject var appViewModel: AppViewModel
    @ObservedObject var licenseViewModel: LicenseViewModel

    var body: some View {
        VStack {
            HStack {
                Text("OpenAI API Key")
                    .frame(width: 150, alignment: .trailing)
                TextField("Enter OpenAI API Key", text: $licenseViewModel.apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, 60)
            }
            // Conditionally show the feedback message if the API key is invalid or unverified
            if licenseViewModel.apiKeyValidationState == .invalid {
                HStack {
                    Text(" ")
                        .frame(width: 150, alignment: .trailing) // Adds the same width as "OpenAI API Key"
                    
                    if let errorMessage = licenseViewModel.apiKeyErrorMessage?.lowercased() {
                        if errorMessage.contains("the internet connection appears to be offline") {
                            Text("Your device is not connected to the internet")
                                .foregroundColor(.red)
                                .font(.footnote)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.trailing, 60)
                        } else if errorMessage.contains("the request timed out") || errorMessage.contains("the network connection was lost") {
                            Text("Looks like there's a network issue")
                                .foregroundColor(.red)
                                .font(.footnote)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.trailing, 60)
                        } else if errorMessage.contains("failed to list assistants or bad response") {
                            Text("It looks like the API Key is invalid")
                                .foregroundColor(.red)
                                .font(.footnote)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.trailing, 60)
                        } else {
                            Text("API Key is invalid")
                                .foregroundColor(.red)
                                .font(.footnote)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.trailing, 60)
                        }
                    }
                }
            } else if licenseViewModel.apiKeyValidationState == .unverified {
                HStack {
                    Text(" ")
                        .frame(width: 150, alignment: .trailing) // Adds the same width as "OpenAI API Key"
                    Text("\(appViewModel.GPTSuggestionsFreeTierCount)/\(appViewModel.GPTSuggestionsFreeTierLimit) complimentary AI responses used")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Text.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 60)
                        .bold()
                }
            }
            Spacer().frame(height: 1)
            HStack(alignment: .top) {
                Text(" ")
                    .frame(width: 150, alignment: .trailing) // Adds the same width as "OpenAI API Key"
                VStack(alignment: .leading, spacing: 0) {
                    Text("If you don't have an API key yet, you can sign up for one at")
                        .font(.footnote)
                        .foregroundColor(Color.Text.gray)
                    Link("OpenAI - API Keys", destination: URL(string: "https://platform.openai.com/api-keys")!)
                        .font(.footnote)
                        .underline()
                        .foregroundColor(Color.Text.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}



struct AboutView: View {
    @ObservedObject private var aboutViewModel = AboutViewModel()
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                if let appIcon = NSImage(named: "AppIcon") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 150, height: 150)
                }
                Spacer().frame(width: 20)  // Custom-sized spacer for horizontal spacing
                VStack(alignment: .leading) {
                    Text("ShellMate")
                        .font(.title)
                    Text("Version \(aboutViewModel.appVersion)")
                        .font(.subheadline)
                        .padding(.bottom, 8)
                        .opacity(0.8)
                    HStack {
                        Button(action: {
                            sendFeedbackEmail()
                        }) {
                            Text("Send Feedback")
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(Color.black)
                                .foregroundColor(Color.white)
                                .cornerRadius(3)
                                .font(.subheadline)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    
                    
                        Button(action: {
                            if let url = URL(string: "https://www.deepspring.ai/shellmate") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Text("Visit Website")
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(Color.black)
                                .foregroundColor(Color.white)
                                .cornerRadius(3)
                                .font(.subheadline)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                Spacer()
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
