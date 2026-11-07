//
//  TrudataRiderApp.swift
//  TrudataRider
//
//  Created by Reva on 21/08/26.
//

import SwiftUI

@main
struct TrudataRiderApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var rootManager = AppRootManager.shared
    @StateObject private var remoteConfig = RemoteConfigManager.shared
    @StateObject private var session = SessionManager.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    switch rootManager.currentRoot {
                    case .splash:
                        SplashScreen()
                    case .auth:
                        AuthScreen()
                    case .home:
                        HomeScreen()
                    }
                }
                .dynamicTypeSize(.large)
                .handleNoInternet()

                // Both of these sit above everything: a forced update has no way past it, and a
                // cut-short session must not leave the app usable behind the countdown.
                if let update = remoteConfig.pendingUpdate {
                    AppUpdateDialog(config: update) { remoteConfig.postponeUpdate() }
                        .transition(.opacity)
                }

                if session.isBlocked {
                    AccountBlockedScreen { session.returnToLogin() }
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: session.isBlocked)
            .preferredColorScheme(.light)
            .onAppear {
                UIApplication.shared.keyWindow?.enableTapToDismissKeyboard()
                remoteConfig.fetchAndActivate()
            }
        }
    }
}
