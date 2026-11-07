//
//  CashCollectionViewModel.swift
//  TrudataRider
//

import Foundation
import Combine

enum CollectionTab: Hashable {
    case submit, list, summary
}

final class CashCollectionViewModel: ObservableObject {

    // MARK: - Tab

    @Published var tab: CollectionTab = .submit

    // MARK: - Submit form

    @Published var declaredText = ""
    @Published var counts: DenominationCounts = [:]
    @Published var remark = ""
    @Published var declaredError: String?
    @Published var isSubmitting = false
    @Published var isConfirming = false
    @Published var submitted: CashCollection?
    @Published var formError: String?

    // MARK: - List

    @Published var collections: [CashCollection] = []
    @Published var isLoadingList = false
    @Published var isLoadingMore = false
    @Published var listError: String?
    @Published var statusFilter: String?
    @Published var range: CashDateRange = .allTime

    let access = CashAccess.current

    private var page = 1
    private var hasMore = false
    private let service = CashCollectionServiceManager()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Derived form state

    var declared: Int {
        Int(declaredText) ?? 0
    }

    var counted: Int {
        counts.cashTotal
    }

    var isBalanced: Bool {
        declared > 0 && counted == declared
    }

    var noteCount: Int {
        counts.pieces(ofKind: .note)
    }

    var coinCount: Int {
        counts.pieces(ofKind: .coin)
    }

    var listTitle: String {
        access.canReviewAll ? "All Collection" : "My Collection"
    }

    // MARK: - Form actions

    /// Keeps only digits, drops leading zeros, and caps the length so a count can't overflow.
    static func digitsOnly(_ input: String, maxLength: Int = 9) -> String {
        String(input.filter(\.isNumber).drop(while: { $0 == "0" }).prefix(maxLength))
    }

    func declaredChanged(_ text: String) {
        declaredText = Self.digitsOnly(text)
        declaredError = nil
        formError = nil
    }

    func countChanged(_ denomination: Denomination, to count: Int) {
        counts[denomination] = max(0, count)
        formError = nil
    }

    func clearForm() {
        declaredText = ""
        counts = [:]
        remark = ""
        declaredError = nil
        formError = nil
    }

    /// The server rejects a submission whose counts don't add up to the declared total, so the
    /// mismatch is caught here, before anything is sent.
    func requestSubmit() {
        if declared <= 0 {
            declaredError = "Enter the total cash amount"
            formError = "Enter the total cash amount you are handing over, then count each note and coin."
        } else if counted == 0 {
            formError = "Count the notes and coins before submitting."
        } else if !isBalanced {
            formError = "The counts add up to \(CashFormat.rupees(counted)), not \(CashFormat.rupees(declared)). Fix the counts or the total."
        } else {
            isConfirming = true
        }
    }

    func submit() {
        guard !isSubmitting, isBalanced else { return }
        isConfirming = false
        isSubmitting = true
        formError = nil

        service.submitCollection(declared: declared, counts: counts, remark: remark)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isSubmitting = false
                if case .failure(let error) = completion {
                    self.formError = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isSubmitting = false
                if response.status, let collection = response.data {
                    self.submitted = collection
                    self.clearForm()
                } else {
                    self.formError = response.message.isEmptyString
                        ? "The submission could not be saved." : response.message
                }
            }
            .store(in: &cancellables)
    }

    /// Called when the "cash submitted" sheet is dismissed: the new row belongs at the top of the list.
    func dismissSubmitted() {
        submitted = nil
        loadList(refresh: true)
    }

    // MARK: - List actions

    func loadList(refresh: Bool = false) {
        if refresh {
            page = 1
        }
        guard !isLoadingList else { return }

        isLoadingList = true
        listError = nil

        listPublisher(page: 1)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoadingList = false
                if case .failure(let error) = completion {
                    self.listError = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoadingList = false
                self.collections = response.items
                self.page = response.meta.currentPage
                self.hasMore = response.hasMore
            }
            .store(in: &cancellables)
    }

    func loadMore() {
        guard hasMore, !isLoadingList, !isLoadingMore else { return }

        isLoadingMore = true
        let next = page + 1

        listPublisher(page: next)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoadingMore = false
                if case .failure(let error) = completion {
                    self.listError = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoadingMore = false
                // Pages can overlap when a new collection lands between requests; keep the first copy.
                let known = Set(self.collections.map(\.id))
                self.collections += response.items.filter { !known.contains($0.id) }
                self.page = response.meta.currentPage
                self.hasMore = response.hasMore
            }
            .store(in: &cancellables)
    }

    func statusFilterChanged(_ status: String?) {
        statusFilter = status
        loadList(refresh: true)
    }

    func rangeChanged(_ newRange: CashDateRange) {
        range = newRange
        loadList(refresh: true)
    }

    private func listPublisher(page: Int) -> AnyPublisher<PagedResponse<CashCollection>, Error> {
        if access.canReviewAll {
            return service.allCollections(range: range, staffIds: [], status: statusFilter, page: page)
        }
        return service.myCollections(range: range, page: page)
    }
}
