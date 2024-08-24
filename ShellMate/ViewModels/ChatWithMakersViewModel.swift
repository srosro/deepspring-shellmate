//
//  ChatWithMakersViewModel.swift
//  ShellMate
//
//  Created by Daniel Delattre on 24/08/24.
//

import Foundation
import Combine

class ChatWithMakersViewModel: ObservableObject {
    @Published private(set) var shouldShowBanner: Bool = false
    private var isCorrectTimeToShowBanner: Bool = false
    private var hasUserClosedBanner: Bool = false
    private var timer: Timer?
    
    init() {
        checkIfShouldShowBanner()
        startTimer() // Start the timer when the view model is initialized
    }
    
    deinit {
        timer?.invalidate() // Invalidate the timer when the view model is deallocated
    }
    
    func checkIfShouldShowBanner() {
        print("DANBUG: checking if should show banner (chat)")
        // Check if it's the right time to show the banner
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        
        let currentDate = Date()
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: currentDate)
        
        guard let weekday = components.weekday, let hour = components.hour, let minute = components.minute else {
            isCorrectTimeToShowBanner = false
            updateBannerVisibility()
            return
        }
        
        // Check if today is Saturday (in Swift, Sunday is 1, so Saturday is 7) and minute is 24
        if weekday == 7 && hour == 14 && minute == 24 {
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
