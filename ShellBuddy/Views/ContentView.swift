import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

    init(viewModel: AppViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        SuggestionsView(viewModel: viewModel)
            .onAppear {
                viewModel.isPaused = false
            }
    }
}
