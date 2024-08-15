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

    @Published var currentStep: Int = 1 {
        didSet {
            if oldValue != currentStep {
                // currentStep has changed
                MixpanelHelper.shared.trackEvent(name: "onboardingStep\(currentStep)FlowShown")
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
        // Initialization
        NotificationCenter.default.addObserver(self, selector: #selector(handleOnboardingStepChange(_:)), name: .onboardingStepChanged, object: nil)
    }

    func getCurrentStep() -> Int {
        return currentStep
    }

    func setStep(to newStep: Int) {
        if newStep >= 1 && newStep <= 4 {
            if currentStep != newStep {
                MixpanelHelper.shared.trackEvent(name: "onboardingStep\(currentStep)FlowCompleted")
            }
            currentStep = newStep
        }
    }

    @objc private func handleOnboardingStepChange(_ notification: Notification) {
        if let newStep = notification.userInfo?["newStep"] as? Int {
            if currentStep != newStep {
                currentStep = newStep
                MixpanelHelper.shared.trackEvent(name: "onboardingStep\(newStep)FlowShown")
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .onboardingStepChanged, object: nil)
    }
}


func getOnboardingSmCommand() -> String {
    // Function to return the onboarding command text
    return "how can I see the calendar in terminal?"
}
