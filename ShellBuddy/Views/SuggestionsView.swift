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

            ScrollViewReader { scrollView in
                ScrollView {
                    VStack {
                        if viewModel.results.isEmpty {
                            Text("No text recognized yet")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        } else {
                            ForEach(Array(viewModel.results.keys.sorted()), id: \.self) { key in
                                VStack(alignment: .leading) {
                                    Text("Window [\(key)]:")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    ForEach(viewModel.results[key] ?? [], id: \.self) { resultDict in
                                        Text(resultDict["gpt response"] ?? "No response")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.bottom, 10)
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(8)
                                            .padding(.bottom, 5)
                                            .textSelection(.enabled)

                                        if let command = resultDict["suggested command"] {
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
                                .id(key) // Assign ID for each section
                            }
                        }
                    }
                    .onChange(of: viewModel.results) {
                        scrollToBottom(scrollView: scrollView, keys: Array(viewModel.results.keys))
                    }
                }
            }
        }
        .padding()
    }

    private func scrollToBottom(scrollView: ScrollViewProxy, keys: [String]) {
        if let lastKey = keys.sorted().last {
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
