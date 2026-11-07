//
//  AccountBlockedScreen.swift
//  TrudataRider
//
//  Shown when the session is cut short — an expired token, or an account that has been blocked.
//  Counts down, then drops the user back on the login screen. Mirrors Android's
//  `AccountBlockedActivity`.
//

import SwiftUI
import Combine

/// Watches API replies for the "token expired" message and ends the session when one arrives.
@MainActor
final class SessionManager: ObservableObject {

    static let shared = SessionManager()

    @Published private(set) var isBlocked = false

    private init() {}

    /// Android checks for a message that mentions both "expired" and "token"; same test here so a
    /// change on the server lands on both platforms at once.
    func checkTokenExpiry(message: String?) {
        guard let message else { return }
        let lower = message.lowercased()
        guard lower.contains("expired"), lower.contains("token") else { return }
        guard !UserDefaultManager.shared.getUserDefaultsString(key: .authToken).isEmptyString else { return }

        UserDefaultManager.shared.resetUserData()
        isBlocked = true
    }

    /// Called by the countdown when it runs out.
    func returnToLogin() {
        isBlocked = false
        AppRootManager.shared.switchToAuth()
    }
}

struct AccountBlockedScreen: View {

    var onTimeout: () -> Void

    private let countdownSeconds: Double = 5
    @State private var progress: Double = 1

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray4), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(AppTheme.brand.deep, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 120, height: 120)

                Spacer().frame(height: 24)

                Text("You have been logged out.")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 16)

                Text("You will be redirected to the login screen shortly.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
        }
        .onAppear {
            withAnimation(.linear(duration: countdownSeconds)) {
                progress = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + countdownSeconds) {
                onTimeout()
            }
        }
    }
}
