//
//  HistoryView.swift
//  ShellBuddy
//
//  Created by Daniel Delattre on 22/05/24.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        VStack {
            Text("History")
                .font(.title)
                .padding(.top, 20)
            
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                }
            }
        }
    }
}
