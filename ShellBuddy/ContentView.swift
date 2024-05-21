//
//  AppViewModel.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 15/05/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: AppViewModel

    init(viewModel: AppViewModel = AppViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack {
            Text("Your Personal Shell Buddy")
                .font(.title)
                .padding(.bottom, 20)

            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
                .padding(.bottom, 20)

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
        .padding()
    }

    private func copyToClipboard(command: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command, forType: .string)
        print("Copied to clipboard: \(command)")
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample view model with mock data
        let sampleViewModel = AppViewModel()
        sampleViewModel.chatgptResponses = [
            "1": "Sample text from window 1",
            "2": "Sample text from window 2"
        ]
        sampleViewModel.recommendedCommands = [
            "1": ["command_1", "command_2"],
            "2": ["command_3", "command_4"]
        ]

        // Use a custom ContentView initializer for preview
        return ContentView(viewModel: sampleViewModel)
    }
}
#endif
