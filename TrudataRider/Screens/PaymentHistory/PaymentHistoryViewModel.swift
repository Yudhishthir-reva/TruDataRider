//
//  PaymentHistoryViewModel.swift
//  TrudataRider
//

import Foundation
import Combine

final class PaymentHistoryViewModel: ObservableObject {

    @Published var transactions: [PaymentTransaction] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    // Filters
    @Published var paymentType = PaymentType.all.id
    @Published var paymentStatus = PaymentApprovalStatus.all.id
    @Published var startDate: Date?
    @Published var endDate: Date?

    private var page = 1
    private var lastPage = 1
    private let service = PaymentHistoryServiceManager()
    private var cancellables = Set<AnyCancellable>()

    var hasMore: Bool { page < lastPage }

    var total: Double {
        transactions.reduce(0) { $0 + $1.amountValue }
    }

    var hasActiveFilters: Bool {
        !paymentType.isEmpty || !paymentStatus.isEmpty || startDate != nil || endDate != nil
    }

    func load(refresh: Bool = false) {
        guard !isLoading else { return }
        if refresh { page = 1 }
        isLoading = true
        errorMessage = nil

        request(page: 1)
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
                if response.status {
                    self.transactions = response.transactions
                    self.page = response.currentPage
                    self.lastPage = response.lastPage
                } else {
                    self.transactions = []
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to fetch transaction history." : response.message
                }
            }
            .store(in: &cancellables)
    }

    func loadMore() {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true

        request(page: page + 1)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoadingMore = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoadingMore = false
                guard response.status else { return }
                let known = Set(self.transactions.map(\.id))
                self.transactions += response.transactions.filter { !known.contains($0.id) }
                self.page = response.currentPage
                self.lastPage = response.lastPage
            }
            .store(in: &cancellables)
    }

    func typeChanged(_ type: String) {
        paymentType = type
        load(refresh: true)
    }

    func statusChanged(_ status: String) {
        paymentStatus = status
        load(refresh: true)
    }

    func applyDateFilter(start: Date?, end: Date?) {
        startDate = start
        endDate = end
        load(refresh: true)
    }

    func clearFilters() {
        paymentType = PaymentType.all.id
        paymentStatus = PaymentApprovalStatus.all.id
        startDate = nil
        endDate = nil
        load(refresh: true)
    }

    private func request(page: Int) -> AnyPublisher<PaymentHistoryResponse, Error> {
        service.fetchPaymentHistory(
            page: page,
            startDate: startDate.map(CashFormat.apiString(from:)) ?? "",
            endDate: endDate.map(CashFormat.apiString(from:)) ?? "",
            paymentMode: paymentType,
            paymentStatus: paymentStatus
        )
    }
}
