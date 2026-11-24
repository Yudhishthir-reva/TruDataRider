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

/// Ends the session the moment the server says the token is no longer good.
///
/// Two things can say that, and the backend uses both: an HTTP 401 (Laravel's auth middleware,
/// whose body is a bare `{"message": "Unauthenticated."}`), and a reply whose message spells the
/// problem out. Only the second was being watched, so a plain 401 — the common case — left the
/// user sitting on a screen whose every request was failing.
@MainActor
final class SessionManager: ObservableObject {

    static let shared = SessionManager()

    @Published private(set) var isBlocked = false

    private init() {}

    /// Wordings that mean the token is done. Android tests for "expired" and "token" together;
    /// that case is kept, with the other shapes this backend sends added beside it.
    private static let expiryPhrases = [
        "unauthenticated",
        "unauthorized",
        "token has expired",
        "token expired",
        "token is invalid",
        "invalid token",
        "token not provided",
        "token could not be parsed"
    ]

    /// A 401 is reason enough on its own — the body doesn't have to say anything useful.
    ///
    /// `sentWith` is the Authorization header the failing request carried, so a slow reply to a
    /// request made under an old token cannot sign out a session that has since been renewed.
    func handleUnauthorized(sentWith authorization: String?) {
        endSession(sentWith: authorization)
    }

    /// For replies that carry a message instead of a 401.
    func checkTokenExpiry(message: String?, sentWith authorization: String? = nil) {
        guard let message else { return }
        let lower = message.lowercased()

        let matches = Self.expiryPhrases.contains { lower.contains($0) }
            // Android's original test, kept so a server-side change lands on both platforms.
            || (lower.contains("expired") && lower.contains("token"))
        guard matches else { return }

        endSession(sentWith: authorization)
    }

    /// Clears the session and raises the blocked screen. Safe to call from several failing
    /// requests at once — only the first one does anything.
    private func endSession(sentWith authorization: String?) {
        guard !isBlocked else { return }

        // Nothing to end if the user is already signed out: a 401 on the login call itself is a
        // wrong password, not an expired session, and must not throw up the blocked screen.
        let current = UserDefaultManager.shared.authHeader["Authorization"] ?? ""
        guard !current.isEmptyString else { return }

        // A delayed response from an old login must not log out a newer session.
        if let authorization, !authorization.isEmpty, authorization != current { return }

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
