//
//  EmptyStateViewModel.swift
//  ShellMate
//
//  Created by Daniel Delattre on 31/08/24.
//

import Foundation

class EmptyStateViewModel {
    static let shared = EmptyStateViewModel()

    let emptyStateData: [[String: String]]

    private init() {
        self.emptyStateData = EmptyStateMessages.messages
    }

    func getRandomMessage() -> [String: String]? {
        return emptyStateData.randomElement()
    }
}
