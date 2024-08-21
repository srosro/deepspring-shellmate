//
//
//  OnboardingViewModel.swift
//  ShellMate
//
//  Created by Daniel Delattre on 18/07/24.
//

import Foundation
import SwiftUI
import Combine

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
            // Check if any step has been marked as completed
            if oldValue != stepCompletionStatus {
                checkAndTrackCompletedSteps()
            }
        }
    }
    
    @Published var showOnboarding: Bool {
        didSet {
            if oldValue != showOnboarding {
                UserDefaults.standard.set(showOnboarding, forKey: "showOnboarding")
                if !showOnboarding {
                    MixpanelHelper.shared.trackEvent(name: "onboardingModalClosed")
                }
            }
        }
    }

    private init() {
        self.showOnboarding = UserDefaults.standard.object(forKey: "showOnboarding") as? Bool ?? true
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
            stepCompletionStatus[step] = true
            MixpanelHelper.shared.trackEvent(name: "onboardingStep\(step)FlowCompleted")
            print("DANBUG: Step \(step) marked as completed. Current step completion status: \(stepCompletionStatus)")

            // Notify that the next onboarding pro tip should be shown
            let nextStep = step + 1
            NotificationCenter.default.post(name: .forwardOnboardingStepToAppViewModel, object: nil, userInfo: ["newStep": nextStep])
        }
    }


    func isStepCompleted(step: Int) -> Bool {
        return stepCompletionStatus[step] ?? false
    }

    func areAllStepsCompleted() -> Bool {
        return stepCompletionStatus.values.allSatisfy { $0 == true }
    }
    
    private func checkAndTrackCompletedSteps() {
        for (step, completed) in stepCompletionStatus {
            if completed {
                MixpanelHelper.shared.trackEvent(name: "onboardingStep\(step)FlowShown")
            }
        }
    }
}

func getOnboardingSmCommand() -> String {
    // Function to return the onboarding command text
    return "how can I display a calendar?"
}
