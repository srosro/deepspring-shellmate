//
//  BannersView.swift
//  ShellMate
//
//  Created by Daniel Delattre on 31/08/24.
//

import SwiftUI

struct BannersView: View {
  @ObservedObject private var updateShellProfileViewModel = UpdateShellProfileViewModel.shared
  @ObservedObject private var chatWithMakersViewModel = ChatWithMakersViewModel.shared

  let scrollToFixingCommand: (ScrollViewProxy, String) -> Void
  let scrollView: ScrollViewProxy

  var body: some View {
    if updateShellProfileViewModel.shouldShowUpdateShellProfileBanner() {
      UpdateShellProfile(
        scrollToFixingCommand: scrollToFixingCommand,
        scrollView: scrollView
      )
    } else if chatWithMakersViewModel.shouldShowBanner {
      ChatWithMakersView()
    } else {
      Divider().padding(.top, 5)
    }
  }
}
