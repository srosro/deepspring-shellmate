//
//  ContentView.swift
//  ShellMate
//
//  Created by Daniel Delattre on 20/06/24.
//

import SwiftUI

struct TroubleshootShellMateView: View {
  @State private var apiKey: String = ""

  var body: some View {
    Button(action: {
    }) {
      // this here is a dummy button just to make the style work
      VStack(alignment: .leading, spacing: 8) {
        Text("Troubleshoot ShellMate")
          .font(.body)
          .fontWeight(.semibold)
          .allowsHitTesting(false)  // Disable interaction for this text

        Text(
          "We're experiencing issues with your current API Key. Please check the key or add a new one to continue. If you believe this is an error, please send us feedback."
        )
        .font(.body)
        .fontWeight(.regular)
        .multilineTextAlignment(.leading)
        .allowsHitTesting(false)  // Disable interaction for this text
        .lineLimit(4)  // Allow text to wrap into multiple lines
        .fixedSize(horizontal: false, vertical: true)

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
          .strokeBorder(
            LinearGradient(
              gradient: Gradient(colors: [AppColors.gradientLightBlue, AppColors.gradientPurple]),
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ), lineWidth: 2)
      )
    }
    .buttonStyle(PlainButtonStyle())  // Ensure no button styling
  }
}

struct ActivateShellMateView: View {
  @State private var apiKey: String = ""
  @State private var showSubscriptionMessage: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if showSubscriptionMessage {
        Text("Thanks for being willing to support us!")
          .font(.body)
          .fontWeight(.semibold)
          .allowsHitTesting(false)  // Disable interaction for this text

        Text(
          "We haven’t implemented this yet. But we’ve given you more free credits on our OpenAI account"
        )
        .font(.body)
        .fontWeight(.regular)
        .multilineTextAlignment(.leading)
        .allowsHitTesting(false)  // Disable interaction for this text
        .lineLimit(5)  // Allow text to wrap into multiple lines
        .fixedSize(horizontal: false, vertical: true)

        Button(action: acceptFreeCredits) {
          Text("Accept 2,000 free credits")
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Color.Text.green)
            .foregroundColor(Color.Text.oppositePrimary)
            .cornerRadius(4)
            .font(.subheadline)
        }
        .buttonStyle(BorderlessButtonStyle())  // Ensure no default button styling

      } else {
        Text("Activate ShellMate")
          .font(.body)
          .fontWeight(.semibold)
          .allowsHitTesting(false)  // Disable interaction for this text

        Text(
          "You've run out of free AI responses. Subscribe for credits or add your own OpenAI API key to continue using ShellMate."
        )
        .font(.body)
        .fontWeight(.regular)
        .multilineTextAlignment(.leading)
        .allowsHitTesting(false)  // Disable interaction for this text
        .lineLimit(5)  // Allow text to wrap into multiple lines
        .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: 8) {  // Use HStack to align buttons side by side
          Button(action: handleSubscriptionClick) {
            Text("Subscribe for $2.99/month")
              .padding(.horizontal, 11)
              .padding(.vertical, 7)
              .background(Color.black)
              .foregroundColor(.white)
              .cornerRadius(4)
              .font(.subheadline)
          }
          .buttonStyle(BorderlessButtonStyle())  // Ensure no default button styling

          SettingsLink {
            Text("Add OpenAI API key")
              .padding(.horizontal, 11)
              .padding(.vertical, 7)
              .background(Color.clear)
              .foregroundColor(.primary)
              .cornerRadius(4)
              .font(.subheadline)
              .overlay(
                RoundedRectangle(cornerRadius: 4)
                  .stroke(Color.primary, lineWidth: 0.5)
              )
          }
          .buttonStyle(BorderlessButtonStyle())  // Ensure no default button styling
        }
      }
    }
    .padding(.horizontal, 16)  // Inner padding for the VStack inside the border
    .padding(.vertical, 12)  // Inner padding for the VStack inside the border
    .frame(maxWidth: .infinity, alignment: .leading)  // Make VStack take full width
    .background(
      RoundedRectangle(cornerRadius: 8)
        .strokeBorder(
          LinearGradient(
            gradient: Gradient(colors: [AppColors.gradientLightBlue, AppColors.gradientPurple]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ), lineWidth: 2)
    )
    .buttonStyle(PlainButtonStyle())  // Ensure no button styling
  }

  // Function to handle the subscription button click
  private func handleSubscriptionClick() {
    // Simulate the action and show the message
    showSubscriptionMessage = true
    MixpanelHelper.shared.trackEvent(name: "clickedSubscribeButton")
  }

  // Function to handle the acceptance of 2000 free credits
  private func acceptFreeCredits() {
    print("2000 free credits accepted")

    // Post the notification
    NotificationCenter.default.post(name: .userAcceptedFreeCredits, object: nil)
    MixpanelHelper.shared.trackEvent(name: "receivedFreeAPICredits")
  }
}

struct NetworkIssueView: View {
  @State private var apiKey: String = ""

  var body: some View {
    Button(action: {
    }) {
      // this here is a dummy button just to make the style work
      VStack(alignment: .leading, spacing: 8) {
        Text("Network Error")
          .font(.body)
          .fontWeight(.semibold)
          .allowsHitTesting(false)  // Disable interaction for this text

        Text(
          "Please check your internet connection. If you believe this is an error, feel free to send us feedback."
        )
        .font(.body)
        .fontWeight(.regular)
        .multilineTextAlignment(.leading)
        .allowsHitTesting(false)  // Disable interaction for this text
      }
      .padding(.horizontal, 16)  // Inner padding for the VStack inside the border
      .padding(.vertical, 12)  // Inner padding for the VStack inside the border
      .frame(maxWidth: .infinity, alignment: .leading)  // Make VStack take full width
      .background(
        RoundedRectangle(cornerRadius: 8)
          .strokeBorder(
            LinearGradient(
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
    if let terminalID = viewModel.currentTerminalID,
      viewModel.shouldShowSuggestionsView[terminalID] ?? false
    {
      SuggestionsView(viewModel: viewModel)
    } else {
      EmptyStateView(viewModel: viewModel)
    }
  }
}

struct SuggestionsView: View {
  @ObservedObject var viewModel: AppViewModel
  @ObservedObject private var stateManager = OnboardingStateManager.shared
  @State private var isRotating = false
  @State private var scrollToKey: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ScrollViewReader { scrollView in
        ScrollView {
          VStack(alignment: .leading) {
            if let currentTerminalID = viewModel.currentTerminalID,
              let windowData = viewModel.results[currentTerminalID]
            {

              ForEach(windowData.suggestionsHistory.indices, id: \.self) { batchIndex in
                let batch = windowData.suggestionsHistory[batchIndex].1
                if let proTipIdx = batch.first?["proTipIdx"],
                  batch.first?["isProTipBanner"] == "true"
                {
                  if let step = Int(proTipIdx) {
                    OnboardingView(currentStep: step, batchIndex: batchIndex + 1)  // +1 as it starts from 0. but we show to user starting from 1
                      .id("protip-\(batchIndex)")
                  }
                } else {
                  SuggestionBatchView(
                    batch: batch,
                    batchIndex: batchIndex,
                    isLastBatch: batchIndex == windowData.suggestionsHistory.count - 1,
                    viewModel: viewModel
                  )
                  .id(generateSuggestionViewElementID(batchIndex: batchIndex))
                }
              }
            }
          }
          .padding(.horizontal, 10)
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 15)
        .onChange(of: viewModel.updateCounter) {
          if let currentTerminalID = viewModel.currentTerminalID,
            let windowData = viewModel.results[currentTerminalID],
            let lastBatch = windowData.suggestionsHistory.last?.1,
            let lastSuggestionIndex = lastBatch.indices.last
          {

            // Check if the last batch is a pro tip and scroll to it
            if lastBatch.first?["isProTipBanner"] == "true" {
              scrollView.scrollTo("protip-\(windowData.suggestionsHistory.count - 1)", anchor: .top)
            } else {
              scrollToBottom(
                scrollView: scrollView,
                key: "suggestion-\(windowData.suggestionsHistory.count - 1)-\(lastSuggestionIndex)")
            }
          }
        }
        .onChange(of: scrollToKey) {
          if let key = scrollToKey {
            withAnimation {
              scrollView.scrollTo(key, anchor: .top)
            }
          }
        }

        if viewModel.hasGPTSuggestionsFreeTierCountReachedLimit
          && viewModel.hasUserValidatedOwnOpenAIAPIKey == .usingFreeTier
        {
          ActivateShellMateView()
            .padding(10)
        } else if viewModel.shouldShowNetworkIssueWarning {
          NetworkIssueView()
            .padding(10)
        } else if viewModel.shouldTroubleShootAPIKey
          || viewModel.hasUserValidatedOwnOpenAIAPIKey == .invalid
        {
          TroubleshootShellMateView()
            .padding(10)
        }

        BannersView(scrollToFixingCommand: scrollToFixingCommand, scrollView: scrollView)
      }
      SuggestionsStatusBarView(viewModel: viewModel)
    }
  }

  private func scrollToBottom(scrollView: ScrollViewProxy, key: String) {
    withAnimation {
      scrollView.scrollTo(key, anchor: .top)
    }
  }

  private func copyToClipboard(command: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(command, forType: .string)
    print("Copied to clipboard: \(command)")
  }

  func scrollToFixingCommand(scrollView: ScrollViewProxy, key: String) {
    withAnimation {
      scrollView.scrollTo(key, anchor: .top)
    }
  }
}

struct SuggestionBatchView: View {
  var batch: [[String: String]]
  var batchIndex: Int
  var isLastBatch: Bool
  var viewModel: AppViewModel

  var body: some View {
    if let firstResponse = batch.first {
      VStack(alignment: .leading) {
        Text(firstResponse["gptResponse"] ?? "No response")
          .font(.system(.subheadline, design: .default))
          .fontWeight(.semibold)
          .padding()
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.black)
          .foregroundColor(Color.Other.lightGray)
          .cornerRadius(8)
      }
    }

    ForEach(batch.indices, id: \.self) { index in
      let resultDict = batch[index]
      let isLastSuggestionInBatch = index == batch.count - 1

      SuggestionView(resultDict: resultDict, batchIndex: batchIndex, index: index)
        .padding(.bottom, isLastSuggestionInBatch ? 35 : 0)
        .id(generateSuggestionViewElementID(batchIndex: batchIndex, suggestionIndex: index))
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
          .foregroundColor(Color.Text.primary)
      } else {
        Text("sm \(batchIndex + 1)")
          .font(.system(.footnote, design: .monospaced))
          .fontWeight(.regular)
          .foregroundColor(Color.Text.primary)
        Text(".\(index + 1)")
          .font(.system(.footnote, design: .monospaced))
          .fontWeight(.regular)
          .foregroundColor(index == 0 ? Color.Text.secondary : Color.Text.primary)
      }
    }
    .padding(6)
    .background(buttonText == "copied" ? Color.BG.Cells.tertiaryFocused : Color.BG.Cells.tertiary)
    .background(Color.BG.Cells.tertiary)
    .cornerRadius(4)
  }
}

struct SuggestionView: View {
  var resultDict: [String: String]
  var batchIndex: Int
  var index: Int

  @State private var isHovered: Bool = false
  @State private var borderColor: Color = Color.Stroke.Cells.secondary
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
          .background(isHovered ? Color.BG.Cells.secondaryFocused : Color.BG.Cells.secondary)
          .foregroundColor(Color.Text.primary)
          .cornerRadius(8)
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(borderColor, lineWidth: borderWidth)
          )
          .padding(1)  // Ensure padding is uniform around the button to avoid thicker bottom border
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
          .foregroundColor(Color.Text.gray)
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
    MixpanelHelper.shared.trackEvent(name: "commandCopiedToClipboard")
  }

  private func provideFeedback() {
    withAnimation(Animation.easeInOut(duration: 0.02)) {
      borderColor = Color.Stroke.Cells.secondaryClicked
      borderWidth = 2
      buttonText = "copied"
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      withAnimation {
        borderColor = Color.Stroke.Cells.secondary
        borderWidth = 1
        buttonText = "sm \(batchIndex + 1).\(index + 1)"
      }
    }
  }
}

struct PlayPauseButtonStyle: ButtonStyle {
  @State private var isHovered: Bool = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(4)
      .background(isHovered ? Color.BG.Cells.secondaryFocused : Color.clear)
      .cornerRadius(4)
      .foregroundColor(Color.Text.secondary)  // Ensures icon color remains consistent
      .onHover { hovering in
        withAnimation(.easeInOut(duration: 0.2)) {
          isHovered = hovering
        }
      }
  }
}
