//
//  EmptyStateView.swift
//  ShellMate
//
//  Created by Daniel Delattre on 31/08/24.
//

import SwiftUI

struct TitleSubtitleView: View {
  var title: String
  var subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(Color.Text.EmptyState.gray)

      Text(subtitle)
        .font(.system(size: 12))
        .foregroundColor(Color.Text.EmptyState.gray)
    }
    .padding(.horizontal, 16)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct CommandView: View {
  var command: String

  var body: some View {
    HStack(spacing: 8) {
      Text(">")
        .font(.system(size: 12))
        .foregroundColor(Color.Text.EmptyState.gray)
        .italic()

      Text(command)
        .font(.system(size: 12, weight: .light, design: .monospaced))
        .italic()
        .background(Color.Stroke.Cells.secondary)
        .foregroundColor(Color.Text.EmptyState.gray)
        .textSelection(.enabled)
    }
    .padding(.horizontal, 16)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct TextView: View {
  var text: String

  @State private var textHeight: CGFloat = 0

  var body: some View {
    HStack(spacing: 8) {
      Rectangle()
        .frame(width: 1, height: textHeight)
        .foregroundColor(Color.Text.EmptyState.gray)

      Text(text)
        .font(.system(size: 12, weight: .light, design: .monospaced))
        .italic()
        .background(Color.Stroke.Cells.secondary)
        .foregroundColor(Color.Text.EmptyState.gray)
        .background(
          GeometryReader { geometry in
            Color.clear
              .onAppear {
                self.textHeight = geometry.size.height  // Set the initial height
              }
              .onChange(of: geometry.size.height) { oldHeight, newHeight in
                if oldHeight != newHeight {
                  self.textHeight = newHeight  // Update the height if it changes
                }
              }
          }
        )
    }
    .padding(.horizontal, 16)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct EmptyStateView: View {
  @ObservedObject var viewModel: AppViewModel

  var body: some View {
    let randomMessage =
      EmptyStateViewModel.shared.getEmptyStateMessage(for: viewModel.currentTerminalID ?? "") ?? [:]

    VStack(spacing: 0) {
      Spacer()
      VStack(alignment: .leading, spacing: 5) {
        if let title = randomMessage["title"], let subtitle = randomMessage["subtitle"] {
          TitleSubtitleView(title: title, subtitle: subtitle)
        }
        Spacer().frame(height: 23)

        if randomMessage["text"] != nil {
          // Use TextView with the rectangle
          TextView(text: randomMessage["text"] ?? "")
        } else if let command = randomMessage["command"] {
          // Use CommandView with the ">" sign
          CommandView(command: command)
        }
      }
      Spacer()

      if viewModel.hasGPTSuggestionsFreeTierCountReachedLimit
        && viewModel.hasUserValidatedOwnOpenAIAPIKey == .usingFreeTier
      {
        ActivateShellMateView()
          .padding(10)
      } else if viewModel.shouldTroubleShootAPIKey
        || viewModel.hasUserValidatedOwnOpenAIAPIKey == .invalid
      {
        TroubleshootShellMateView()
          .padding(10)
      }

      BannersViewForEmptyState()
      SuggestionsStatusBarView(viewModel: viewModel)
    }
    .frame(maxHeight: .infinity, alignment: .bottom)
  }
}
