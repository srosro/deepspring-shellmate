//
//  NetworkErrorViewModel.swift
//  ShellMate
//
//  Created by Daniel Delattre on 06/09/24.
//

import Combine
import Foundation

class NetworkErrorViewModel: ObservableObject {
  static let shared = NetworkErrorViewModel()

  @Published var shouldShowNetworkError: Bool = false

  private init() {}
}
