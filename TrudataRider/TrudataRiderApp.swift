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

    var body: some Scene {
        WindowGroup {
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
            .handleNoInternet()
            .preferredColorScheme(.light)
            .onAppear {
                UIApplication.shared.keyWindow?.enableTapToDismissKeyboard()
            }
        }
    }
}
