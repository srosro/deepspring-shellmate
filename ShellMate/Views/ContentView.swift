//
//  ContentView.swift
//  ShellMate
//
//  Created by Daniel Delattre on 20/06/24.
//

import SwiftUI

struct ActivateShellMateView: View {
    @State private var apiKey: String = ""

    var body: some View {
        Button(action: {
        }) {
            // this here is a dummy button just to make the style work
            VStack(alignment: .leading, spacing: 8) {
                Text("Activate ShellMate")
                    .font(.body)
                    .fontWeight(.semibold)
                    .allowsHitTesting(false)  // Disable interaction for this text

                Text("You've run out of free AI responses. Add your own OpenAI API key to keep using.")
                    .font(.body)
                    .fontWeight(.regular)
                    .multilineTextAlignment(.leading)
                    .allowsHitTesting(false)  // Disable interaction for this text

                SettingsLink {
                    Text("Add API key")
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .font(.subheadline)
                }
                .buttonStyle(BorderlessButtonStyle())  // Ensure no default button styling
            }
            .padding(.horizontal, 16)  // Inner padding for the VStack inside the border
            .padding(.vertical, 12)  // Inner padding for the VStack inside the border
            .frame(maxWidth: .infinity, alignment: .leading)  // Make VStack take full width
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(LinearGradient(
                        gradient: Gradient(colors: [AppColors.gradientLightBlue, AppColors.gradientPurple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())  // Ensure no button styling
    }
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
            
            ActivateShellMateView()
                .padding(10)

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


struct SmButtonIdxView: View {
    var batchIndex: Int
    var index: Int
    @Binding var buttonText: String

    var body: some View {
        HStack(spacing: 0) {
            if buttonText == "copied" {
                Text(buttonText)
                    .font(.system(.footnote, design: .monospaced))
                    .fontWeight(.regular)
                    .foregroundColor(AppColors.black)
            } else {
                Text("sm \(batchIndex + 1)")
                    .font(.system(.footnote, design: .monospaced))
                    .fontWeight(.regular)
                    .foregroundColor(AppColors.black)
                Text(".\(index + 1)")
                    .font(.system(.footnote, design: .monospaced))
                    .fontWeight(.regular)
                    .foregroundColor(AppColors.black)
                    .opacity(index == 0 ? 0.4 : 1.0) // Updated opacity logic
            }
        }
        .padding(6)
        .background(buttonText == "copied" ? AppColors.smButtonBackground.opacity(0.15) : AppColors.smButtonBackground.opacity(0.05))
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

    @State private var isHovered: Bool = false
    @State private var borderColor: Color = AppColors.gray600.opacity(0.2)
    @State private var borderWidth: CGFloat = 1
    @State private var buttonText: String

    init(resultDict: [String: String], batchIndex: Int, index: Int) {
        self.resultDict = resultDict
        self.batchIndex = batchIndex
        self.index = index
        _buttonText = State(initialValue: "sm \(batchIndex + 1).\(index + 1)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let command = resultDict["suggestedCommand"] {
                Button(action: {
                    copyToClipboard(command: command)
                    provideFeedback()
                }) {
                    HStack {
                        Text("> \(command)")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        SmButtonIdxView(batchIndex: batchIndex, index: index, buttonText: $buttonText)
                    }
                    .padding(10)
                    .background(isHovered ? AppColors.gray600.opacity(0.05) : AppColors.white)
                    .foregroundColor(AppColors.black)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
                    .padding(1) // Ensure padding is uniform around the button to avoid thicker bottom border
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    isHovered = hovering
                }
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

    private func provideFeedback() {
        withAnimation(Animation.easeInOut(duration: 0.02)) {
            borderColor = AppColors.black
            borderWidth = 2
            buttonText = "copied"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                borderColor = AppColors.gray600.opacity(0.2)
                borderWidth = 1
                buttonText = "sm \(batchIndex + 1).\(index + 1)"
            }
        }
    }
}
