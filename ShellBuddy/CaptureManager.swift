//
//  CaptureManager.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 24/05/24.
//

import Foundation
import ScreenCaptureKit

class CaptureManager {
    
    func captureWindows(completion: @escaping ([(identifier: String, image: CGImage?)]) -> Void) {
        findEligibleWindows { windows in
            self.captureImages(for: windows, completion: completion)
        }
    }

    private func findEligibleWindows(completion: @escaping ([SCWindow]) -> Void) {
        SCShareableContent.getWithCompletionHandler { content, error in
            guard let content = content, error == nil else {
                print("Failed to discover shareable content: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }

            let terminalWindows = content.windows.filter { window in
                let minSize: CGFloat = 40
                return window.isOnScreen && window.frame.width > minSize && window.frame.height > minSize && !(window.title?.isEmpty ?? true) && window.owningApplication?.applicationName == "Terminal"
            }

            print("Terminal windows found: \(terminalWindows.count)")
            terminalWindows.forEach { window in
                print("Window title: \(window.title ?? "Unknown")")
            }

            completion(terminalWindows)
        }
    }

    private func captureImages(for windows: [SCWindow], completion: @escaping ([(identifier: String, image: CGImage?)]) -> Void) {
        var results: [(identifier: String, image: CGImage?)] = []
        let group = DispatchGroup()
        
        windows.forEach { window in
            group.enter()
            let config = SCStreamConfiguration()
            config.width = Int(window.frame.width)
            config.height = Int(window.frame.height)
            config.showsCursor = false

            let filter = SCContentFilter(desktopIndependentWindow: window)
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) { image, error in
                let identifier = "\(window.windowID)_\(window.title ?? "unknown")"
                if let error = error {
                    print("Failed to capture screenshot for window \(identifier): \(error.localizedDescription)")
                } else {
                    print("Screenshot captured successfully for window \(identifier).")
                    results.append((identifier: identifier, image: image))
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(results)
        }
    }
}
