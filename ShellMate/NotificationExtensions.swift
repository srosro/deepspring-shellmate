//
//  NotificationExtensions.swift
//  ShellMate
//
//  Created by Daniel Delattre on 24/06/24.
//

import Foundation

extension Notification.Name {
    static let terminalWindowIdDidChange = Notification.Name("terminalWindowIdDidChange")
    static let terminalContentChangeStarted = Notification.Name("terminalContentChangeStarted")
    static let terminalContentChangeEnded = Notification.Name("terminalContentChangeEnded")
    
    /// Notification to indicate the status of suggestion generation.
    /// userInfo dictionary should contain:
    /// - "identifier": String
    /// - "isGeneratingSuggestion": Bool
    static let suggestionGenerationStatusChanged = Notification.Name("suggestionGenerationStatusChanged")

    /// Notification to request analysis of terminal content.
    /// userInfo dictionary should contain:
    /// - "text": String
    /// - "currentTerminalWindowID": String
    /// - "source": String (e.g., "highlighted" or "terminalContent")
    /// - "changeIdentifiedAt": Double (current timestamp in seconds)
    static let requestTerminalContentAnalysis = Notification.Name("requestTerminalContentAnalysis")
    
    /// Notification to send the current active terminal line for processing.
    /// userInfo dictionary should contain:
    /// - "activeLine": String (the last line of the terminal text)
    static let terminalActiveLineChanged = Notification.Name("terminalActiveLineChanged")
}
