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
    
    /// Notification to indicate the window attachment position has changed.
    /// userInfo dictionary should contain:
    /// - "position": String (the new window attachment position, e.g., "left", "right", "float")
    /// - "source": String (the source of the change, e.g., "dragging", "config")
    static let windowAttachmentPositionDidChange = Notification.Name("windowAttachmentPositionDidChange")
}
