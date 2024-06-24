//
//  ContentView.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 20/06/24.
//

import SwiftUI

struct AppColors {
    static let black = Color(red: 0.00, green: 0.00, blue: 0.00)
    static let gray200 = Color(red: 0.91, green: 0.91, blue: 0.92)
    static let gray400 = Color(red: 0.61, green: 0.64, blue: 0.69)
    static let gray500 = Color(red: 0.42, green: 0.45, blue: 0.49)
    static let gray600 = Color(red: 0.29, green: 0.33, blue: 0.39)
    static let gray700 = Color(red: 0.22, green: 0.25, blue: 0.32)
    static let gray900 = Color(red: 0.07, green: 0.09, blue: 0.15)
    static let green = Color(red: 0.02, green: 0.59, blue: 0.41)
    static let white = Color(red: 1.00, green: 1.00, blue: 1.00)
    static let lightGray = Color(red: 0.85, green: 0.85, blue: 0.85)
    static let veryLightGray = Color(red: 0.92, green: 0.92, blue: 0.92)
    static let extraLightGray = Color(red: 0.98, green: 0.98, blue: 0.98)
}

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
                        if let currentTerminalID = viewModel.currentTerminalID, let windowData = viewModel.filteredResults[currentTerminalID] {
                            ForEach(windowData.suggestionsHistory.indices, id: \.self) { batchIndex in
                                SuggestionBatchView(batch: windowData.suggestionsHistory[batchIndex], batchIndex: batchIndex, isLastBatch: batchIndex == windowData.suggestionsHistory.count - 1)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .padding(.horizontal, 0)
                .padding(.top, 15)
                .onChange(of: viewModel.updateCounter) { _ in
                    if let currentTerminalID = viewModel.currentTerminalID, let windowData = viewModel.filteredResults[currentTerminalID], let lastBatch = windowData.suggestionsHistory.last, let lastSuggestionIndex = lastBatch.indices.last {
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

