//
//  NotificationExtensions.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 24/06/24.
//

import Foundation

extension Notification.Name {
    static let terminalWindowIdDidChange = Notification.Name("terminalWindowIdDidChange")
    static let terminalContentChangeStarted = Notification.Name("terminalContentChangeStarted")
    static let terminalContentChangeEnded = Notification.Name("terminalContentChangeEnded")
    
    /// Notification to request analysis of terminal content.
    /// userInfo dictionary should contain:
    /// - "text": String
    /// - "currentTerminalWindowID": String
    /// - "source": String (e.g., "highlighted" or "terminalContent")
    static let requestTerminalContentAnalysis = Notification.Name("requestTerminalContentAnalysis")
}
