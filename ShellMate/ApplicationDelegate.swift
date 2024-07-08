//
//  ApplicationDelegate.swift
//  ShellMate
//
//  Created by Daniel Delattre on 23/06/24.
//

import Cocoa
import AXSwift
import Mixpanel
import Sentry


class ApplicationDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let terminalContentDelegate = TerminalContentManager()
    let windowPositionDelegate = WindowPositionManager()
    let keyPressDelegate = KeyPressDelegate()
    var isAppInitialized = false // Add this property

    func applicationDidFinishLaunching(_ notification: Notification) {
        resizeWindow(width: 400, height: 600)
        print("ApplicationDelegate - Application did finish launching.")

        setupSentry()
        runInstallScript() // Run the install.sh script
        trackFirstLaunchAfterInstall()
        MixpanelHelper.shared.trackEvent(name: "applicationLaunch")
        checkAccessibilityPermissionsAndApiKey()
    }
    
    func setupSentry() {        // Initialize Sentry SDK
        SentrySDK.start { options in
            options.dsn = "https://0256895de48160d74021d3ffe93688e6@o4507511162798080.ingest.us.sentry.io/4507540074463232"
            options.debug = false // Enable debug for initial setup
            // Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring.
            // We recommend adjusting this value in production.
            options.tracesSampleRate = 1.0

            // Sample rate for profiling, applied on top of TracesSampleRate.
            // We recommend adjusting this value in production.
            options.profilesSampleRate = 1.0
        }
    }
    
    func resizeWindow(width: CGFloat, height: CGFloat) {
        if let window = NSApplication.shared.windows.first {
            window.setContentSize(NSSize(width: width, height: height))
            window.center() // Optional: to center the window
            self.window = window
        }
    }
    
    func checkAccessibilityPermissionsAndApiKey() {
        let isAppTrusted = AccessibilityChecker.isAppTrusted()
        
        if isAppTrusted {
            print("Application is trusted for accessibility.")
        } else {
            print("Application is not trusted for accessibility.")
        }
        
        let apiKeyValidationState = UserDefaults.standard.string(forKey: "apiKeyValidationState") ?? ApiKeyValidationState.unverified.rawValue
        let isApiKeyValid = apiKeyValidationState == ApiKeyValidationState.valid.rawValue

        if isAppTrusted && isApiKeyValid {
            initializeApp()
        } else {
            showSettingsView()
        }
    }

    func initializeApp() {
        showContentView()
        guard !isAppInitialized else { return } // Add this check

        isAppInitialized = true // Set the flag to true
        print("ApplicationDelegate - initializeApp called.")
        
        observeTerminalLifecycle()
        terminalContentDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("AppDidFinishLaunching")))
        windowPositionDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("AppDidFinishLaunching")))
        windowPositionDelegate.initializeObserverForRunningTerminal()
        keyPressDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("AppDidFinishLaunching")))
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
        // Get the path to the install.sh script in the app bundle
        guard let scriptPath = Bundle.main.path(forResource: "install", ofType: "sh") else {
            print("install.sh not found in the app bundle")
            return
        }

        print("Found install.sh at path: \(scriptPath)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath]

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
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
