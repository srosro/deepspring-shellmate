//
//  NetworkErrorView.swift
//  ShellMate
//
//  Created by Daniel Delattre on 06/09/24.
//

import SwiftUI

struct NetworkErrorView: View {
  var body: some View {
    HStack(spacing: 8) {
      NetworkErrorTextView()

      Spacer()
    }
    .padding(.vertical, 10)
    .padding(.horizontal, 16)
    .background(Color.BG.UpdateShellProfile.red)
  }
}

struct NetworkErrorTextView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Network Error")
        .font(.body)
        .fontWeight(.semibold)
        .foregroundColor(Color.Text.white)
        .allowsHitTesting(false)  // Disable interaction for this text

      Text(
        "Please check your internet connection. If you believe this is an error, feel free to send us feedback."
      )
      .fontWeight(.regular)
      .foregroundColor(Color.Text.white)
      .lineLimit(5)  // Allow text to wrap into multiple lines
      .fixedSize(horizontal: false, vertical: true)
    }
    .font(.body)
  }
}
