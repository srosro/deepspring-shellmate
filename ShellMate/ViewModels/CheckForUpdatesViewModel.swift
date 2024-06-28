//
//  CheckForUpdatesViewModel.swift
//  ShellMate
//
//  Created by Daniel Delattre on 28/06/24.
//

import Foundation
import Sparkle

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}
