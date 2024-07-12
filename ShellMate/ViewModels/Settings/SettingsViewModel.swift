//
//  SettingsViewModel.swift
//  ShellMate
//
//  Created by daniel on 08/07/24.
//

import Foundation

class AboutViewModel: ObservableObject {
    @Published var appVersion: String = ""
    @Published var appBuild: String = ""
    
    init() {
        do {
            appVersion = try getAppVersion()
            appBuild = try getAppBuild()
        } catch {
            appVersion = "Version info not available"
            appBuild = "Build info not available"
        }
    }
}

enum WindowAttachmentPosition: String {
    case left
    case right
    case float
}

class GeneralViewModel: ObservableObject {
    @Published var windowAttachmentPosition: WindowAttachmentPosition
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 1 // Adjust the debounce interval as needed
    private var isDebouncing: Bool = false // Flag to manage debounce state
    
    init() {
        if let savedPosition = UserDefaults.standard.string(forKey: "windowAttachmentPosition"),
           let position = WindowAttachmentPosition(rawValue: savedPosition) {
            self.windowAttachmentPosition = position
        } else {
            self.windowAttachmentPosition = .right
        }
        // Add the observer
        NotificationCenter.default.addObserver(self, selector: #selector(handleWindowAttachmentPositionDidChange(_:)), name: .windowAttachmentPositionDidChange, object: nil)
    }
    
    func updateWindowAttachmentPosition(source: String) {
        UserDefaults.standard.set(windowAttachmentPosition.rawValue, forKey: "windowAttachmentPosition")
        
        NotificationCenter.default.post(name: .updatedAppPositionAfterWindowAttachmentChange, object: nil)
    }
    
    @objc private func handleWindowAttachmentPositionDidChange(_ notification: Notification) {
        print("HANDLE 1.a")
        print("Is debouncing: \(isDebouncing)")
        guard let userInfo = notification.userInfo,
              let source = userInfo["source"] as? String,
              source == "dragging",
              let positionRawValue = userInfo["position"] as? String,
              let newPosition = WindowAttachmentPosition(rawValue: positionRawValue),
              !isDebouncing else {
            return
        }
        // Set the debouncing flag to true to ignore subsequent events
        isDebouncing = true
        
        print("HANDLE 1.b")
        // Immediately update the windowAttachmentPosition
        DispatchQueue.main.async {
            self.windowAttachmentPosition = newPosition
            UserDefaults.standard.set(newPosition.rawValue, forKey: "windowAttachmentPosition")
            print("BLABLABLA: \(newPosition)")
            print("BLABLABLA var: \(self.windowAttachmentPosition)")
            print("HANDLE 1.c")
            NotificationCenter.default.post(name: .updatedAppPositionAfterWindowAttachmentChange, object: nil)
        }

        // Schedule a timer to reset the debouncing flag after the debounce interval
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            self?.isDebouncing = false
            if let savedPosition = UserDefaults.standard.string(forKey: "windowAttachmentPosition") {
                print("BLABLABLA2 var: \(savedPosition)")
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
