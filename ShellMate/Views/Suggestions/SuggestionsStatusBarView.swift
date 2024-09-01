//
//  SuggestionsStatusBarView.swift
//  ShellMate
//
//  Created by Daniel Delattre on 01/09/24.
//

import SwiftUI

struct SuggestionsStatusBarView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isSamAltmanIconFaceRotating = false

    var body: some View {
        ZStack(alignment: .center) {
            HStack {
                if let currentTerminalID = viewModel.currentTerminalID,
                   viewModel.pauseSuggestionGeneration[currentTerminalID] != true
                {
                    Text(viewModel.currentStateText)
                        .font(.footnote)
                        .foregroundColor(
                            viewModel.currentStateText == "Detecting changes..."
                            ? Color.Text.green : Color.Text.gray
                        )
                        .padding(.leading)
                }
                Spacer()
                HStack(spacing: 8) {
                    if let currentTerminalID = viewModel.currentTerminalID {
                        if viewModel.isGeneratingSuggestion[currentTerminalID] == true {
                            Text("Generating suggestion...")
                                .font(.footnote)
                                .foregroundColor(Color.Text.green)
                        } else if viewModel.pauseSuggestionGeneration[currentTerminalID] == true {
                            Text("ShellMate paused")
                                .font(.footnote)
                                .foregroundColor(Color.Text.gray)
                        }

                        Button(action: {
                            // Toggle the pause state
                            viewModel.setPauseSuggestionGeneration(
                                for: currentTerminalID,
                                to: !viewModel.pauseSuggestionGeneration[currentTerminalID, default: false])
                        }) {
                            Image(
                                systemName: viewModel.pauseSuggestionGeneration[currentTerminalID] == true
                                ? "play.circle.fill" : "pause.circle.fill"
                            )
                            .font(.system(size: 16))  // Adjust the size as needed
                            .foregroundColor(Color.Text.secondary)
                        }
                        .buttonStyle(PlayPauseButtonStyle())
                    }
                }
                .padding(.trailing, 16)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .center)

            if let currentTerminalID = viewModel.currentTerminalID,
               viewModel.isGeneratingSuggestion[currentTerminalID] == true
            {
                if viewModel.shouldShowSamAltmansFace {
                    Image("samAltmansFace")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 29)
                        .rotationEffect(.degrees(isSamAltmanIconFaceRotating ? 360 : 0))
                        .onAppear {
                            withAnimation(
                                Animation.linear(duration: 0.5)
                                    .delay(0.8)
                                    .repeatForever(autoreverses: false)
                            ) {
                                isSamAltmanIconFaceRotating = true
                            }
                        }
                        .onDisappear {
                            isSamAltmanIconFaceRotating = false  // Stop the rotation when the view disappears
                        }
                        .padding(.vertical, 0)
                        .offset(y: -1)
                }
            }
        }
    }
}
