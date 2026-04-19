//
//  ContentView.swift
//  tickr
//
//  Created by Alex Morrison on 16/4/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var isShowingSplash = true
    @State private var splashVisible = false

    var body: some View {
        ZStack {
            RootTabView()

            if isShowingSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .opacity(splashVisible ? 1 : 0)
                    .zIndex(1)
            }
        }
        .task {
            guard isShowingSplash else { return }

            withAnimation(.easeOut(duration: 0.18)) {
                splashVisible = true
            }

            try? await Task.sleep(for: .milliseconds(900))

            withAnimation(.easeInOut(duration: 0.22)) {
                splashVisible = false
            }

            try? await Task.sleep(for: .milliseconds(220))
            isShowingSplash = false
        }
    }
}

#Preview {
    ContentView()
}
