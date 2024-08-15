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
    let shellMateWindowTrackingDelegate = ShellMateWindowTrackingDelegate()
    let keyPressDelegate = KeyPressDelegate()
    var isAppInitialized = false // Add this property

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check if another instance is running
        let runningInstances = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!)
        if runningInstances.count > 1 {
            print("Another instance of the app is already running. Exiting this instance.")
            NSApp.terminate(nil) // Exit the current instance
            return
        }
        
        showPermissionsView()
        setupMainWindow()
        resizeWindow(width: 430, height: 650)
        print("ApplicationDelegate - Application did finish launching.")

        setupSentry()
        runInstallScript() // Run the install.sh script
        trackFirstLaunchAfterInstall()
        MixpanelHelper.shared.trackEvent(name: "applicationLaunch")
        checkAccessibilityPermissionsAndApiKey()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleStartAppInitialization), name: .startAppInitialization, object: nil)
    }
    
    @objc func handleStartAppInitialization() {
        initializeApp() // This runs on Permissions 'Continue' button click action
    }
    
    func setupSentry() {        // Initialize Sentry SDK
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])

        SentrySDK.start { options in
            options.dsn = "https://0256895de48160d74021d3ffe93688e6@o4507511162798080.ingest.us.sentry.io/4507540074463232"
            options.debug = false // Enable debug for initial setup
            // Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring.
            // We recommend adjusting this value in production.
            //options.tracesSampleRate = 1.0

            // Sample rate for profiling, applied on top of TracesSampleRate.
            // We recommend adjusting this value in production.
            //options.profilesSampleRate = 1.0
        }
    }
    
    func setupMainWindow() {
        if let mainWindow = NSApplication.shared.windows.first {
            self.window = mainWindow
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
        DispatchQueue.main.async {
            let isAppTrusted = AccessibilityChecker.isAppTrusted()
            
            if isAppTrusted {
                print("Application is trusted for accessibility.")
            } else {
                print("Application is not trusted for accessibility.")
            }
            
            Task {
                let result = await LicenseViewModel.shared.checkApiKey(LicenseViewModel.shared.apiKey)
                let isApiKeyValid: Bool
                
                switch result {
                case .success:
                    isApiKeyValid = true
                    print("ApplicationDelegate - API key is valid.")
                case .failure(let error):
                    isApiKeyValid = false
                    print("ApplicationDelegate - API key validation failed with error: \(error.localizedDescription)")
                }
                
                if isAppTrusted && isApiKeyValid {
                    // Both conditions are true, so initialize the app
                    self.initializeApp()
                    print("ApplicationDelegate - \(isApiKeyValid) (valid API) - App initialized.")
                } else {
                    print("ApplicationDelegate - \(isApiKeyValid) (valid API) - Show permissions view.")
                }
            }
        }
    }

    func initializeApp() {
        showContentView()
        guard !isAppInitialized else { return } // Dont run initialization twice

        isAppInitialized = true // Set the flag to true
        print("ApplicationDelegate - initializeApp called.")
               
        StartupTerminalWindowHandler.handleTerminalApp()
        shellMateWindowTrackingDelegate.setWindowPositionDelegate(windowPositionDelegate)
        shellMateWindowTrackingDelegate.startTracking() 
        
        observeTerminalLifecycle()
        terminalContentDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("AppDidFinishLaunching")))
        windowPositionDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("AppDidFinishLaunching")))
        windowPositionDelegate.initializeObserverForRunningTerminal()
        keyPressDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("AppDidFinishLaunching")))
    }
   
    func getURLForTerminal() -> URL? {
        let terminalBundleIdentifier = "com.apple.Terminal"
        if let urls = LSCopyApplicationURLsForBundleIdentifier(terminalBundleIdentifier as CFString, nil)?.takeRetainedValue() as? [URL],
           let terminalURL = urls.first {
            return terminalURL
        } else {
            return nil
        }
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
    
    func applicationWillTerminate(_ notification: Notification) {
        // Stop tracking
        shellMateWindowTrackingDelegate.stopTracking()
    }
}
