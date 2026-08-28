//
//  AppRootManager.swift
//  Truedata
//

import Foundation
import SwiftUI
import UIKit
import Combine

enum AppRootDestination: Equatable {
    case splash
    case auth
    case home
}

@MainActor
final class AppRootManager: ObservableObject {

    static let shared = AppRootManager()

    @Published var currentRoot: AppRootDestination = .splash
    @Published var isSheetPresented: Bool = false

    func switchToHome() {
        withAnimation(.easeInOut(duration: 0.35)) {
            self.currentRoot = .home
        }
    }

    func switchToAuth() {
        withAnimation(.easeInOut(duration: 0.35)) {
            self.currentRoot = .auth
        }
    }

    func resetToSplash() {
        withAnimation(.easeInOut(duration: 0.35)) {
            self.currentRoot = .splash
        }
    }

    func setRootView<T: View>(view: T, window: UIWindow? = nil) {
        if view is HomeScreen {
            switchToHome()
            return
        } else if view is AuthScreen {
            switchToAuth()
            return
        } else if view is SplashScreen {
            resetToSplash()
            return
        }

        let targetWindow = window ?? UIApplication.shared.keyWindow
        guard let targetWindow else { return }

        targetWindow.overrideUserInterfaceStyle = .light
        targetWindow.enableTapToDismissKeyboard()
        targetWindow.rootViewController = UIHostingController(rootView: view.handleNoInternet().preferredColorScheme(.light))
        UIView.transition(
            with: targetWindow,
            duration: 0.3,
            options: .transitionCrossDissolve,
            animations: nil,
            completion: nil
        )
    }
}

extension UIApplication {
    var keyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

private class TapDismissGestureRecognizer: UITapGestureRecognizer {}

extension UIWindow: @retroactive UIGestureRecognizerDelegate {
    func enableTapToDismissKeyboard() {
        if gestureRecognizers?.contains(where: { $0 is TapDismissGestureRecognizer }) == true {
            return
        }
        let tap = TapDismissGestureRecognizer(target: self, action: #selector(dismissKeyboardFromWindowOnTap))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboardFromWindowOnTap() {
        endEditing(true)
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
