//
//  HistoryView.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 22/05/24.
//

import SwiftUI

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

                                if let ocrResult = log.gptResponse {
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
