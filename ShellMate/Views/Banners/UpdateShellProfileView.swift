//
//  UpdateShellProfile.swift
//  ShellMate
//
//  Created by Daniel Delattre on 28/08/24.
//

import SwiftUI

struct UpdateShellProfile: View {
  var scrollToFixingCommand: (ScrollViewProxy, String) -> Void
  var scrollView: ScrollViewProxy

  var body: some View {
    HStack(spacing: 8) {
      UpdateShellProfileTextView()

      Spacer()

      UpdateShellProfileActionsView(
        scrollToFixingCommand: scrollToFixingCommand, scrollView: scrollView)
    }
    .padding(.vertical, 10)
    .padding(.horizontal, 16)
    .background(Color.BG.UpdateShellProfile.red)
  }
}

struct UpdateShellProfileTextView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("ShellMate encountered an issue")
        .fontWeight(.semibold)
        .foregroundColor(Color.Text.white)

      (Text("Refresh your shell profile to run ")
        + Text("‘sm’").bold()
        + Text(" commands on windows open prior to install."))
        .fontWeight(.regular)
        .foregroundColor(Color.Text.white)
        .lineLimit(5)  // Allow text to wrap into multiple lines
        .fixedSize(horizontal: false, vertical: true)
    }
    .font(.body)
  }
}

struct UpdateShellProfileActionsView: View {
  @ObservedObject var viewModel = UpdateShellProfileViewModel.shared
  var scrollToFixingCommand: (ScrollViewProxy, String) -> Void
  var scrollView: ScrollViewProxy

  var body: some View {
    Button(action: {
      // Access the suggestion ID from the view model
      if let scrollKey = viewModel.fixSmCommandNotFoundSuggestionIndex {
        scrollToFixingCommand(scrollView, scrollKey)  // Trigger the scroll with the correct ID
      }
    }) {
      Text("Show me how")
        .font(.body)
        .fontWeight(.regular)
        .foregroundColor(Color.Text.white)
        .padding(.init(top: 6, leading: 9, bottom: 6, trailing: 8))
        .background(Color.clear)
        .overlay(
          RoundedRectangle(cornerRadius: 4)
            .stroke(Color.Stroke.ChatWithMakers.gray, lineWidth: 1.4)
        )
    }
    .buttonStyle(BorderlessButtonStyle())
  }
}
