import SwiftUI


@main
struct ShellBuddyApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) var appDelegate
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}


class AppViewModel: ObservableObject {
    @Published var currentTerminalID: String?
    @Published var currentStateText: String
    @Published var updateCounter: Int = 0
    @Published var filteredResults: [String: (suggestionsCount: Int, suggestionsHistory: [[[String: String]]], updatedAt: Date)]

    init() {
        self.filteredResults = [
            "dummyID": (suggestionsCount: 1,
                        suggestionsHistory: [
                            [
                                ["gptResponse": "Showing the user's intention", "suggestedCommand": "echo 'Hello, World!' [1]", "commandExplanation": "prints 'Hello, World!' [1]"],
                                ["gptResponse": "Hello, World! [2]", "suggestedCommand": "echo 'Hello, World!' [2]", "commandExplanation": "prints 'Hello, World!' [2]"],
                                ["gptResponse": "Hello, World! [3]", "suggestedCommand": "echo 'Hello, World!' [3]", "commandExplanation": "prints 'Hello, World!' [3]"]
                            ],
                            [
                                ["gptResponse": "Instead of the actual command (as we don't really have the command)", "suggestedCommand": "echo 'Hello, World!' [1]", "commandExplanation": "prints 'Hello, World!' [1]"],
                                ["gptResponse": "Hello, World! [2]", "suggestedCommand": "echo 'Hello, World!' [2]", "commandExplanation": "prints 'Hello, World!' [2]"],
                                ["gptResponse": "Hello, World! [3]", "suggestedCommand": "echo 'Hello, World!' [3]", "commandExplanation": "prints 'Hello, World!' [3]"]
                            ],
                            [
                                ["gptResponse": "Showing the user's intention", "suggestedCommand": "echo 'Hello, World!' [4]", "commandExplanation": "prints 'Hello, World!' [4]"],
                                ["gptResponse": "Hello, World! [5]", "suggestedCommand": "echo 'This will be a really long long long long long long long long long long command to see what happens, World!' [5]", "commandExplanation": "prints 'Hello, World!' [5]"],
                                ["gptResponse": "Hello, World! [6]", "suggestedCommand": "echo 'Hello, World!' [6]", "commandExplanation": "prints 'Hello, World!' [6]"]
                            ],
                        ],
                        updatedAt: Date()),
             
            "dummyID2": (suggestionsCount: 1,
                         suggestionsHistory: [
                            [
                                ["gptResponse": "Hello, World! [1]", "suggestedCommand": "echo 'Hello, World!' [1]"],
                                ["gptResponse": "Hello, World! [2]", "suggestedCommand": "echo 'Hello, World!' [2]"],
                                ["gptResponse": "Hello, World! [3]", "suggestedCommand": "echo 'Hello, World!' [3]"]
                            ],
                         ],
                         updatedAt: Date()),
        ]
        
        self.currentTerminalID = "dummyID"
        self.currentStateText = "Detecting changes..."
    }
}





