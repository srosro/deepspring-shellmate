//
//  AppViewModel.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 15/05/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: AppViewModel
    @State private var selectedTab: Tab = .suggestions

    init(viewModel: AppViewModel = AppViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    enum Tab {
        case suggestions, history
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SuggestionsView(viewModel: viewModel)
                .tabItem {
                    Label("Suggestions", systemImage: "lightbulb")
                }
                .tag(Tab.suggestions)
                .onAppear {
                    viewModel.isPaused = false
                }

            HistoryView(viewModel: viewModel)
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(Tab.history)
                .onAppear {
                    viewModel.isPaused = true
                }
        }
    }
}

struct SuggestionsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack {
            Text("Your Personal Shell Buddy")
                .font(.title)
                .padding(.top, 5)
                .padding(.bottom, 5)

            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
                .padding(.bottom, 10)

            ScrollView {
                if viewModel.chatgptResponses.isEmpty {
                    Text("No text recognized yet")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                } else {
                    ForEach(viewModel.chatgptResponses.keys.sorted(), id: \.self) { key in
                        VStack(alignment: .leading) {
                            Text("Window [\(key)]:")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(viewModel.chatgptResponses[key] ?? "No text")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 10)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                                .padding(.bottom, 5)
                                .textSelection(.enabled) // Enable text selection

                            if let commands = viewModel.recommendedCommands[key] {
                                ForEach(commands.indices, id: \.self) { index in
                                    let command = commands[index]
                                    let shortcutCharacter = Character("\(index + 1)")
                                    let shortcut = KeyboardShortcut(KeyEquivalent(shortcutCharacter), modifiers: .command)
                                    
                                    Button(action: {
                                        copyToClipboard(command: command)
                                    }) {
                                        HStack {
                                            Text("Cmd+\(index + 1)") // Display the shortcut key
                                                .font(.headline)
                                                .foregroundColor(.yellow)
                                                .padding(.trailing, 10)
                                            Text(command)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                    }
                                    .keyboardShortcut(shortcut) // Assign the shortcut
                                    .padding(.bottom, 5)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .padding()
    }

    private func copyToClipboard(command: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command, forType: .string)
        print("Copied to clipboard: \(command)")
    }
}

struct HistoryView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack {
            Text("History")
                .font(.title)
                .padding(.top, 20)

            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    VStack {
                        ForEach(viewModel.getRecentLogs(), id: \.identifier) { log in
                            VStack(alignment: .leading) {
                                Text("Window [\(log.identifier)]:")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if let ocrResult = log.ocrResult {
                                    Text(ocrResult)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.bottom, 10)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(8)
                                        .padding(.bottom, 5)
                                        .textSelection(.enabled)
                                }

                                if let commands = log.recommendedCommands {
                                    ForEach(commands.indices, id: \.self) { index in
                                        let command = commands[index]

                                        Button(action: {
                                            copyToClipboard(command: command)
                                        }) {
                                            HStack {
                                                Text("Copy")
                                                    .font(.headline)
                                                    .foregroundColor(.yellow)
                                                    .padding(.trailing, 10)
                                                Text(command)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .padding()
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                        }
                                        .padding(.bottom, 5)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .id(log.identifier) // Set the ID for scrolling
                        }
                    }
                    .onAppear {
                        if let lastLog = viewModel.getRecentLogs().last {
                            scrollViewProxy.scrollTo(lastLog.identifier, anchor: .bottom)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func copyToClipboard(command: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command, forType: .string)
        print("Copied to clipboard: \(command)")
    }
}
