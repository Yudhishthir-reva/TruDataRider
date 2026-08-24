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

    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .handleNoInternet()
        }
    }
}
