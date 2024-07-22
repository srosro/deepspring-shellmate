//
//  Permissions.swift
//  ShellMate
//
//  Created by Daniel Delattre on 26/06/24.
//

import SwiftUI
import Sentry

struct PermissionsWindowView: View {
    @ObservedObject var appViewModel: AppViewModel
    @ObservedObject var permissionsViewModel: PermissionsViewModel
    @ObservedObject var licenseViewModel: LicenseViewModel

    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Spacer()
            WelcomeView()
            Spacer()
            PermissionsView(permissionsViewModel: permissionsViewModel)
            Spacer()
            LicenseView(licenseViewModel: licenseViewModel, appViewModel: appViewModel)
            Spacer()
            ContinueButtonView(permissionsViewModel: permissionsViewModel, licenseViewModel: licenseViewModel, appViewModel: appViewModel, onContinue: onContinue)
            Spacer()
        }
        .padding()
    }
}

struct WelcomeView: View {
    var body: some View {
        VStack {
            Text("Welcome to ShellMate")
                .font(.title)
                .bold()
                .padding(.bottom, 2)
            Text("We need a couple of things before we can get started.")
                .font(.subheadline)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, alignment: .center) // Center align the header text
    }
}

struct PermissionsView: View {
    @ObservedObject var permissionsViewModel: PermissionsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Permissions")
                .font(.subheadline)
                .bold()
                .padding(.leading, 15)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Accessibility")
                            .font(.subheadline)
                            .bold()
                        Text("Allows you to talk to shellmate directly from your terminal.")
                            .font(.caption)
                    }
                    Spacer()
                    if permissionsViewModel.isAppTrusted {
                        HStack {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color.Text.green)
                                .font(.subheadline)
                            Text("Granted")
                                .foregroundColor(Color.Text.green)
                                .font(.subheadline)
                        }
                    } else {
                        Button(action: {
                            permissionsViewModel.requestAccessibilityPermissions()
                        }) {
                            Text("Grant Access")
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(Color.black)
                                .foregroundColor(Color.white)
                                .cornerRadius(3)
                                .font(.footnote)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .padding()
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.gray400, lineWidth: 0.4)
            )
        }
        .frame(maxWidth: .infinity)
    }
}

struct LicenseView: View {
    @ObservedObject var licenseViewModel: LicenseViewModel
    @ObservedObject var appViewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if appViewModel.hasGPTSuggestionsFreeTierCountReachedLimit {
                Text("License")
                    .font(.subheadline)
                    .bold() // Ensure the text is bold
                    .padding(.leading, 15)
                
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("OpenAI API Key")
                            .font(.subheadline)
                            .bold()
                        Text("Add your Secret API key from OpenAI. How do I get an API key?")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 10) // Adding some padding at the bottom of the text

                    TextField("Enter OpenAI API Key", text: $licenseViewModel.apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    // Conditionally show the feedback message if the API key is invalid
                    if licenseViewModel.apiKeyValidationState == .invalid {
                        Text("API Key is invalid")
                            .foregroundColor(.red)
                            .font(.footnote)
                            .padding(.top, 5)
                    } else if licenseViewModel.apiKeyValidationState == .unverified {
                        Text("\(appViewModel.GPTSuggestionsFreeTierCount)/\(appViewModel.GPTSuggestionsFreeTierLimit) complimentary AI responses used")
                            .font(.footnote)
                            .foregroundColor(Color.Text.gray)
                            .padding(.top, 5)
                    }
                }
                .padding()
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppColors.gray400, lineWidth: 0.4) // Consistent line width
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
}


struct ContinueButtonView: View {
    @ObservedObject var permissionsViewModel: PermissionsViewModel
    @ObservedObject var licenseViewModel: LicenseViewModel
    @ObservedObject var appViewModel: AppViewModel

    let onContinue: () -> Void

    var body: some View {
        Button(action: {
            permissionsViewModel.initializeApp()
        }) {
            Text("Continue")
                .padding(.horizontal, 40)
                .padding(.vertical, 8)
                .background(buttonBackgroundColor)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .disabled(!isButtonEnabled)
        .background(Color.clear) // Ensure background color is clear to avoid white corners
        .clipShape(RoundedRectangle(cornerRadius: 8)) // Clip the shape to remove background outside corners
        .buttonStyle(BorderlessButtonStyle())
    }
    
    private var isButtonEnabled: Bool {
        if !appViewModel.hasGPTSuggestionsFreeTierCountReachedLimit {
            return permissionsViewModel.isAppTrusted
        } else {
            return permissionsViewModel.isAppTrusted && licenseViewModel.apiKeyValidationState == .valid
        }
    }
    
    private var buttonBackgroundColor: Color {
        if isButtonEnabled {
            return Color.black
        } else {
            return AppColors.gray400
        }
    }
}
