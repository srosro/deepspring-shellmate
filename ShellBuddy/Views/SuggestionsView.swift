import SwiftUI

struct SuggestionsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { // Set spacing to 0 to remove margin
            ScrollViewReader { scrollView in
                ScrollView {
                    VStack(alignment: .leading) {
                        if let currentTerminalID = viewModel.currentTerminalID, let windowData = viewModel.filteredResults[currentTerminalID] {
                            ForEach(windowData.suggestionsHistory.indices, id: \.self) { batchIndex in
                                SuggestionBatchView(batch: windowData.suggestionsHistory[batchIndex], batchIndex: batchIndex, isLastBatch: batchIndex == windowData.suggestionsHistory.count - 1)
                            }
                        }
                    }
                    .padding(.horizontal, 10) // Add padding to the left and right of the content
                }
                .padding(.horizontal, 0) // Ensure no padding affects the scroll bar
                .padding(.top, 15) // Ensure no padding affects the scroll bar
                .onChange(of: viewModel.updateCounter) { _ in
                    if let currentTerminalID = viewModel.currentTerminalID, let windowData = viewModel.filteredResults[currentTerminalID], let lastBatch = windowData.suggestionsHistory.last, let lastSuggestionIndex = lastBatch.indices.last {
                        // Scroll to the last suggestion in the last batch
                        scrollToBottom(scrollView: scrollView, key: "suggestion-\(windowData.suggestionsHistory.count - 1)-\(lastSuggestionIndex)")
                    }
                }
            }
            
            // Line separator with no vertical padding
            Divider().padding(.top, 5)
            
            // "Detecting Changes" text at the bottom-left
            HStack {
                Text(viewModel.currentStateText)
                    .font(.footnote)
                    .foregroundColor(viewModel.currentStateText == "Detecting changes..." ? AppColors.green : AppColors.gray700.opacity(0.9))
                    .padding(.leading)
                Spacer()
            }
            .padding(.vertical, 10) // Keep margin between the text and the divider
            .frame(maxWidth: .infinity, alignment: .center) // Center the text horizontally
        }
        //.padding(.bottom, 20) // Add bottom padding to ensure there is space below the text
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

struct SuggestionBatchView: View {
    var batch: [[String: String]]
    var batchIndex: Int
    var isLastBatch: Bool

    var body: some View {
        if let firstResponse = batch.first {
            VStack(alignment: .leading) {
                Text("> \(firstResponse["gptResponse"] ?? "No response")")
                    .font(.system(.subheadline, design: .monospaced))  // Set the font to monospaced
                    .fontWeight(.regular)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.black)
                    .foregroundColor(AppColors.white)
                    .cornerRadius(8)
            }

            ForEach(batch.indices, id: \.self) { index in
                let resultDict = batch[index]
                let isLastSuggestionInBatch = index == batch.count - 1
                
                SuggestionView(resultDict: resultDict, batchIndex: batchIndex, index: index)
                    .padding(.bottom, isLastSuggestionInBatch ? 35 : 0) // Decrease the padding between suggestions
                    .id("suggestion-\(batchIndex)-\(index)") // Assign unique ID for each suggestion
            }
        }
    }
}

struct SbButtonIdxView: View {
    var batchIndex: Int
    var index: Int
    
    var body: some View {
        HStack(spacing: 0) {
            Text("sb \(batchIndex + 1)")
                .font(.footnote)
                .fontWeight(.regular)
                .foregroundColor(AppColors.black)
            Text(".\(index + 1)")
                .font(.footnote)
                .fontWeight(.regular)
                .foregroundColor(AppColors.black)
                .opacity(index == 0 ? 0.4 : 1.0)
        }
        .padding(.horizontal, 8)
        .background(AppColors.gray600.opacity(0.05))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(AppColors.gray600.opacity(0.05), lineWidth: 1)
        )
    }
}

struct SuggestionView: View {
    var resultDict: [String: String]
    var batchIndex: Int
    var index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let command = resultDict["suggestedCommand"] {
                Button(action: {
                    copyToClipboard(command: command)
                }) {
                    HStack {
                        Text(command)
                            .font(.system(.subheadline, design: .monospaced))  // Set the font to monospaced
                            .fontWeight(.regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        SbButtonIdxView(batchIndex: batchIndex, index: index) // Use the new component
                    }
                    .padding(10)
                    .background(AppColors.white)  // Highlight the first suggestion of the last batch
                    .foregroundColor(AppColors.black)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.gray600.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle()) // Avoid default button styling
                //.padding(.bottom, 2)
            }

            // Show command explanation below each command
            if let explanation = resultDict["commandExplanation"] {
                Text(explanation)
                    .font(.footnote)
                    .fontWeight(.regular)
                    .foregroundColor(AppColors.gray600)
                    .padding(.horizontal, 10)
                    .padding(.top, 2) // Decrease padding below explanations
            }
        }
        .background(Color.clear) // Ensure no extra background is added
        .cornerRadius(8)
    }

    private func copyToClipboard(command: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command, forType: .string)
        print("Copied to clipboard: \(command)")
    }
}
