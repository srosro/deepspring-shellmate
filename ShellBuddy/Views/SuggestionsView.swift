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
            
            Text(viewModel.currentStateText)  // Display the current state text
                .font(.headline)
                .foregroundColor(viewModel.currentStateText == "Detecting Changes" ? .red : .green)
                .padding(.bottom, 10)

            ScrollViewReader { scrollView in
                ScrollView {
                    VStack {
                        if let currentTerminalID = viewModel.currentTerminalID, let windowData = viewModel.results[currentTerminalID] {
                            VStack(alignment: .leading) {
                                Text("Window [\(currentTerminalID)]:")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                ForEach(windowData.gptResponses.indices, id: \.self) { index in
                                    let resultDict = windowData.gptResponses[index]
                                    Text(resultDict["gptResponse"] ?? "No response")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.bottom, 10)
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
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                        }
                                        .padding(.bottom, 5)
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
        }
        .padding()
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
