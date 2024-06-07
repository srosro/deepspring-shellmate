import Foundation
import Combine
import ScreenCaptureKit
import AppKit
import os


class AppViewModel: ObservableObject {
    @Published var results: [String: (suggestionsCount: Int, suggestionsHistory: [[Dictionary<String, String>]], updatedAt: Date)] = [:]
    @Published var isPaused: Bool = true
    @Published var updateCounter: Int = 0  // This counter will be incremented on every update
    @Published private(set) var currentTerminalID: String?  // Make currentTerminalID publicly readable
    @Published var currentStateText: String = "No Changes on Terminal"  // Add this property

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "App", category: "AppViewModel")
    private let queue = DispatchQueue(label: "com.example.appviewmodel.queue")
    private weak var appWindow: NSWindow?
    private var processingManager: ProcessingManager?

    
    // Original initializer (commented out for preview purpose)
    // init(appWindow: NSWindow?) {
    //     self.appWindow = appWindow
    //     startWindowPoller()
    //     processingManager = ProcessingManager(viewModel: self)
    // }

    // Initializer for previews
    init(appWindow: NSWindow?) {
        self.results = ["dummyID": (suggestionsCount: 1, 
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
        //self.currentStateText = "No changes on Terminal"
        self.appWindow = nil
    }

    private func startWindowPoller() {
        queue.async {
            self.windowPoller()
        }
    }

    private func windowPoller() {
        while true {
            self.findEligibleWindows { windows in
                if let currentTerminalID = self.currentTerminalID, windows.contains(where: { "\( $0.windowID)" == currentTerminalID }) {
                    // Current terminal window is still eligible
                    if let currentWindow = windows.first(where: { "\( $0.windowID)" == currentTerminalID }) {
                        self.adjustApplicationWindow(to: currentWindow)
                        self.unminimizeAppWindow()
                    }
                } else {
                    // Select a new terminal window
                    if let newWindow = windows.first {
                        self.currentTerminalID = "\(newWindow.windowID)"
                        self.adjustApplicationWindow(to: newWindow)
                        self.unminimizeAppWindow()
                    } else {
                        // No eligible terminal windows found, minimize ShellBuddy
                        self.minimizeAppWindow()
                    }
                }
            }
            // Delay before the next iteration
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    private func findEligibleWindows(completion: @escaping ([SCWindow]) -> Void) {
        SCShareableContent.getWithCompletionHandler { content, error in
            guard let content = content, error == nil else {
                self.logger.error("Failed to discover shareable content: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }

            let terminalWindows = content.windows.filter { window in
                let minSize: CGFloat = 40
                return window.isOnScreen
                    && window.frame.width > minSize
                    && window.frame.height > minSize
                    && !(window.title?.isEmpty ?? true)
                    && window.owningApplication?.applicationName == "Terminal"
            }

            self.logger.log("Terminal windows found: \(terminalWindows.count)")
            completion(terminalWindows)
        }
    }

    private func adjustApplicationWindow(to window: SCWindow) {
        guard let appWindow = self.appWindow else { return }

        let screenHeight = NSScreen.main?.frame.height ?? 0
        let windowFrame = window.frame
        let newAppFrame = CGRect(x: windowFrame.maxX, y: screenHeight - windowFrame.maxY, width: 400, height: windowFrame.height)

        DispatchQueue.main.async {
            appWindow.setFrame(newAppFrame, display: true, animate: true)
        }
    }

    private func minimizeAppWindow() {
        guard let appWindow = self.appWindow else { return }
        DispatchQueue.main.async {
            if !appWindow.isMiniaturized {
                appWindow.miniaturize(nil)
                self.logger.log("ShellBuddy window minimized")
            }
        }
    }

    private func unminimizeAppWindow() {
        guard let appWindow = self.appWindow else { return }
        DispatchQueue.main.async {
            if appWindow.isMiniaturized {
                appWindow.deminiaturize(nil)
                self.logger.log("ShellBuddy window unminimized")
            }
        }
    }
}

extension AppViewModel {
    var sortedResults: [String] {
        results.keys.sorted {
            results[$0]!.updatedAt < results[$1]!.updatedAt
        }
    }
}
