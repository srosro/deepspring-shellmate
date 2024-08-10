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
                    .font(.subheadline)
            }
            .labelsHidden()
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
