//
//  ShellMateWindowVisibilityService.swift
//  ShellMate
//
//  Created by Daniel Delattre on 24/09/24.
//

import Foundation
import Cocoa

class ShellMateWindowVisibilityService {
    static let shared = ShellMateWindowVisibilityService()
    
    private init() {
    }
    
    func isShellMateVisible() -> Bool {
        guard let window = NSApplication.shared.windows.first else {
            return false
        }
        
        // Check if the window is visible
        guard window.isVisible else {
            return false
        }
        
        // Check if the window is minimized
        guard !window.isMiniaturized else {
            return false
        }
        
        // Check if the window is on screen
        guard window.screen != nil else {
            return false
        }
        
        return true
    }
}
