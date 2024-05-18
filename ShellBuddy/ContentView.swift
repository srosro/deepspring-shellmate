//
//  ContentView.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 15/05/24.
//


import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel() // Initialize the ViewModel

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
                            ForEach(commands, id: \.self) { command in
                                Button(action: {
                                    copyToClipboard(command: command)
                                }) {
                                    Text(command)
                                        .frame(maxWidth: .infinity, alignment: .leading)
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
        ContentView()
    }
}
#endif

