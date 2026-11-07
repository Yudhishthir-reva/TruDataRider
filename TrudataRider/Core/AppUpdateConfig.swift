//
//  AppUpdateConfig.swift
//  TrudataRider
//
//  The `rider_update_config` JSON that Firebase Remote Config serves. The same document drives both
//  platforms; the APK fields are Android's side of it and are read but unused here, since iOS
//  updates come from the App Store.
//

import Foundation

struct AppUpdateConfig: Decodable, Equatable {
    var appPackageName: String
    var updateRequired: Bool
    /// `soft` lets the user carry on; `force` blocks the app until they update.
    var updateType: String
    var latestVersionName: String
    var latestVersionCode: Int
    var minSupportedVersionCode: Int
    var updateTitle: String
    var updateMessage: String
    var releaseNotes: String
    var updateSizeMb: String
    var apkDownloadUrl: String
    var apkDownloadUrlBackup: String
    var apkMd5: String
    var updatePostponeHours: Int

    enum CodingKeys: String, CodingKey {
        case appPackageName = "app_package_name"
        case updateRequired = "update_required"
        case updateType = "update_type"
        case latestVersionName = "latest_version_name"
        case latestVersionCode = "latest_version_code"
        case minSupportedVersionCode = "min_supported_version_code"
        case updateTitle = "update_title"
        case updateMessage = "update_message"
        case releaseNotes = "release_notes"
        case updateSizeMb = "update_size_mb"
        case apkDownloadUrl = "apk_download_url"
        case apkDownloadUrlBackup = "apk_download_url_backup"
        case apkMd5 = "apk_md5"
        case updatePostponeHours = "update_postpone_hours"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appPackageName = container.decodeStringLeniently(forKey: .appPackageName) ?? ""
        updateRequired = container.decodeBoolLeniently(forKey: .updateRequired) ?? false
        updateType = container.decodeStringLeniently(forKey: .updateType) ?? "soft"
        latestVersionName = container.decodeStringLeniently(forKey: .latestVersionName) ?? ""
        latestVersionCode = container.decodeIntLeniently(forKey: .latestVersionCode) ?? 0
        minSupportedVersionCode = container.decodeIntLeniently(forKey: .minSupportedVersionCode) ?? 0
        updateTitle = container.decodeStringLeniently(forKey: .updateTitle) ?? ""
        updateMessage = container.decodeStringLeniently(forKey: .updateMessage) ?? ""
        releaseNotes = container.decodeStringLeniently(forKey: .releaseNotes) ?? ""
        updateSizeMb = container.decodeStringLeniently(forKey: .updateSizeMb) ?? ""
        apkDownloadUrl = container.decodeStringLeniently(forKey: .apkDownloadUrl) ?? ""
        apkDownloadUrlBackup = container.decodeStringLeniently(forKey: .apkDownloadUrlBackup) ?? ""
        apkMd5 = container.decodeStringLeniently(forKey: .apkMd5) ?? ""
        updatePostponeHours = container.decodeIntLeniently(forKey: .updatePostponeHours) ?? 24
    }

    /// The build this app was shipped as, read from `CFBundleVersion`.
    static var currentVersionCode: Int {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return Int(build) ?? 0
    }

    static var currentVersionName: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    /// Below the minimum supported build, or the config says so outright — the user can't dismiss.
    var isForced: Bool {
        if Self.currentVersionCode < minSupportedVersionCode { return true }
        return updateRequired && updateType.lowercased() == "force"
    }

    /// There is a newer build than the one running.
    var hasUpdate: Bool {
        updateRequired || Self.currentVersionCode < latestVersionCode
    }

    var title: String {
        updateTitle.isEmptyString ? "Update available" : updateTitle
    }

    var message: String {
        if !updateMessage.isEmptyString { return updateMessage }
        return isForced
            ? "This version is no longer supported. Update to carry on."
            : "A newer version of TruDataa Rider is available."
    }
}
