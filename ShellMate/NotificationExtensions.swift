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
    static let updatedAppPositionAfterWindowAttachmentChange = Notification.Name("updatedAppPositionAfterWindowAttachmentChange")
    
    // Required for GhostWindow logic
    /// Notification to update the ghost window state.
    /// userInfo dictionary should contain:
    /// - "action": String (the action to perform, e.g., "update", "show", "hide")
    /// - "terminalPosition": NSRect (the new position of the ghost window, required if action is "update")
    static let ghostWindowStateDidChange = Notification.Name("ghostWindowStateDidChange")
    /// Notification to indicate the mouse position is close to a terminal window border.
    /// userInfo dictionary should contain:
    /// - "isCloseToTerminalBorder": Bool (indicates if the mouse is close to any terminal window border)
    /// - "terminalBorder": String? (the terminal window border the mouse is close to, e.g., "left", "right", or nil if not close to any border)
    static let mousePositionCloseToTerminalBorder = Notification.Name("mousePositionCloseToTerminalBorder")
    
    /// Notification to indicate the user has validated their own OpenAI API Key.
    /// userInfo dictionary should contain:
    /// - "isValid": Bool? (indicates if the API key validation was successful or `nil` if the validation state is unknown)
    static let userValidatedOwnOpenAIAPIKey = Notification.Name("userValidatedOwnOpenAIAPIKey")
    
    /// Notification to start the app initialization process (continue button from permissionsView -> change to SuggestionsView
    static let startAppInitialization = Notification.Name("startAppInitialization")
    
    /// Notification to indicate the onboarding step has changed.
    /// userInfo dictionary should contain:
    /// - "newStep": Int (the new step to set in the onboarding process)
    static let onboardingStepChanged = Notification.Name("onboardingStepChanged")
    
    /// Notification to indicate that the terminal window ID should be reinitialized.
    static let reinitializeTerminalWindowID = Notification.Name("reinitializeTerminalWindowID")
    
    /// Notification to indicate that the user has accepted to receive free credits.
    static let userAcceptedFreeCredits = Notification.Name("userAcceptedFreeCredits")
}
