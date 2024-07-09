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
    @StateObject private var viewModel = GeneralViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Startup")
                    .frame(width: 150, alignment: .trailing)
                LaunchAtLogin.Toggle {
                    Text("Open ShellMate at login")
                        .font(.subheadline)
                }
                .labelsHidden()
            }
            HStack {
                Text("Window Position")
                    .frame(width: 150, alignment: .trailing)
                Picker(selection: $viewModel.windowAttachmentPosition, label: HStack {
                    switch viewModel.windowAttachmentPosition {
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
                .onChange(of: viewModel.windowAttachmentPosition) { _ in
                    viewModel.updateWindowAttachmentPosition(source: "config")
                }
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
