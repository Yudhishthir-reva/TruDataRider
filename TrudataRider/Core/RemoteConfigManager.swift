//
//  RemoteConfigManager.swift
//  TrudataRider
//
//  Firebase Remote Config, reading the same `rider_update_config` document the Android app reads.
//

import Foundation
import Combine
import FirebaseRemoteConfig

@MainActor
final class RemoteConfigManager: ObservableObject {

    static let shared = RemoteConfigManager()

    /// The parsed config, or nil until the first fetch lands.
    @Published private(set) var appUpdateConfig: AppUpdateConfig?

    /// Set when the user postpones a soft update, so the sheet stays away for `updatePostponeHours`.
    private var postponedUntil: Date? {
        get { UserDefaults.standard.object(forKey: Self.postponeKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.postponeKey) }
    }

    private static let configKey = "rider_update_config"
    private static let postponeKey = "app_update_postponed_until"

    private let remoteConfig = RemoteConfig.remoteConfig()

    private init() {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 15
        remoteConfig.configSettings = settings
    }

    /// The sheet is due when there is an update and it is either forced or not currently postponed.
    var pendingUpdate: AppUpdateConfig? {
        guard let config = appUpdateConfig, config.hasUpdate else { return nil }
        if config.isForced { return config }
        if let postponedUntil, postponedUntil > Date() { return nil }
        return config
    }

    func fetchAndActivate() {
        remoteConfig.fetchAndActivate { [weak self] status, error in
            if let error {
                print("RemoteConfig: fetch failed — \(error.localizedDescription)")
            } else {
                print("RemoteConfig: \(status == .successFetchedFromRemote ? "updated" : "using cached values")")
            }
            // Even a failed fetch can leave valid cached values from a previous one.
            Task { @MainActor [weak self] in
                self?.parseConfig()
            }
        }

        // Real-time updates, so a force-update can land while the app is open.
        remoteConfig.addOnConfigUpdateListener { [weak self] update, error in
            guard error == nil, update?.updatedKeys.contains(Self.configKey) == true else { return }
            self?.remoteConfig.activate { _, _ in
                Task { @MainActor [weak self] in
                    self?.parseConfig()
                }
            }
        }
    }

    /// Hides a soft update until the postpone window runs out.
    func postponeUpdate() {
        let hours = appUpdateConfig?.updatePostponeHours ?? 24
        postponedUntil = Calendar.current.date(byAdding: .hour, value: hours, to: Date())
        objectWillChange.send()
    }

    private func parseConfig() {
        let raw = remoteConfig.configValue(forKey: Self.configKey).stringValue
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else {
            print("RemoteConfig: config string is empty. No update rules applied.")
            return
        }
        do {
            appUpdateConfig = try JSONDecoder().decode(AppUpdateConfig.self, from: data)
        } catch {
            print("RemoteConfig: couldn't read the update config — \(error)")
        }
    }
}
