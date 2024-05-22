//
//  SuggestionsView.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 22/05/24.
//

import SwiftUI

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

