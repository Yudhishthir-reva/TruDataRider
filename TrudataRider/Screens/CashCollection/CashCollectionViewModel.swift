//
//  CashCollectionViewModel.swift
//  TrudataRider
//
//  Android `CashCollectionViewModel`: the Submit tab and the list tab. The list is the user's own
//  submissions for a sale person or rider, and everyone's for a reviewer (admin, accountant, sales
//  manager).
//

import Combine
import Foundation

enum CollectionTab: Hashable {
    case submit, list, summary
}

final class CashCollectionViewModel: ObservableObject {

    // MARK: - Tab

    @Published private(set) var tab: CollectionTab = .submit

    // MARK: - Submit form

    @Published private(set) var declaredText = ""
    @Published private(set) var counts: DenominationCounts = [:]
    @Published private(set) var remark = ""
    @Published private(set) var declaredError: String?
    @Published var isConfirming = false
    @Published private(set) var isSubmitting = false
    @Published var formError: String?
    @Published private(set) var submitted: CashCollection?

    // MARK: - List

    @Published private(set) var filter = CashFilter(period: .month)
    /// Names for the staff filter; reviewers only.
    @Published private(set) var people: [PersonOption] = []
    /// Only offered to reviewers; nil means every status.
    @Published private(set) var statusFilter: String?
    @Published private(set) var list = CashListState<CashCollection>()

    let access = CashAccess.current

    private let service = CashCollectionServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var submitJob: AnyCancellable?

    private lazy var pager = CashPager<CashCollection>(
        read: { [weak self] in self?.list },
        write: { [weak self] change in
            guard let self else { return }
            change(&self.list)
        },
        fetch: { [weak self] page in
            guard let self else { return Empty().eraseToAnyPublisher() }
            return self.fetch(page: page)
        }
    )

    init() {
        if access.canReviewAll {
            CashPeople.load()
                .receive(on: RunLoop.main)
                .sink { _ in } receiveValue: { [weak self] people in self?.people = people }
                .store(in: &cancellables)
        }
        CashChange.publisher
            .sink { [weak self] change in
                guard let self, change == .collection, self.list.loaded else { return }
                self.pager.load(refresh: true)
            }
            .store(in: &cancellables)
    }

    // MARK: - Derived form state

    var declared: Int { Int(declaredText) ?? 0 }

    var counted: Int { counts.cashTotal }

    var isBalanced: Bool { declared > 0 && counted == declared }

    var pieces: Int { counts.values.reduce(0, +) }

    var listTitle: String {
        access.canReviewAll ? "All Collection" : "My Collection"
    }

    /// Staff-list names, plus anyone in the loaded rows the staff list leaves out.
    var staffOptions: [PersonOption]? {
        guard access.canReviewAll else { return nil }
        let seen = list.items.compactMap { item in
            item.submittedBy.map { PersonOption(id: $0.id, name: $0.name, role: "") }
        }
        return cashMergePeople(people, seen)
    }

    var emptyText: String {
        access.canReviewAll
            ? "No collections were submitted \(filter.periodPhrase)."
            : "You haven't submitted any cash \(filter.periodPhrase)."
    }

    // MARK: - Tab and form actions

    func selectTab(_ newTab: CollectionTab) {
        tab = newTab
        if newTab == .list && !list.loaded { pager.load() }
    }

    func declaredChanged(_ text: String) {
        declaredText = cashDigitsOnly(text)
        declaredError = nil
        formError = nil
    }

    func countChanged(_ denomination: Denomination, to count: Int) {
        if count <= 0 {
            counts.removeValue(forKey: denomination)
        } else {
            counts[denomination] = count
        }
        formError = nil
    }

    func remarkChanged(_ text: String) {
        remark = String(text.prefix(250))
    }

    func clearForm() {
        declaredText = ""
        counts = [:]
        remark = ""
        declaredError = nil
        isConfirming = false
        formError = nil
        submitted = nil
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

        submitJob = service.submitCollection(declared: declared, counts: counts, remark: remark)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                if case .failure(let error) = completion {
                    self.isSubmitting = false
                    self.formError = CashError.message(error)
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isSubmitting = false
                if let collection = response.data {
                    self.submitted = collection
                } else {
                    self.formError = CashError.server(response.message) ?? CashError.empty
                }
            }
    }

    /// The "Cash submitted" pop-up was closed: the form starts over and the list shows the new row.
    func acknowledgeSubmitted() {
        clearForm()
        tab = .list
        pager.load(refresh: !list.items.isEmpty)
    }

    // MARK: - List actions

    func filterChanged(_ newFilter: CashFilter) {
        guard newFilter != filter else { return }
        filter = newFilter
        pager.load()
    }

    func statusFilterChanged(_ status: String?) {
        statusFilter = status
        pager.load()
    }

    func refresh() {
        pager.load(refresh: true)
    }

    func loadMore() {
        pager.loadMore()
    }

    private func fetch(page: Int) -> AnyPublisher<CashPage<CashCollection>, Error> {
        let range = filter.dates()
        let publisher = access.canReviewAll
            ? service.allCollections(range: range, staffIds: filter.staffIds, status: statusFilter, page: page)
            : service.myCollections(range: range, page: page)
        return publisher
            .map { CashPage(items: $0.items, meta: $0.meta) }
            .eraseToAnyPublisher()
    }
}
