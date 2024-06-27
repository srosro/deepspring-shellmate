//
//  ApplicationDelegate.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 23/06/24.
//

import Cocoa
import AXSwift

class ApplicationDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let terminalContentDelegate = TerminalContentManager()
    let windowPositionDelegate = WindowPositionManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            window.setContentSize(NSSize(width: 400, height: 600))
            window.center() // Optional: to center the window
            self.window = window
        }
        checkAccessibilityPermissions()
    }
    
    func checkAccessibilityPermissions() {
        let isAppTrusted = AccessibilityChecker.isAppTrusted()
        let isTerminalTrusted = AccessibilityChecker.isTerminalTrusted()
        
        if isAppTrusted {
            print("Application is trusted for accessibility.")
        } else {
            print("Application is not trusted for accessibility.")
        }
        
        if isTerminalTrusted {
            print("Terminal is trusted for accessibility.")
        } else {
            print("Terminal is not trusted for accessibility.")
        }
        
        if isAppTrusted && isTerminalTrusted {
            initializeApp()
        } else {
            showSettingsView()
        }
    }
    
    func showSettingsView() {
        UserDefaults.standard.set(true, forKey: "showSettingsView")
    }
    
    func initializeApp() {
        UserDefaults.standard.set(false, forKey: "showSettingsView")
        observeTerminalLifecycle()
        terminalContentDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("AppDidFinishLaunching")))
        windowPositionDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("AppDidFinishLaunching")))
        windowPositionDelegate.initializeObserverForRunningTerminal()
        runInstallScript() // Run the install.sh script
    }
    
    func observeTerminalLifecycle() {
        let workspace = NSWorkspace.shared
        
        workspace.notificationCenter.addObserver(windowPositionDelegate,
                                                 selector: #selector(WindowPositionManager.handleTerminalLaunch(_:)),
                                                 name: NSWorkspace.didLaunchApplicationNotification,
                                                 object: nil)
        
        workspace.notificationCenter.addObserver(windowPositionDelegate,
                                                 selector: #selector(WindowPositionManager.handleTerminalTermination(_:)),
                                                 name: NSWorkspace.didTerminateApplicationNotification,
                                                 object: nil)
    }
    private func runInstallScript() {
        // Print the current directory (should be the root)
        printCurrentDirectory()
        
        // List the contents of the current directory (should be the root)
        listDirectoryContents()
        
        // Get the current executable path (app bundle path)
        let currentPath = Bundle.main.bundlePath
        print("App bundle path: \(currentPath)")
        
        // List the contents of the app bundle path
        listDirectoryContents(atPath: currentPath)
        
        // Change directory to the Contents folder within the app bundle path and list contents
        changeToContentsAndListContents(atPath: currentPath)
        
        // Path to the install.sh script
        let scriptPath = (currentPath as NSString).appendingPathComponent("../ShellBuddyCLI/install.sh")
        let absoluteScriptPath = URL(fileURLWithPath: scriptPath).standardized.path
        
        // Check if the script exists at the calculated path
        guard FileManager.default.fileExists(atPath: absoluteScriptPath) else {
            print("install.sh not found at path: \(absoluteScriptPath)")
            return
        }
        
        print("Found install.sh at path: \(absoluteScriptPath)")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [absoluteScriptPath]
        process.currentDirectoryURL = URL(fileURLWithPath: currentPath) // Set the working directory to the app bundle path
        
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                print("Script executed successfully.")
            } else {
                print("Script execution failed with status: \(process.terminationStatus)")
            }
        } catch {
            print("Failed to execute script: \(error)")
        }
    }
    
    private func printCurrentDirectory() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "pwd"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print("Current directory: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        } catch {
            print("Failed to run pwd: \(error)")
        }
    }
    
    private func listDirectoryContents(atPath path: String? = nil) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        
        if let path = path {
            process.arguments = ["-c", "ls -la \(path)"]
        } else {
            process.arguments = ["-c", "ls -la"]
        }
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print("Directory contents:\n\(output)")
            }
        } catch {
            print("Failed to run ls: \(error)")
        }
    }
    
    private func changeToContentsAndListContents(atPath path: String) {
        let contentsPath = (path as NSString).appendingPathComponent("Contents")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "cd \(contentsPath) && ls -la"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print("Contents of \(contentsPath):\n\(output)")
            }
        } catch {
            print("Failed to change directory and list contents: \(error)")
        }
    }
}
