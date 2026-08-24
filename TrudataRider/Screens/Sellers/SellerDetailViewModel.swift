//
//  SellerDetailViewModel.swift
//  TrudataRider
//

import Foundation
import Combine

final class SellerDetailViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var profile: SellerProfileDetail?
    @Published var showDetails = true

    let sellerId: String
    private var cancellable: AnyCancellable?
    private let service = SellerDetailServiceManager()

    init(sellerId: String) {
        self.sellerId = sellerId
    }

    var headerTitle: String {
        profile?.name.isEmptyString == false ? (profile?.name ?? "Seller Profile") : "Seller Profile"
    }

    func onAppear() {
        if profile == nil {
            load()
        }
    }

    func refresh() {
        load()
    }

    private func load() {
        cancellable?.cancel()
        isLoading = true
        errorMessage = nil

        cancellable = service.fetchProfile(sellerId: sellerId)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if response.status, let profile = response.profile {
                    self.profile = profile
                    self.errorMessage = nil
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Unable to load seller profile."
                        : response.message
                }
            }
    }
}
