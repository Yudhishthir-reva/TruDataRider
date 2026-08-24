//
//  PlaceholderScreen.swift
//  TrudataRider
//

import SwiftUI

struct PlaceholderScreen: View {
    let title: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "DEE6F8"), Color(hex: "E7EBEF")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 42))
                    .foregroundStyle(DashboardTheme.primaryBlue)
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Text("This screen will be added next, matching the Android flow.")
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
