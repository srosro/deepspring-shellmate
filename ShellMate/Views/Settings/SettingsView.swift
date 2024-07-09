//
//  SettingsView.swift
//  ShellMate
//
//  Created by daniel on 08/07/24.
//

import SwiftUI
import LaunchAtLogin

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralView()
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
    @State private var selectedWindowPosition = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Startup")
                    .frame(width: 150, alignment: .trailing)
                Toggle(isOn: .constant(true)) {
                    Text("Open ShellMate at login")
                }
                .labelsHidden()
            }
            HStack {
                Text("Window Position")
                    .frame(width: 150, alignment: .trailing)
                Picker(selection: $selectedWindowPosition, label: HStack {
                    switch selectedWindowPosition {
                    case 0:
                        Image(systemName: "arrow.right")
                        Text("Pin To The Right")
                    case 1:
                        Image(systemName: "arrow.left")
                        Text("Pin To The Left")
                    case 2:
                        Image(systemName: "arrow.up.and.down")
                        Text("Float")
                    default:
                        Text("")
                    }
                }) {
                    HStack {
                        Image(systemName: "square.righthalf.fill")
                        Text("Pin To The Right")
                    }.tag(0)
                    HStack {
                        Image(systemName: "square.lefthalf.fill")
                        Text("Pin To The Left")
                    }.tag(1)
                    HStack {
                        Image(systemName: "square.fill")
                        Text("Float")
                    }.tag(2)
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .padding(.trailing, 60)
            }
            HStack {
                Text("OpenAI API Key")
                    .frame(width: 150, alignment: .trailing)
                TextField("Enter OpenAI API Key", text: .constant(""))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, 60)
            }
            Spacer()
        }
        .padding()
    }
}


struct GeneralView2: View {
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

struct AboutView: View {
    @ObservedObject private var viewModel = AboutViewModel()
    
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
                    Text("Version \(viewModel.appVersion)")
                        .font(.subheadline)
                        .padding(.bottom, 8)
                        .opacity(0.8)
                    HStack {
                        Button(action: {
                            // Do something
                        }) {
                            Text("Send Feedback")
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(AppColors.black)
                                .foregroundColor(.white)
                                .cornerRadius(3)
                                .font(.subheadline)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    
                    
                        Button(action: {
                            //Do something
                        }) {
                            Text("Visit Website")
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(AppColors.black)
                                .foregroundColor(.white)
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
