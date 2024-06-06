import Foundation
import AppKit

func pasteClipboardContent() {
    let appleScript = """
    tell application "System Events"
        keystroke "v" using command down
    end tell
    """
    
    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: appleScript) {
        scriptObject.executeAndReturnError(&error)
    }
}

func main() {
    // Paste the clipboard content
    pasteClipboardContent()
}

// Usage
main()
