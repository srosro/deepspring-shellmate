//
//  ChatWithMakersViewModel.swift
//  ShellMate
//
//  Created by Daniel Delattre on 24/08/24.
//

import Combine
import Foundation

class ChatWithMakersViewModel: ObservableObject {
  // Singleton instance
  static let shared = ChatWithMakersViewModel()

  @Published private(set) var shouldShowBanner: Bool = false
  private var isCorrectTimeToShowBanner: Bool = false
  private var hasUserClosedBanner: Bool = false
  private var timer: Timer?

  // Private initializer to enforce singleton pattern
  private init() {
    print("ChatWithMakers banner is currently disabled")
    //checkIfShouldShowBanner()
    //startTimer()  // Start the timer when the view model is initialized
  }

  deinit {
    timer?.invalidate()  // Invalidate the timer when the view model is deallocated
  }

  func checkIfShouldShowBanner() {
    // Check if it's the right time to show the banner
    var calendar = Calendar.current
    calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!

    let currentDate = Date()
    let components = calendar.dateComponents([.weekday, .hour, .minute], from: currentDate)

    guard let weekday = components.weekday, let hour = components.hour,
      let minute = components.minute
    else {
      isCorrectTimeToShowBanner = false
      updateBannerVisibility()
      return
    }

    // in Swift, Sunday is 1, so Saturday is 7
    if weekday == 1 {
      isCorrectTimeToShowBanner = true
    } else {
      isCorrectTimeToShowBanner = false
    }

    updateBannerVisibility()
  }

  func closeBanner() {
    hasUserClosedBanner = true
    updateBannerVisibility()
  }

  private func updateBannerVisibility() {
    shouldShowBanner = isCorrectTimeToShowBanner && !hasUserClosedBanner
  }

  private func startTimer() {
    // Run the check every minute
    timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
      self?.checkIfShouldShowBanner()
    }
  }
}
