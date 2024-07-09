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
        
        // Post the notification
        NotificationCenter.default.post(name: .windowAttachmentPositionDidChange, object: nil, userInfo: ["position": windowAttachmentPosition.rawValue, "source": source])
    }
    
    @objc private func handleWindowAttachmentPositionDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let source = userInfo["source"] as? String,
              source == "dragging",
              let positionRawValue = userInfo["position"] as? String,
              let newPosition = WindowAttachmentPosition(rawValue: positionRawValue) else {
            return
        }
        
        DispatchQueue.main.async {
            self.windowAttachmentPosition = newPosition
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
