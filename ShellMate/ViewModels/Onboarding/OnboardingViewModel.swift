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

  @Published var stepCompletionStatus: [Int: Bool] = [
    1: false, 2: false, 3: false, 4: false, 5: false,
  ]
  {
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
    switch step {
    case 1, 2:
      if stepCompletionStatus[step] == false {
        let nextStep = step + 1
        NotificationCenter.default.post(
          name: .forwardOnboardingStepToAppViewModel,
          object: nil,
          userInfo: ["newStep": nextStep]
        )
        MixpanelHelper.shared.trackEvent(name: "onboardingStep\(nextStep)FlowShown")
        stepCompletionStatus[step] = true
        MixpanelHelper.shared.trackEvent(name: "onboardingStep\(step)FlowCompleted")
      }

    case 3:
      if stepCompletionStatus[step] == false {
        stepCompletionStatus[step] = true
        MixpanelHelper.shared.trackEvent(name: "onboardingStep\(step)FlowCompleted")
      }

    case 4, 5:
      if stepCompletionStatus[step] == false {
        MixpanelHelper.shared.trackEvent(name: "onboardingStep\(step)FlowShown")
        NotificationCenter.default.post(
          name: .forwardOnboardingStepToAppViewModel,
          object: nil,
          userInfo: ["newStep": step]
        )
        stepCompletionStatus[step] = true
        MixpanelHelper.shared.trackEvent(name: "onboardingStep\(step)FlowCompleted")
      }

    case 6:
      // No need to check for completion status as this chould be shown multiple times
      MixpanelHelper.shared.trackEvent(name: "proTipProvideContextBannerShown")
      NotificationCenter.default.post(
        name: .forwardOnboardingStepToAppViewModel,
        object: nil,
        userInfo: ["newStep": step]
      )

    default:
      break
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
