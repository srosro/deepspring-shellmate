//
//  StartupTerminalWindowHandler.swift
//  ShellMate
//
//  Created by Daniel Delattre on 20/07/24.
//

import Cocoa
import AXSwift

class StartupTerminalWindowHandler {
    static func handleTerminalApp() {
        let terminalBundleIdentifier = "com.apple.Terminal"
        
        // Check if Terminal is running
        if let runningTerminalApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == terminalBundleIdentifier }) {
            handleRunningTerminalApp(runningTerminalApp)
        } else {
            launchTerminalApp()
        }
    }
    
    private static func handleRunningTerminalApp(_ runningTerminalApp: NSRunningApplication) {
        let axApp = AXUIElementCreateApplication(runningTerminalApp.processIdentifier)
        
        // Check if Terminal has any windows
        var axWindows: AnyObject?
        let result = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &axWindows)
        
        if result == .success, let axWindows = axWindows as? [AXUIElement], !axWindows.isEmpty {
            handleTerminalWindows(axWindows)
        } else {
            activateHiddenTerminalWindow()
        }
        
        // Bring Terminal to the foreground
        runningTerminalApp.activate()
    }
    
    private static func activateHiddenTerminalWindow() {
        let script = """
        tell application "Terminal"
            reopen
            activate
        end tell
        """
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
        if let error = error {
            print("Error activating hidden Terminal window: \(error)")
        }
    }
    
    private static func handleTerminalWindows(_ axWindows: [AXUIElement]) {
        var foundNonMiniaturizedWindow = false
        
        for axWindow in axWindows {
            if let isMinimized = isWindowMinimized(axWindow), !isMinimized {
                activateWindow(axWindow)
                foundNonMiniaturizedWindow = true
                break
            }
        }
        
        if !foundNonMiniaturizedWindow {
            for axWindow in axWindows {
                if let isMinimized = isWindowMinimized(axWindow), isMinimized == true {
                    unminiaturizeAndActivateWindow(axWindow)
                    break
                }
            }
        }
    }
    
    private static func isWindowMinimized(_ window: AXUIElement) -> Bool? {
        var isMinimized: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &isMinimized) == .success {
            return isMinimized as? Bool
        }
        return nil
    }
    
    private static func activateWindow(_ window: AXUIElement) {
        let frontmost: CFBoolean = kCFBooleanTrue
        let setResult = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, frontmost)
        if setResult != .success {
            print("Error activating window: \(setResult.rawValue)")
        }
    }
    
    private static func unminiaturizeAndActivateWindow(_ window: AXUIElement) {
        let unminiaturizeValue: CFBoolean = kCFBooleanFalse
        let setResult = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, unminiaturizeValue)
        if setResult == .success {
            activateWindow(window)
        } else {
            print("Error unminiaturizing window: \(setResult.rawValue)")
        }
    }
    
    private static func launchTerminalApp() {
        if let terminalURL = getURLForTerminal() {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: terminalURL, configuration: configuration, completionHandler: nil)
            
            // After launching, bring Terminal to the foreground
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let runningTerminalApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.Terminal" }) {
                    runningTerminalApp.activate()
                }
            }
        } else {
            print("Could not find Terminal app.")
        }
    }
    
    private static func getURLForTerminal() -> URL? {
        let terminalBundleIdentifier = "com.apple.Terminal"
        if let urls = LSCopyApplicationURLsForBundleIdentifier(terminalBundleIdentifier as CFString, nil)?.takeRetainedValue() as? [URL],
           let terminalURL = urls.first {
            return terminalURL
        } else {
            print("Error finding Terminal app.")
            return nil
        }
    }
}
