//
//
//  OnboardingViewModel.swift
//  ShellMate
//
//  Created by Daniel Delattre on 18/07/24.
//

import Foundation
import SwiftUI

class OnboardingStateManager: ObservableObject {
    static let shared = OnboardingStateManager()

    @AppStorage("stepCompletionStatus") private var stepCompletionStatusData: String = ""
    
    @Published var stepCompletionStatus: [Int: Bool] = [1: false, 2: false, 3: false, 4: false] {
        didSet {
            // Serialize the dictionary to JSON and store it in AppStorage
            do {
                let data = try JSONEncoder().encode(stepCompletionStatus)
                stepCompletionStatusData = String(data: data, encoding: .utf8) ?? ""
            } catch {
                print("Failed to encode step completion status: \(error)")
            }
        }
    }

    private init() {
        loadStepCompletionStatus()
    }

    private func loadStepCompletionStatus() {
        // Load step completion status from AppStorage
        if let data = stepCompletionStatusData.data(using: .utf8) {
            do {
                let decodedStatus = try JSONDecoder().decode([Int: Bool].self, from: data)
                stepCompletionStatus = decodedStatus
            } catch {
                print("Failed to decode step completion status during initialization: \(error)")
            }
        }
    }

    func markAsCompleted(step: Int) {
        guard step >= 1 && step <= 4 else { return }
        
        if stepCompletionStatus[step] == false {
            // Notify that the next onboarding pro tip should be shown only if the current step is less than 3
            if step < 3 {
                let nextStep = step + 1
                NotificationCenter.default.post(name: .forwardOnboardingStepToAppViewModel, object: nil, userInfo: ["newStep": nextStep])
                MixpanelHelper.shared.trackEvent(name: "onboardingStep\(nextStep)FlowShown")
            } else if step == 4 { // This is automatically completed when triggered so we just want to show the banner without any action necessary
                MixpanelHelper.shared.trackEvent(name: "onboardingStep\(step)FlowShown")
                NotificationCenter.default.post(name: .forwardOnboardingStepToAppViewModel, object: nil, userInfo: ["newStep": step])
            }
            
            stepCompletionStatus[step] = true
            MixpanelHelper.shared.trackEvent(name: "onboardingStep\(step)FlowCompleted")
        }
    }

    func isStepCompleted(step: Int) -> Bool {
        return stepCompletionStatus[step] ?? false
    }
}

func getOnboardingSmCommand() -> String {
    // Function to return the onboarding command text
    return "how can I display a calendar?"
}
