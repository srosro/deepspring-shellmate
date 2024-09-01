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
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyStateView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var randomMessage: [String: String] = [:]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 5) {
                if let title = randomMessage["title"], let subtitle = randomMessage["subtitle"] {
                    TitleSubtitleView(title: title, subtitle: subtitle)
                }
                Spacer().frame(height: 23)
                if let command = randomMessage["command"] {
                    CommandView(command: command)
                }
            }
            Spacer()
            Divider().padding(.top, 5)
            SuggestionsStatusBarView(viewModel: viewModel)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .onAppear {
            if let message = EmptyStateViewModel.shared.getRandomMessage() {
                randomMessage = message
            }
        }
    }
}

