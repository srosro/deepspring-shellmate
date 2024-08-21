//
//  OnboardingView.swift
//  ShellMate
//
//  Created by Daniel Delattre on 18/07/24.
//


import SwiftUI

struct OnboardingView: View {
    var currentStep: Int

    var body: some View {
        VStack {
            if currentStep == 1 {
                OnboardingStep1View()
                    .padding(.top, 10)
            } else if currentStep == 2 {
                OnboardingStep2View()
            } else if currentStep == 3 {
                OnboardingStep3View()
                    .padding(.bottom, 10)
            }
        }
    }
}


struct OnboardingContainerView<Content: View>: View {
    let header: String
    let content: Content

    init(header: String, @ViewBuilder content: () -> Content) {
        self.header = header
        self.content = content()
    }

    var body: some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb") // Assuming "lightbulb" is the correct icon
                        .foregroundColor(Color.blue) // Adjust color as needed
                    Text("Pro-tip: \(header)")
                        .font(.body)
                        .fontWeight(.bold)
                }

                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(LinearGradient(
                        gradient: Gradient(colors: [AppColors.gradientLightBlue, AppColors.gradientPurple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}


struct OnboardingStep1View: View {
    var body: some View {
        OnboardingContainerView(header: "Ask questions") {

            Text("Use \"sm\" to ask questions in your terminal with natural text.")
                .font(.body)
                .padding(.bottom, 5)

            VStack(alignment: .leading) {
                Text("Try it yourself:")
                    .font(.body)
                    .fontWeight(.bold)
                    .padding(.bottom, 5)
                
                HStack(alignment: .top, spacing: 0) {
                    Text("1")
                        .font(.system(.body, design: .monospaced))
                    (Text(". Type: ")
                        .font(.body) +
                    Text("sm \"\(getOnboardingSmCommand())\"")
                        .foregroundColor(Color.Text.purple)
                        .font(.body)
                        .fontWeight(.bold)
                     +
                    Text(" into your terminal.")
                        .font(.body))
                }
                .padding(.leading, 4)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
                
                HStack(alignment: .top, spacing: 0) {
                    Text("2")
                        .font(.system(.body, design: .monospaced))
                    Text(". Execute the command line")
                        .font(.body)
                }
                .padding(.leading, 4)
            }
        }
    }
}

struct OnboardingStep2View: View {
    var body: some View {
        OnboardingContainerView(header: "Insert suggestions") {

            Text("Insert any suggestion with the shortcut \"sm x.x\"")
                .font(.body)
                .padding(.bottom, 5)

            VStack(alignment: .leading) {
                HStack(alignment: .top, spacing: 0) {
                    Text("1")
                        .font(.system(.body, design: .monospaced))
                    (Text(". Type ")
                        .font(.body) +
                     Text("sm 1 ")
                        .font(.body)
                        .foregroundColor(Color.Text.purple)
                        .fontWeight(.bold) +
                     Text("or ")
                        .font(.body) +
                     Text("sm 1.1 ")
                        .font(.body)
                        .foregroundColor(Color.Text.purple)
                        .fontWeight(.bold) +
                     Text("to insert the suggestion above.")
                        .font(.body))
                }
                .padding(.leading, 4)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
                
                HStack(alignment: .top, spacing: 0) {
                    Text("2")
                        .font(.system(.body, design: .monospaced))
                    Text(". Execute the command to paste the suggestion.")
                        .font(.body)
                }
                .padding(.leading, 4)
            }
        }
    }
}

struct OnboardingStep3View: View {
    var body: some View {
        OnboardingContainerView(header: "Review and execute") {

            Text("Review before executing inserted suggestions. You should never run commands you don’t know.")
                .font(.body)
                .padding(.bottom, 5)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
