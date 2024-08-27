//
//  ShellMateWindowTrackingDelegate.swift
//  ShellMate
//
//  Created by daniel on 09/07/24.
//

import AXSwift
import Cocoa

class GhostWindow: NSWindow {
  static var sharedInstance: GhostWindow?
  private var isMouseCloseToTerminalBorder: Bool = false
  private var terminalBorderPosition: String?
  private var feedbackBorderWidth: CGFloat = 5
  private var proximityFeedbackBorderWidth: CGFloat = 25
  private var mouseCloseToBorderFeedbackWindow: NSWindow?
  private var appRelativePositionToTerminalWindow: String?

  static func getInstance(appWindowPosition: NSRect) -> GhostWindow {
    if sharedInstance == nil {
      let ghostRect = NSRect(
        x: appWindowPosition.origin.x, y: appWindowPosition.origin.y, width: 100, height: 100)  // Placeholder rect; will be updated by notification
      sharedInstance = GhostWindow(contentRect: ghostRect)
    }
    return sharedInstance!
  }

  init(contentRect: NSRect) {
    super.init(contentRect: contentRect, styleMask: .borderless, backing: .buffered, defer: false)
    self.isOpaque = false
    self.backgroundColor = NSColor(
      calibratedRed: 8 / 255, green: 133 / 255, blue: 245 / 255, alpha: 0.8)
    self.level = .floating
    self.hasShadow = false
    setupNotificationObservers()
  }

  override var canBecomeKey: Bool {
    return false
  }

  override var canBecomeMain: Bool {
    return false
  }

  private func setupNotificationObservers() {
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleGhostWindowStateChange(_:)), name: .ghostWindowStateDidChange,
      object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleMousePositionCloseToTerminalBorder(_:)),
      name: .mousePositionCloseToTerminalBorder, object: nil)
  }

  deinit {
    NotificationCenter.default.removeObserver(self, name: .ghostWindowStateDidChange, object: nil)
    NotificationCenter.default.removeObserver(
      self, name: .mousePositionCloseToTerminalBorder, object: nil)
  }

  @objc private func handleGhostWindowStateChange(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
      let action = userInfo["action"] as? String
    else { return }

    print("Received notification with action: \(action)")

    switch action {
    case "update", "show":
      if let appWindowPosition = userInfo["appWindowPosition"] as? NSRect,
        let terminalPosition = userInfo["terminalPosition"] as? (position: CGPoint, size: CGSize)
      {
        let relativePosition = checkWindowPositionRelativeToTerminal(
          appWindowPosition: appWindowPosition, terminalWindowPosition: terminalPosition.position,
          terminalWindowSize: terminalPosition.size)

        if relativePosition == "float" {
          self.orderOut(nil)
        } else {
          let frame = calculateGhostWindowFrame(
            appWindowPosition: appWindowPosition, terminalPosition: terminalPosition)
          self.setFrame(frame, display: true)
          if action == "show" {
            self.makeKeyAndOrderFront(nil)
          } else if action == "update" && !self.isVisible {
            self.makeKeyAndOrderFront(nil)
          }
        }
        print("Updated ghost window frame to: \(frame)")
      }
    case "hide":
      self.orderOut(nil)
      print("Ghost window hidden")
    default:
      break
    }
  }

  private func calculateGhostWindowFrame(
    appWindowPosition: NSRect, terminalPosition: (position: CGPoint, size: CGSize)
  ) -> NSRect {
    appRelativePositionToTerminalWindow = checkWindowPositionRelativeToTerminal(
      appWindowPosition: appWindowPosition, terminalWindowPosition: terminalPosition.position,
      terminalWindowSize: terminalPosition.size)

    // Debug print statements
    print("App window position: \(appWindowPosition)")
    print("Terminal position: \(terminalPosition)")
    print("Relative position: \(appRelativePositionToTerminalWindow ?? "nil")")
    print("Mouse close to terminal border: \(isMouseCloseToTerminalBorder)")
    print("Terminal border position: \(terminalBorderPosition ?? "nil")")

    var ghostRect: NSRect
    let borderWidth = feedbackBorderWidth

    if appRelativePositionToTerminalWindow == "left" {
      ghostRect = NSRect(
        x: terminalPosition.position.x, y: terminalPosition.position.y, width: borderWidth,
        height: terminalPosition.size.height)
    } else if appRelativePositionToTerminalWindow == "right" {
      ghostRect = NSRect(
        x: terminalPosition.position.x + terminalPosition.size.width - borderWidth,
        y: terminalPosition.position.y, width: borderWidth, height: terminalPosition.size.height)
    } else {
      ghostRect = NSRect(
        x: appWindowPosition.origin.x - borderWidth, y: appWindowPosition.origin.y,
        width: borderWidth, height: appWindowPosition.size.height)
    }

    // Final debug print statement
    print("Calculated ghost window rect: \(ghostRect)")

    ghostRect.origin.y = NSScreen.main!.frame.height - ghostRect.origin.y - ghostRect.height  // Adjust Y-axis

    return ghostRect
  }

  @objc private func handleMousePositionCloseToTerminalBorder(_ notification: Notification) {
    guard let userInfo = notification.userInfo else { return }

    let feedbackWindowWidth: CGFloat = 17

    if let isClose = userInfo["isCloseToTerminalBorder"] as? Bool {
      self.isMouseCloseToTerminalBorder = isClose
    }

    if let border = userInfo["terminalBorder"] as? String {
      self.terminalBorderPosition = border
    } else {
      self.terminalBorderPosition = nil
    }

    // Show feedback window only if the terminal border and app relative position match
    if isMouseCloseToTerminalBorder
      && (terminalBorderPosition == appRelativePositionToTerminalWindow)
    {
      // Determine the position of the feedback window based on the side
      let feedbackXPosition: CGFloat
      if terminalBorderPosition == "left" {
        feedbackXPosition = self.frame.maxX  // Right side of the GhostWindow
      } else {
        feedbackXPosition = self.frame.minX - feedbackWindowWidth  // Left side of the GhostWindow
      }

      // Create and show mouseCloseToBorderFeedbackWindow
      if mouseCloseToBorderFeedbackWindow == nil {
        let feedbackRect = NSRect(
          x: feedbackXPosition, y: self.frame.minY, width: feedbackWindowWidth,
          height: self.frame.height)
        mouseCloseToBorderFeedbackWindow = NSWindow(
          contentRect: feedbackRect, styleMask: .borderless, backing: .buffered, defer: false)
        mouseCloseToBorderFeedbackWindow?.isOpaque = false
        mouseCloseToBorderFeedbackWindow?.backgroundColor = NSColor(
          calibratedRed: 8 / 255, green: 133 / 255, blue: 245 / 255, alpha: 0.2)
        mouseCloseToBorderFeedbackWindow?.level = .floating
        mouseCloseToBorderFeedbackWindow?.hasShadow = false
        mouseCloseToBorderFeedbackWindow?.makeKeyAndOrderFront(nil)
      } else {
        let feedbackRect = NSRect(
          x: feedbackXPosition, y: self.frame.minY, width: feedbackWindowWidth,
          height: self.frame.height)
        mouseCloseToBorderFeedbackWindow?.setFrame(feedbackRect, display: true)
      }
    } else {
      // Hide mouseCloseToBorderFeedbackWindow
      mouseCloseToBorderFeedbackWindow?.orderOut(nil)
      mouseCloseToBorderFeedbackWindow = nil
    }

    print(
      "Mouse is close to terminal border: \(isMouseCloseToTerminalBorder), at border: \(terminalBorderPosition ?? "nil")"
    )
  }

  func hideMouseCloseToBorderFeedbackWindow() {
    mouseCloseToBorderFeedbackWindow?.orderOut(nil)
    mouseCloseToBorderFeedbackWindow = nil
  }
}

class ShellMateWindowTrackingDelegate: NSObject {
  private var localMouseEventMonitor: Any?
  private var windowPositionDelegate: WindowPositionManager?
  private var terminalObserver: AXObserver?
  private var ghostWindowController: NSWindowController?
  private let mousePositionTrackingManager = MousePositionTrackingManager()  // Instantiate the new class
  private var initialWindowPosition: NSRect?
  private var isDraggingWindow = false

  func setWindowPositionDelegate(_ delegate: WindowPositionManager) {
    self.windowPositionDelegate = delegate
    mousePositionTrackingManager.setWindowPositionDelegate(delegate)
  }

  private func monitorLocalMouseEvents() {
    localMouseEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [
      .leftMouseDown, .leftMouseUp,
    ]) { [weak self] event in
      self?.handleLocalMouseEvent(event)
      return event
    }
  }

  func startTracking() {
    monitorLocalMouseEvents()
  }

  func stopTracking() {
    stopMonitoringLocalMouseEvents()
  }

  private func stopMonitoringLocalMouseEvents() {
    if let monitor = localMouseEventMonitor {
      NSEvent.removeMonitor(monitor)
      localMouseEventMonitor = nil
    }
  }

  private func handleLocalMouseEvent(_ event: NSEvent) {
    guard let window = event.window, window.title == "ShellMate" else {
      return
    }
    switch event.type {
    case .leftMouseDown:
      handleMouseDown(event)
    case .leftMouseUp:
      handleMouseUp(event)
    default:
      break
    }
  }

  private func handleMouseDown(_ event: NSEvent) {
    print("Mouse button pressed.")
    isDraggingWindow = false
    initialWindowPosition = getAppWindowPosition()

    // Get the mouse click location
    let clickLocation = event.locationInWindow
    print("Mouse click y-coordinate: \(clickLocation.y)")

    if isClickInTitleBar(event, clickLocation: clickLocation) {
      print("Mouse click was in the top window bar.")
    } else {
      print("Mouse click was outside the top window bar.")
      return
    }

    // Initialize ghost window if needed
    if let appWindowPosition = initialWindowPosition {
      initializeGhostWindowIfNeeded(appWindowPosition: appWindowPosition)
    }

    setupObserverForShellMate()
  }

  private func isClickInTitleBar(_ event: NSEvent, clickLocation: NSPoint) -> Bool {
    // Assuming the title bar height is 22 points + some extra
    let titleBarHeight: CGFloat = 35.0

    // Get the window height
    guard let windowHeight = event.window?.frame.size.height else {
      return false
    }
    // Check if the click is within the title bar area
    // This check prevents a bug where clicks on buttons don't trigger mouse up events, causing the tracking process to start and never end.
    return clickLocation.y >= windowHeight - titleBarHeight
  }

  private func handleMouseUp(_ event: NSEvent) {
    let appWindowPosition = getAppWindowPosition()
    if let terminalWindowPosition = getTerminalWindowPositionAndSize() {
      updateGhostWindowPosition(
        appWindowPosition: appWindowPosition, terminalWindowPosition: terminalWindowPosition)
      handleRelativePositionUpdate(
        appWindowPosition: appWindowPosition, terminalWindowPosition: terminalWindowPosition)
    }
    removeObserverForShellMate()
    hideGhostWindow()
    mousePositionTrackingManager.stopMonitoringMousePositionEvents()
    // Hide mouseCloseToBorderFeedbackWindow on mouse up
    if let ghostWindow = GhostWindow.sharedInstance {
      ghostWindow.hideMouseCloseToBorderFeedbackWindow()
    }
  }

  private func getAppWindowPosition() -> NSRect? {
    return NSApplication.shared.windows.first?.frame
  }

  private func getTerminalWindowPositionAndSize() -> (position: CGPoint, size: CGSize)? {
    if let positionDelegate = windowPositionDelegate,
      let result = positionDelegate.getTerminalWindowPositionAndSize()
    {
      return (result.position, result.size)
    }
    return nil
  }

  private func printAppWindowPosition(_ appWindowPosition: NSRect?) {
    guard let appWindowPosition = appWindowPosition else { return }
    let position = appWindowPosition.origin
    let size = appWindowPosition.size
    print("App window position: \(position), Size: \(size)")
  }

  private func handleRelativePositionUpdate(
    appWindowPosition: NSRect?, terminalWindowPosition: (position: CGPoint, size: CGSize)
  ) {
    let relativePosition = checkWindowPositionRelativeToTerminal(
      appWindowPosition: appWindowPosition, terminalWindowPosition: terminalWindowPosition.position,
      terminalWindowSize: terminalWindowPosition.size)
    print("Relative Position: \(relativePosition)")
    postWindowAttachmentPositionDidChangeNotification(position: relativePosition.lowercased())
  }

  private func postWindowAttachmentPositionDidChangeNotification(position: String) {
    let userInfo: [String: String] = [
      "position": position,
      "source": "dragging",
    ]
    NotificationCenter.default.post(
      name: .windowAttachmentPositionDidChange, object: nil, userInfo: userInfo)
  }

  private func setupObserverForShellMate() {
    guard
      let shellMateApp = NSWorkspace.shared.runningApplications.first(where: {
        $0.localizedName == "ShellMate"
      })
    else {
      print("ShellMate application is not running.")
      return
    }

    var observer: AXObserver?
    let pid = shellMateApp.processIdentifier
    let callback: AXObserverCallback = { (observer, element, notification, refcon) in
      print("Observer callback triggered for ShellMate: \(notification).")
      let delegate = Unmanaged<ShellMateWindowTrackingDelegate>.fromOpaque(refcon!)
        .takeUnretainedValue()
      delegate.handleAppWindowPositionChange(notification: notification as CFString)
    }

    let result = AXObserverCreate(pid_t(pid), callback, &observer)

    if result != .success {
      print("Failed to create AXObserver for ShellMate. Error: \(result.rawValue)")
      return
    }

    self.terminalObserver = observer

    guard let observer = observer else {
      print("Failed to create AXObserver.")
      return
    }

    let shellMateElement = AXUIElementCreateApplication(pid_t(pid))
    let runLoopSource = AXObserverGetRunLoopSource(observer)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
    print("Observer added to run loop for ShellMate.")

    let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    addNotifications(to: observer, element: shellMateElement, refcon: refcon)
  }

  private func removeObserverForShellMate() {
    guard let observer = terminalObserver else { return }
    let runLoopSource = AXObserverGetRunLoopSource(observer)
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
    terminalObserver = nil
    print("Observer removed for ShellMate.")
  }

  private func addNotifications(
    to observer: AXObserver, element: AXUIElement, refcon: UnsafeMutableRawPointer
  ) {
    let notifications = [
      kAXMovedNotification as CFString,
      kAXResizedNotification as CFString,
    ]

    for notification in notifications {
      let result = AXObserverAddNotification(observer, element, notification, refcon)
      if result != .success {
        print("Failed to add \(notification) notification to observer. Error: \(result.rawValue)")
      }
    }
  }

  private func handleAppWindowPositionChange(notification: CFString) {
    let appWindowPosition = getAppWindowPosition()
    if notification == kAXResizedNotification as CFString {
      print("Resize detected.")
      handleMouseUp(NSEvent())
    } else if let initialPosition = initialWindowPosition, initialPosition != appWindowPosition {
      // Detect drag and execute default actions
      if !isDraggingWindow {
        isDraggingWindow = true
        if let terminalWindowPosition = getTerminalWindowPositionAndSize() {
          createAndShowGhostWindow(
            appWindowPosition: appWindowPosition, terminalWindowPosition: terminalWindowPosition)
        }
        mousePositionTrackingManager.startMonitoringMousePositionEvents()
      } else {
        // Update ghost window position during drag
        if let terminalWindowPosition = getTerminalWindowPositionAndSize() {
          postGhostWindowStateNotification(
            action: "update", appWindowPosition: appWindowPosition,
            terminalWindowPosition: terminalWindowPosition)
        }
      }
    }
  }

  private func printTerminalWindowPosition(
    _ terminalWindowPosition: (position: CGPoint, size: CGSize)
  ) {
    print(
      "Terminal window position: \(terminalWindowPosition.position), Size: \(terminalWindowPosition.size)"
    )
  }

  private func hideGhostWindow() {
    NotificationCenter.default.post(
      name: .ghostWindowStateDidChange, object: nil, userInfo: ["action": "hide"])
    ghostWindowController = nil
  }

  private func updateGhostWindowPosition(
    appWindowPosition: NSRect?, terminalWindowPosition: (position: CGPoint, size: CGSize)
  ) {
    guard let appWindowPosition = appWindowPosition else { return }

    let userInfo: [String: Any] = [
      "action": "update",
      "appWindowPosition": appWindowPosition,
      "terminalPosition": terminalWindowPosition,
    ]

    NotificationCenter.default.post(
      name: .ghostWindowStateDidChange, object: nil, userInfo: userInfo)
  }

  private func postGhostWindowStateNotification(
    action: String, appWindowPosition: NSRect?,
    terminalWindowPosition: (position: CGPoint, size: CGSize)
  ) {
    guard let appWindowPosition = appWindowPosition else { return }

    let userInfo: [String: Any] = [
      "action": action,
      "appWindowPosition": appWindowPosition,
      "terminalPosition": terminalWindowPosition,
    ]

    NotificationCenter.default.post(
      name: .ghostWindowStateDidChange, object: nil, userInfo: userInfo)
  }

  private func createAndShowGhostWindow(
    appWindowPosition: NSRect?, terminalWindowPosition: (position: CGPoint, size: CGSize)
  ) {
    guard let appWindowPosition = appWindowPosition else { return }

    let ghostWindow = GhostWindow.getInstance(appWindowPosition: appWindowPosition)

    // Ensure the ghost window is immediately set up and visible
    if ghostWindowController == nil {
      ghostWindowController = NSWindowController(window: ghostWindow)
      ghostWindowController?.showWindow(nil)
    }

    let userInfo: [String: Any] = [
      "action": "show",
      "appWindowPosition": appWindowPosition,
      "terminalPosition": terminalWindowPosition,
    ]

    NotificationCenter.default.post(
      name: .ghostWindowStateDidChange, object: nil, userInfo: userInfo)
  }

  private func initializeGhostWindowIfNeeded(appWindowPosition: NSRect) {
    if ghostWindowController == nil {
      let ghostWindow = GhostWindow.getInstance(appWindowPosition: appWindowPosition)
      ghostWindowController = NSWindowController(window: ghostWindow)
    }
  }
}

class MousePositionTrackingManager {
  private var localMousePositionEventMonitor: Any?
  private var windowPositionDelegate: WindowPositionManager?
  private var mousePositionDebounceInterval: TimeInterval = 0.1
  private var lastMousePositionEventTime: Date = Date.distantPast

  func setWindowPositionDelegate(_ delegate: WindowPositionManager) {
    self.windowPositionDelegate = delegate
  }

  func startMonitoringMousePositionEvents() {
    localMousePositionEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [
      .mouseMoved, .leftMouseDragged,
    ]) { [weak self] event in
      self?.handleMousePositionEvent(event)
      return event
    }
  }

  func stopMonitoringMousePositionEvents() {
    if let localMonitor = localMousePositionEventMonitor {
      NSEvent.removeMonitor(localMonitor)
      localMousePositionEventMonitor = nil
    }
  }

  private func handleMousePositionEvent(_ event: NSEvent) {
    let currentTime = Date()
    guard currentTime.timeIntervalSince(lastMousePositionEventTime) > mousePositionDebounceInterval
    else {
      return
    }

    lastMousePositionEventTime = currentTime

    let mouseLocation = NSEvent.mouseLocation  // Get the global mouse location
    print("Mouse position: \(mouseLocation)")

    if let terminalWindowPosition = getTerminalWindowPositionAndSize() {
      let distanceToLeftBorder = abs(mouseLocation.x - terminalWindowPosition.position.x)
      let distanceToRightBorder = abs(
        mouseLocation.x - (terminalWindowPosition.position.x + terminalWindowPosition.size.width))

      var isClose = false
      var border: String? = nil

      if distanceToLeftBorder <= 20 {
        print("Mouse is within 20 pixels of the left border of the terminal window.")
        isClose = true
        border = "left"
      } else if distanceToRightBorder <= 20 {
        print("Mouse is within 20 pixels of the right border of the terminal window.")
        isClose = true
        border = "right"
      }

      // Post the notification
      NotificationCenter.default.post(
        name: .mousePositionCloseToTerminalBorder, object: nil,
        userInfo: ["isCloseToTerminalBorder": isClose, "terminalBorder": border ?? ""])
    }
  }

  private func getTerminalWindowPositionAndSize() -> (position: CGPoint, size: CGSize)? {
    guard let delegate = windowPositionDelegate else { return nil }
    if let result = delegate.getTerminalWindowPositionAndSize() {
      return (result.position, result.size)
    }
    return nil
  }
}

func checkWindowPositionRelativeToTerminal(
  appWindowPosition: NSRect?, terminalWindowPosition: CGPoint, terminalWindowSize: CGSize
) -> String {
  guard let appWindowPosition = appWindowPosition else { return "Unknown" }

  let appWindowCenterX = appWindowPosition.origin.x + (appWindowPosition.size.width / 2)
  let terminalWindowLeftX = terminalWindowPosition.x
  let terminalWindowRightX = terminalWindowPosition.x + terminalWindowSize.width
  let halfAppWidth = appWindowPosition.size.width / 1.3

  // Check if the app window is in the 'float' state
  if appWindowCenterX < terminalWindowLeftX - halfAppWidth
    || appWindowCenterX > terminalWindowRightX + halfAppWidth
  {
    return "float"
  }

  // Determine relative position
  let terminalWindowCenterX = terminalWindowPosition.x + (terminalWindowSize.width / 2)
  print("App window center      X: \(appWindowCenterX)")
  print("Terminal window center X: \(terminalWindowCenterX)")

  if appWindowCenterX < terminalWindowCenterX {
    return "left"
  } else {
    return "right"
  }
}
