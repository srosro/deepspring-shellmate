//
//  ChatWithMakers.swift
//  ShellMate
//
//  Created by Daniel Delattre on 24/08/24.
//

import SwiftUI

import SwiftUI

struct ChatWithMakersBanner: View {
    @StateObject private var viewModel = ChatWithMakersViewModel()

    var body: some View {
        if viewModel.shouldShowBanner {
            ChatWithMakersView()
        }
    }
}

struct ChatWithMakersView: View {
    var body: some View {
        HStack {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("Live now: ")
                    .fontWeight(.semibold) // Make "Live now" bold
                    .foregroundColor(Color.Text.white)
                Text("Chat with the ShellMate makers")
                    .fontWeight(.regular) // Keep the rest regular
                    .foregroundColor(Color.Text.white)
            }
            .font(.body)
            .padding(.leading, 20)
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: {
                    // Add action for Join button here
                }) {
                    HStack {
                        Image("headset")
                            .resizable()
                            .renderingMode(.template) // This makes the image use the foreground color
                            .frame(width: 16, height: 16)
                            .foregroundColor(Color.Text.white) // Use the specified text white color
                        Text("Join")
                            .font(.body)
                            .fontWeight(.regular)
                            .foregroundColor(Color.Text.white) // Use the specified text white color
                    }
                    .padding(.init(top: 6, leading: 9, bottom: 6, trailing: 8))
                    .background(Color.clear) // Set background to transparent
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.Stroke.ChatWithMakers.gray, lineWidth: 1.4) // Add gray border
                    )
                }
                .buttonStyle(BorderlessButtonStyle()) // Apply borderless button style
                
                Button(action: {
                    // Add action for close button here
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.Text.white)
                        .background(
                            Color.clear // Set the background to transparent
                        )
                }
                .buttonStyle(BorderlessButtonStyle()) // Keep the button borderless
            }
            .padding(.trailing, 8)


        }
        .frame(height: 48)
        .background(Color.BG.ChatWithMakers.purple)
    }
}

