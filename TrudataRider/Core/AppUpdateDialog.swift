//
//  AppUpdateDialog.swift
//  TrudataRider
//
//  The update sheet Remote Config drives. Android downloads an APK; on iOS the only route is the
//  App Store, so the action opens the store page instead.
//

import SwiftUI

struct AppUpdateDialog: View {

    let config: AppUpdateConfig
    var onPostpone: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: config.isForced ? "exclamationmark.arrow.circlepath" : "arrow.down.circle.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(AppTheme.brand.primary)

                Text(config.title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(config.message)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)

                if !config.latestVersionName.isEmptyString {
                    Text("Version \(config.latestVersionName)"
                         + (config.updateSizeMb.isEmptyString ? "" : " · \(config.updateSizeMb) MB"))
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)
                }

                if !config.releaseNotes.isEmptyString {
                    ScrollView {
                        Text(config.releaseNotes)
                            .font(.system(size: 12.5))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 120)
                    .padding(10)
                    .background(AppTheme.whiteSmoke, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                VStack(spacing: 8) {
                    Button(action: openStore) {
                        Text("Update now")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(AppTheme.brand.primary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    // A forced update has no way past it; the app is unusable until the store build is in.
                    if !config.isForced {
                        Button(action: onPostpone) {
                            Text("Later")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 28)
        }
    }

    private func openStore() {
        // No numeric App Store id is in the config, so send them to the store search for the app.
        let name = (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String)
            ?? "TruDataa Rider"
        let query = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "TruDataa"
        guard let url = URL(string: "itms-apps://itunes.apple.com/search?term=\(query)")
                ?? URL(string: "https://apps.apple.com/search?term=\(query)") else { return }
        UIApplication.shared.open(url)
    }
}
