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

    init(appWindow: NSWindow?) {
        self.appWindow = appWindow
        startWindowPoller()
        processingManager = ProcessingManager(viewModel: self)
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
    var filteredResults: [String: (suggestionsCount: Int, suggestionsHistory: [[Dictionary<String, String>]], updatedAt: Date)] {
        var filteredResults = [String: (suggestionsCount: Int, suggestionsHistory: [[Dictionary<String, String>]], updatedAt: Date)]()
        
        for (identifier, result) in results {
            // Filter out empty dictionaries within each history batch
            let nonEmptyHistory = result.suggestionsHistory.map { history in
                history.filter { !$0.isEmpty }
            }.filter { !$0.isEmpty }
            
            if !nonEmptyHistory.isEmpty {
                filteredResults[identifier] = (suggestionsCount: result.suggestionsCount, suggestionsHistory: nonEmptyHistory, updatedAt: result.updatedAt)
            }
        }
        
        // Log the filtered results in a pretty manner
        logFilteredResults(filteredResults)
        return filteredResults
    }
    
    private func logFilteredResults(_ results: [String: (suggestionsCount: Int, suggestionsHistory: [[Dictionary<String, String>]], updatedAt: Date)]) {
        print("#1234debug Filtered Results:")
        for (identifier, result) in results {
            print("#1234debug Identifier: \(identifier)")
            print("#1234debug Suggestions Count: \(result.suggestionsCount)")
            print("#1234debug Updated At: \(result.updatedAt)")
            print("#1234debug Suggestions History:")
            for history in result.suggestionsHistory {
                print("#1234debug   - History Batch:")
                for suggestion in history {
                    print("#1234debug     - \(suggestion)")
                }
            }
        }
    }
}