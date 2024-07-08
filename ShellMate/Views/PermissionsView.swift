//
//  Permissions.swift
//  ShellMate
//
//  Created by Daniel Delattre on 26/06/24.
//

import SwiftUI
import LaunchAtLogin

struct PermissionsWindowView: View {
    @ObservedObject var viewModel: PermissionsViewModel
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Spacer()
            WelcomeView()
            Spacer()
            PermissionsView(viewModel: viewModel)
            Spacer()
            LicenseView(apiKey: $viewModel.apiKey, apiKeyValidationState: viewModel.apiKeyValidationState)
            Spacer()
            GeneralView(viewModel: viewModel)
            Spacer()
            ContinueButtonView(viewModel: viewModel, onContinue: onContinue)
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
    @ObservedObject var viewModel: PermissionsViewModel

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
                    if viewModel.isAppTrusted {
                        HStack {
                            Image(systemName: "checkmark")
                                .foregroundColor(AppColors.green)
                                .font(.subheadline)
                            Text("Granted")
                                .foregroundColor(AppColors.green)
                                .font(.subheadline)
                        }
                    } else {
                        Button(action: {
                            viewModel.requestAccessibilityPermissions()
                        }) {
                            Text("Grant Access")
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(AppColors.black)
                                .foregroundColor(.white)
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
    @Binding var apiKey: String
    var apiKeyValidationState: ApiKeyValidationState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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

                TextField("sk-...", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                // Conditionally show the feedback message if the API key is invalid
                if apiKeyValidationState == .invalid {
                    Text("API Key is invalid")
                        .foregroundColor(.red)
                        .font(.footnote)
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
        .frame(maxWidth: .infinity)
    }
}


struct GeneralView: View {
    @ObservedObject var viewModel: PermissionsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("General")
                .font(.subheadline)
                .bold()
                .padding(.leading, 15)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Login")
                            .font(.subheadline)
                            .bold()
                            .padding(.bottom, 5)
                        LaunchAtLogin.Toggle {
                            Text("Open ShellMate at login")
                                .font(.subheadline)
                        }
                    }
                    Spacer()
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


struct ContinueButtonView: View {
    @ObservedObject var viewModel: PermissionsViewModel
    let onContinue: () -> Void

    var body: some View {
        Button(action: {
            viewModel.initializeApp()
            onContinue()
        }) {
            Text("Continue")
                .padding(.horizontal, 40)
                .padding(.vertical, 8)
                .background(viewModel.isAppTrusted && viewModel.apiKeyValidationState == .valid ? AppColors.black : AppColors.gray400)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .disabled(!(viewModel.isAppTrusted && viewModel.apiKeyValidationState == .valid))
        .background(Color.clear) // Ensure background color is clear to avoid white corners
        .clipShape(RoundedRectangle(cornerRadius: 8)) // Clip the shape to remove background outside corners
        .buttonStyle(BorderlessButtonStyle())
    }
}
