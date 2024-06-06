import SwiftUI

struct SuggestionsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack {
            ScrollViewReader { scrollView in
                ScrollView {
                    VStack {
                        if let currentTerminalID = viewModel.currentTerminalID, let windowData = viewModel.results[currentTerminalID] {
                            VStack(alignment: .leading) {
                                Text("Window [\(currentTerminalID)]:")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.bottom, 10)
                                
                                // Placeholder for the user command that generated the suggestions
                                Text("> Log Hello World")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                    .padding(.bottom, 10)

                                ForEach(windowData.gptResponses.indices, id: \.self) { index in
                                    let resultDict = windowData.gptResponses[index]
                                    VStack(alignment: .leading) {
                                        Text(resultDict["gptResponse"] ?? "No response")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding()
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(8)
                                            .padding(.bottom, 5)
                                            .textSelection(.enabled)

                                        if let command = resultDict["suggestedCommand"] {
                                            Button(action: {
                                                copyToClipboard(command: command)
                                            }) {
                                                HStack {
                                                    Text("Copy | sb \(index + 1)")
                                                        .font(.headline)
                                                        .foregroundColor(.yellow)
                                                        .padding(.trailing, 10)
                                                    Text(command)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                                .padding()
                                                .background(index == 0 ? Color.gray : Color.blue)  // Highlight the first suggestion
                                                .foregroundColor(.white)
                                                .cornerRadius(8)
                                            }
                                            .padding(.bottom, 5)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .id(currentTerminalID) // Assign ID for the current window
                        } else {
                            Text("No text recognized yet")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                    }
                    .onChange(of: viewModel.updateCounter, perform: { _ in
                        if let currentTerminalID = viewModel.currentTerminalID {
                            scrollToBottom(scrollView: scrollView, key: currentTerminalID)
                        }
                    })
                }
            }
            .padding()
            
            // Line separator
            Divider()
                .padding(.vertical, 10)
            
            // "Detecting Changes" text at the bottom-left
            HStack {
                Text(viewModel.currentStateText)
                    .font(.headline)
                    .foregroundColor(viewModel.currentStateText == "Detecting Changes" ? .red : .green)
                    .padding(.leading)
                Spacer()
            }
            .padding(.bottom)
        }
    }

    private func scrollToBottom(scrollView: ScrollViewProxy, key: String) {
        withAnimation {
            scrollView.scrollTo(key, anchor: .bottom)
        }
    }

    private func copyToClipboard(command: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command, forType: .string)
        print("Copied to clipboard: \(command)")
    }
}
