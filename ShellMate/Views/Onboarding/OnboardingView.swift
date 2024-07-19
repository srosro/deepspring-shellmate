//
//  OnboardingView.swift
//  ShellMate
//
//  Created by Daniel Delattre on 18/07/24.
//


import SwiftUI

struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.body)
                .foregroundColor(.primary)
                .padding(5)
                .frame(width: 26, height: 26, alignment: .center)
                .background(
                    Color(NSColor.controlBackgroundColor)
                        .cornerRadius(6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary, lineWidth: 0.5)
                )
        }
        .buttonStyle(BorderlessButtonStyle())
    }
}

struct OnboardingHeader: View {
    let title: String
    let closeAction: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            CloseButton(action: closeAction)
        }
        .padding(.bottom, 20)
    }
}

struct OnboardingStep1View: View {
    @Binding var showOnboarding: Bool

    var body: some View {
        VStack(alignment: .leading) {
            OnboardingHeader(title: "Walkthrough: 1 of 3", closeAction: {
                showOnboarding = false
            })
            
            Text("Become an expert with these pro-tips")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.bottom, 6)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            Text("Use the ShellMate shortcut 'sm' directly in your terminal to ask questions with natural text.")
                .font(.body)
                .padding(.bottom, 6)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading) {
                Text("Complete the task:")
                    .font(.body)
                    .fontWeight(.bold)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(alignment: .top, spacing: 1) {
                    Text("1.")
                        .font(.system(.body, design: .monospaced))
                    (Text("Type: '")
                        .font(.body) +
                    Text("sm \"\(getOnboardingSmCommand())\"")
                        .font(.body)
                        .fontWeight(.bold) +
                    Text("' into your terminal command line. You can also hit the command below to copy the text.")
                        .font(.body))
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 4)
                
                HStack(alignment: .top, spacing: 1) {
                    Text("2.")
                        .font(.system(.body, design: .monospaced))
                    Text("Execute the command line")
                        .font(.body)
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 4)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct OnboardingStep2View: View {
    @Binding var showOnboarding: Bool

    var body: some View {
        VStack(alignment: .leading) {
            OnboardingHeader(title: "Walkthrough: 2 of 3", closeAction: {
                showOnboarding = false
            })
            
            Text("Become an expert with these pro-tips")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.bottom, 6)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            Text("Insert any suggestion with the shortcut 'sm x.x'")
                .font(.body)
                .padding(.bottom, 6)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading) {
                Text("Complete the task:")
                    .font(.body)
                    .fontWeight(.bold)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(alignment: .top, spacing: 1) {
                    Text("1.")
                        .font(.system(.body, design: .monospaced))
                    (Text("Type the following command into your terminal: '")
                        .font(.body) +
                     Text("sm 2")
                        .font(.body)
                        .fontWeight(.bold) +
                     Text("' or '")
                        .font(.body) +
                     Text("sm 2.1")
                        .font(.body)
                        .fontWeight(.bold) +
                     Text("'")
                        .font(.body))
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 4)
                
                HStack(alignment: .top, spacing: 1) {
                    Text("2.")
                        .font(.system(.body, design: .monospaced))
                    Text("Execute the command to paste the suggestion")
                        .font(.body)
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 4)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct OnboardingStep3View: View {
    @Binding var showOnboarding: Bool

    var body: some View {
        VStack(alignment: .leading) {
            OnboardingHeader(title: "Walkthrough: 3 of 3", closeAction: {
                showOnboarding = false
            })
            
            Text("Become an expert with these pro-tips")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.bottom, 6)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            Text("Review and edit inserted suggestions. You should never run commands you don’t know.")
                .font(.body)
                .padding(.bottom, 6)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading) {
                Text("Complete the task:")
                    .font(.body)
                    .fontWeight(.bold)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(alignment: .top, spacing: 1) {
                    Text("1.")
                        .font(.system(.body, design: .monospaced))
                    Text("Review the inserted command")
                        .font(.body)
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 4)
                
                HStack(alignment: .top, spacing: 1) {
                    Text("2.")
                        .font(.system(.body, design: .monospaced))
                    Text("Execute the command line")
                        .font(.body)
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 4)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct OnboardingCompleteView: View {
    @Binding var showOnboarding: Bool

    var body: some View {
        VStack(alignment: .leading) {
            OnboardingHeader(title: "Walkthrough: Complete", closeAction: {
                showOnboarding = false
            })
            
            Text("You're ready!")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.bottom, 6)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            Text("Let us know if you run into any issues by sending us feedback-- you can find a contact link in the menu bar. Otherwise, enjoy!")
                .font(.body)
                .padding(.bottom, 6)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading) {
                Text("Bonus tip:")
                    .font(.body)
                    .fontWeight(.bold)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("You can highlight any text in your terminal to focus your suggestions.")
                    .font(.body)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct OnboardingView: View {
    @ObservedObject private var stateManager = OnboardingStateManager.shared

    var body: some View {
        if stateManager.showOnboarding {
            VStack {
                if stateManager.currentStep == 1 {
                    OnboardingStep1View(showOnboarding: $stateManager.showOnboarding)
                } else if stateManager.currentStep == 2 {
                    OnboardingStep2View(showOnboarding: $stateManager.showOnboarding)
                } else if stateManager.currentStep == 3 {
                    OnboardingStep3View(showOnboarding: $stateManager.showOnboarding)
                } else {
                    OnboardingCompleteView(showOnboarding: $stateManager.showOnboarding)
                }
            }
            HStack {
                if stateManager.currentStep > 1 {
                    Button("Back") {
                        stateManager.goToPreviousStep()
                    }
                }
                Spacer()
                if stateManager.currentStep < 4 {
                    Button("Next") {
                        stateManager.goToNextStep()
                    }
                }
            }
        }
    }
}
