//
//  ContentView.swift
//  ShellMate
//
//  Created by Daniel Delattre on 20/06/24.
//

import SwiftUI



struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        SuggestionsView(viewModel: viewModel)
    }
}

struct SuggestionsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollViewReader { scrollView in
                ScrollView {
                    VStack(alignment: .leading) {
                        if let currentTerminalID = viewModel.currentTerminalID, let windowData = viewModel.results[currentTerminalID] {
                            ForEach(windowData.suggestionsHistory.indices, id: \.self) { batchIndex in
                                SuggestionBatchView(batch: windowData.suggestionsHistory[batchIndex].1, batchIndex: batchIndex, isLastBatch: batchIndex == windowData.suggestionsHistory.count - 1)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .padding(.horizontal, 0)
                .padding(.top, 15)
                .onChange(of: viewModel.updateCounter) {
                    if let currentTerminalID = viewModel.currentTerminalID, let windowData = viewModel.results[currentTerminalID], let lastBatch = windowData.suggestionsHistory.last?.1, let lastSuggestionIndex = lastBatch.indices.last {
                        scrollToBottom(scrollView: scrollView, key: "suggestion-\(windowData.suggestionsHistory.count - 1)-\(lastSuggestionIndex)")
                    }
                }
            }

            Divider().padding(.top, 5)

            HStack {
                Text(viewModel.currentStateText)
                    .font(.footnote)
                    .foregroundColor(viewModel.currentStateText == "Detecting changes..." ? AppColors.green : AppColors.gray700.opacity(0.9))
                    .padding(.leading)
                Spacer()
                if let currentTerminalID = viewModel.currentTerminalID, viewModel.isGeneratingSuggestion[currentTerminalID] == true {
                    Text("Generating suggestion...")
                        .font(.footnote)
                        .foregroundColor(AppColors.green)
                        .padding(.trailing)
                }
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .center)
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

struct SuggestionBatchView: View {
    var batch: [[String: String]]
    var batchIndex: Int
    var isLastBatch: Bool

    var body: some View {
        if let firstResponse = batch.first {
            VStack(alignment: .leading) {
                Text(firstResponse["gptResponse"] ?? "No response")
                    .font(.system(.subheadline, design: .default))
                    .fontWeight(.semibold)
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
                    .padding(.bottom, isLastSuggestionInBatch ? 35 : 0)
                    .id("suggestion-\(batchIndex)-\(index)")
            }
        }
    }
}

struct SbButtonIdxView: View {
    var batchIndex: Int
    var index: Int
    
    var body: some View {
        HStack(spacing: 0) {
            Text("sm \(batchIndex + 1)")
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
                        Text("> \(command)")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        SbButtonIdxView(batchIndex: batchIndex, index: index)
                    }
                    .padding(10)
                    .background(AppColors.white)
                    .foregroundColor(AppColors.black)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.gray600.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            if let explanation = resultDict["commandExplanation"] {
                Text(explanation)
                    .font(.footnote)
                    .fontWeight(.regular)
                    .foregroundColor(AppColors.gray600)
                    .padding(.horizontal, 10)
                    .padding(.top, 2)
            }
        }
        .background(Color.clear)
        .cornerRadius(8)
    }

    private func copyToClipboard(command: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command, forType: .string)
        print("Copied to clipboard: \(command)")
    }
}
