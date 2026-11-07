//
//  AppDelegate.swift
//  TrudataRider
//

import UIKit
import UserNotifications
import IQKeyboardManagerSwift
import IQKeyboardToolbarManager
import FirebaseCore
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        IQKeyboardManager.shared.isEnabled = true
        IQKeyboardManager.shared.resignOnTouchOutside = true
        IQKeyboardToolbarManager.shared.isEnabled = true

        // Configure Firebase
        FirebaseApp.configure()

        // Set messaging delegate
        Messaging.messaging().delegate = self

        // Register for push notifications
        registerForPushNotifications()
        fetchFCMToken()

        NetworkMonitor.shared.start()
        return true
    }

    func registerForPushNotifications() {
        UNUserNotificationCenter.current().delegate = self

        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                if let error = error {
                    print("Push notification authorization error: \(error.localizedDescription)")
                }
                print("Push notification permission granted: \(granted)")
            }
        )

        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        #if DEBUG
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("APNs Device Token: \(token)")
        #endif
        fetchFCMToken()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        fetchFCMToken()
    }

    private func fetchFCMToken() {
        Messaging.messaging().token { token, error in
            #if DEBUG
            if let error {
                print("Failed to fetch FCM token: \(error.localizedDescription)")
            }
            #endif
            guard let token, !token.isEmpty else { return }
            DispatchQueue.main.async {
                self.storeFCMTokenIfNeeded(token)
            }
        }
    }

    private func storeFCMTokenIfNeeded(_ token: String) {
        guard UserDefaultManager.shared.fcmToken != token else { return }
        UserDefaultManager.shared.fcmToken = token
        NotificationCenter.default.post(
            name: .fcmTokenDidUpdate,
            object: nil,
            userInfo: ["token": token]
        )
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("Received remote notification: \(userInfo)")
        NotificationCenter.default.post(name: .didReceivePushNotification, object: userInfo)
        completionHandler(.newData)
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, !fcmToken.isEmpty else { return }
        #if DEBUG
        print("FCM Registration Token: \(fcmToken)")
        #endif
        DispatchQueue.main.async {
            self.storeFCMTokenIfNeeded(fcmToken)
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("Foreground notification received: \(userInfo)")
        NotificationCenter.default.post(name: .didReceivePushNotification, object: userInfo)
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge, .list])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("User tapped notification: \(userInfo)")
        NotificationCenter.default.post(name: .didReceivePushNotification, object: userInfo)
        completionHandler()
    }
}

