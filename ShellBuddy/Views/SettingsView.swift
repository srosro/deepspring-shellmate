//
//  Settings.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 26/06/24.
//

import SwiftUI



struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var apiKey = "samplekey" // Default text value
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .center) {
            WelcomeView()

            PermissionsView(viewModel: viewModel)
            
            LicenseView(apiKey: $apiKey)

            ContinueButtonView(viewModel: viewModel, onContinue: onContinue)
        }
        .padding()
        //.frame(width: 400, height: 600)
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
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Permissions")
                .font(.subheadline)
                .bold()
                .padding(.bottom, 5)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("ShellMate - Accessibility")
                            .font(.subheadline)
                            .bold()
                        Text("Allows you to talk to shellbuddy directly from your terminal.")
                            .font(.footnote)
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
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(AppColors.black)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .font(.subheadline)
                        }
                        .background(Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()

                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Terminal - Accessibility")
                            .font(.subheadline)
                            .bold()
                        Text("Allows terminal to paste shellbuddy suggestions directly into your terminal.")
                            .font(.footnote)
                    }
                    Spacer()
                    if viewModel.isTerminalTrusted {
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
                            viewModel.openAccessibilityPreferences()
                        }) {
                            Text("Grant Access")
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(AppColors.black)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .font(.subheadline)
                        }
                        .background(Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
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
        .padding(.bottom)
        .frame(maxWidth: .infinity)
    }
}

struct LicenseView: View {
    @Binding var apiKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("License")
                .font(.subheadline)
                .bold() // Ensure the text is bold
                .padding(.bottom, 5)

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
            }
            .padding()
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.gray400, lineWidth: 0.4) // Consistent line width
            )
        }
        .padding(.bottom)
        .frame(maxWidth: .infinity)
    }
}


struct ContinueButtonView: View {
    @ObservedObject var viewModel: SettingsViewModel
    let onContinue: () -> Void

    var body: some View {
        Button(action: {
            viewModel.initializeApp()
            onContinue()
        }) {
            Text("Continue")
                .padding(.horizontal, 40)
                .padding(.vertical, 8)
                .background(viewModel.isAppTrusted && viewModel.isTerminalTrusted ? AppColors.black : AppColors.gray400)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .disabled(!(viewModel.isAppTrusted && viewModel.isTerminalTrusted))
        .background(Color.clear) // Ensure background color is clear to avoid white corners
        .clipShape(RoundedRectangle(cornerRadius: 8)) // Clip the shape to remove background outside corners
    }
}

