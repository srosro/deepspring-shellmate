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
                        if viewModel.results.isEmpty {
                            Text("No text recognized yet")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        } else {
                            ForEach(viewModel.sortedResults, id: \.self) { key in  // Use sorted results
                                VStack(alignment: .leading) {
                                    Text("Window [\(key)]:")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if let windowData = viewModel.results[key] {
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
                                }
                                .padding(.horizontal)
                                .id(key) // Assign ID for each section
                            }
                        }
                    }
                    .onChange(of: viewModel.updateCounter, perform: { _ in
                        scrollToBottom(scrollView: scrollView, keys: viewModel.sortedResults)
                    })
                }
            }
        }
        .padding()
    }

    private func scrollToBottom(scrollView: ScrollViewProxy, keys: [String]) {
        if let lastKey = keys.last {
            withAnimation {
                scrollView.scrollTo(lastKey, anchor: .bottom)
            }
        }
    }

    private func copyToClipboard(command: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command, forType: .string)
        print("Copied to clipboard: \(command)")
    }
}
