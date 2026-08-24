//
//  ProfileViewModel.swift
//  TrudataRider
//
//

import Foundation
import Combine

final class ProfileViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var profile: UserProfileDetail?

    private var cancellable: AnyCancellable?
    private let service: ProfileServiceManager

    init(service: ProfileServiceManager = ProfileServiceManager()) {
        self.service = service
        self.profile = Self.fallbackProfile()
    }

    var headerTitle: String {
        "My Profile"
    }

    func onAppear() {
        load()
    }

    func refresh() {
        load()
    }

    private func load() {
        cancellable?.cancel()
        isLoading = true
        errorMessage = nil

        cancellable = service.fetchUserProfile()
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    if self.profile == nil || self.profile?.name.isEmptyString == true {
                        self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                    }
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if response.status, let profile = response.profile {
                    self.profile = profile
                    self.errorMessage = nil
                } else if let profile = response.profile {
                    self.profile = profile
                } else if self.profile == nil {
                    self.errorMessage = response.message.isEmptyString
                        ? "Unable to load profile."
                        : response.message
                }
            }
    }

    private static func fallbackProfile() -> UserProfileDetail {
        let savedName = UserDefaultManager.shared.getUserDefaultsString(key: .userName)
        let savedRole = UserDefaultManager.shared.getUserDefaultsString(key: .userRole)
        let savedMobile = UserDefaultManager.shared.getUserDefaultsString(key: .userMobile)
        let savedId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)

        return UserProfileDetail(
            id: savedId,
            name: savedName.isEmptyString ? "Arman" : savedName,
            riderCode: savedId.isEmptyString ? "TD-039" : "TD-\(savedId)",
            role: savedRole.isEmptyString ? "Rider" : savedRole,
            joiningDate: "2026-07-31",
            status: "Active",
            mobile: savedMobile.isEmptyString ? "7657996189" : savedMobile,
            email: "-",
            location: "Jaipur, RAJASTHAN",
            profilePic: ""
        )
    }
}
