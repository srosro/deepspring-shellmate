//
//  ContentView.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 22/05/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: AppViewModel
    @State private var selectedTab: Tab = .suggestions

    init(viewModel: AppViewModel = AppViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    enum Tab {
        case suggestions, history
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SuggestionsView(viewModel: viewModel)
                .tabItem {
                    Label("Suggestions", systemImage: "lightbulb")
                }
                .tag(Tab.suggestions)
                .onAppear {
                    viewModel.isPaused = false
                }

            HistoryView(viewModel: viewModel)
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(Tab.history)
                .onAppear {
                    viewModel.isPaused = true
                }
        }
    }
}
