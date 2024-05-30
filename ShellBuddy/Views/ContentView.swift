import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

    init(viewModel: AppViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    enum Tab {
        case suggestions, history
    }

    var body: some View {
        TabView {
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
