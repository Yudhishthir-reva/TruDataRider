//
//  SellerListViewModel.swift
//  TrudataRider
//

import Foundation
import Combine

final class SellerListViewModel: ObservableObject {

    @Published var sellers: [RegisteredSeller] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var statusFilter = ""

    private var currentPage = 1
    private var canLoadMore = false
    private var searchCancellable: AnyCancellable?
    private var fetchCancellable: AnyCancellable?
    private let service = SellerListServiceManager()

    var hasActiveFilters: Bool {
        !statusFilter.isEmptyString
    }

    func onAppear() {
        if sellers.isEmpty {
            fetch(reset: true)
        }
    }

    func refresh() {
        fetch(reset: true)
    }

    func onSearchChanged(_ query: String) {
        searchText = query
        searchCancellable?.cancel()
        searchCancellable = Just(query)
            .delay(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.fetch(reset: true)
            }
    }

    func applyStatusFilter(_ status: String) {
        statusFilter = status
        fetch(reset: true)
    }

    func resetFilters() {
        statusFilter = ""
        fetch(reset: true)
    }

    func loadMoreIfNeeded(current: RegisteredSeller) {
        guard canLoadMore, !isLoading, !isLoadingMore else { return }
        guard let index = sellers.firstIndex(where: { $0.id == current.id }) else { return }
        if index >= sellers.count - 3 {
            fetch(reset: false)
        }
    }

    private func fetch(reset: Bool) {
        fetchCancellable?.cancel()
        if reset {
            currentPage = 1
            canLoadMore = false
            isLoading = true
            errorMessage = nil
        } else {
            isLoadingMore = true
            currentPage += 1
        }

        fetchCancellable = service.fetchSellers(
            page: currentPage,
            shopName: searchText.trim,
            status: statusFilter
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isLoading = false
            self.isLoadingMore = false
            if case .failure(let error) = completion {
                self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                if !reset { self.currentPage = max(1, self.currentPage - 1) }
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isLoading = false
            self.isLoadingMore = false
            if response.status {
                if reset {
                    self.sellers = response.sellers
                } else {
                    let existing = Set(self.sellers.map(\.id))
                    self.sellers.append(contentsOf: response.sellers.filter { !existing.contains($0.id) })
                }
                self.currentPage = response.currentPage
                self.canLoadMore = response.currentPage < response.lastPage
                self.errorMessage = nil
            } else {
                if reset { self.sellers = [] }
                self.errorMessage = response.message.isEmptyString
                    ? "No sellers found for selected filters."
                    : response.message
            }
        }
    }
}
