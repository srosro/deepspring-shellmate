//  main.swift
//  ShellMateCLI
//
//  Created by Daniel Delattre on 05/06/24.
//

import Foundation

// Main function
func smCLIMain() {
  // Get the arguments passed to the script
  let arguments = CommandLine.arguments

  // Check if the correct number of arguments is provided
  guard arguments.count == 2 else {
    print(
      """
      Wrong Usage:
      For message requests:
          sm "insert your message with quotations" (e.g., sm "How can I find my external IP address?")\n
      """)
    return
  }

  // Get the argument (message)
  // let message = arguments[1]

  // Do nothing with the message
}

// Usage
smCLIMain()
