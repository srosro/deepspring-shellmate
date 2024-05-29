//
//  CaptureManager.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 24/05/24.
//

import Foundation
import ScreenCaptureKit

class CaptureManager {
    
    func captureWindows(processingStatus: [String: Bool], completion: @escaping ([(identifier: String, windowTitle: String, image: CGImage?)]) -> Void) {
        findEligibleWindows(processingStatus: processingStatus) { windows in
            self.captureImages(for: windows, completion: completion)
        }
    }

    private func findEligibleWindows(processingStatus: [String: Bool], completion: @escaping ([SCWindow]) -> Void) {
        SCShareableContent.getWithCompletionHandler { content, error in
            guard let content = content, error == nil else {
                print("Failed to discover shareable content: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }

            let terminalWindows = content.windows.filter { window in
                let minSize: CGFloat = 40
                let identifier = "\(window.windowID)"
                return window.isOnScreen
                    && window.frame.width > minSize
                    && window.frame.height > minSize
                    && !(window.title?.isEmpty ?? true)
                    && window.owningApplication?.applicationName == "Terminal"
                    && (processingStatus[identifier] == nil || processingStatus[identifier] == false)
            }

            print("Terminal windows found: \(terminalWindows.count)")
            terminalWindows.forEach { window in
                print("Window title: \(window.title ?? "Unknown")")
            }

            completion(terminalWindows)
        }
    }

    private func captureImages(for windows: [SCWindow], completion: @escaping ([(identifier: String, windowTitle: String, image: CGImage?)]) -> Void) {
        var results: [(identifier: String, windowTitle: String, image: CGImage?)] = []
        let group = DispatchGroup()
        
        windows.forEach { window in
            group.enter()
            let config = SCStreamConfiguration()
            config.width = Int(window.frame.width)
            config.height = Int(window.frame.height)
            config.showsCursor = false

            let filter = SCContentFilter(desktopIndependentWindow: window)
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) { image, error in
                let identifier = "\(window.windowID)"
                let windowTitle = window.title ?? "unknown"
                if let error = error {
                    print("Failed to capture screenshot for window \(identifier): \(error.localizedDescription)")
                } else {
                    print("Screenshot captured successfully for window \(identifier).")
                    results.append((identifier: identifier, windowTitle: windowTitle, image: image))
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(results)
        }
    }
}
