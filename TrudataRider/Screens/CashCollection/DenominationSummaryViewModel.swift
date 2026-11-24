//
//  DenominationSummaryViewModel.swift
//  TrudataRider
//
//  Android `DenominationSummaryViewModel`: `V2/cash-collection/denomination-summary`, approved
//  collections only, per the server.
//

import Combine
import Foundation

final class DenominationSummaryViewModel: ObservableObject {

    let access = CashAccess.current

    /// Today by default: the summary is most often opened to check the day's cash.
    @Published private(set) var filter = CashFilter(period: .today)
    @Published private(set) var people: [PersonOption] = []
    @Published private(set) var data: DenominationSummaryResponse?
    @Published private(set) var isLoading = true
    @Published private(set) var isRefreshing = false
    @Published private(set) var error: String?
    @Published private(set) var expandedStaff: Set<Int> = []
    /// Bumped on every successful load, so the counters and bars replay for the new numbers.
    @Published private(set) var loadVersion = 0

    private let service = CashCollectionServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var job: AnyCancellable?
    private var started = false

    init() {
        if access.canReviewAll {
            CashPeople.load()
                .receive(on: RunLoop.main)
                .sink { _ in } receiveValue: { [weak self] people in self?.people = people }
                .store(in: &cancellables)
        }
        // A collection approved or edited elsewhere changes these totals.
        CashChange.publisher
            .sink { [weak self] change in
                guard let self, change == .collection, self.started else { return }
                self.load(refresh: true)
            }
            .store(in: &cancellables)
    }

    /// The staff filter is a reviewer's tool; everyone else only ever sees their own cash.
    var canFilterStaff: Bool { access.canReviewAll }

    /// Staff-list names, plus anyone in the current summary the staff list leaves out (admin).
    var staffOptions: [PersonOption] {
        cashMergePeople(people, (data?.staffWise ?? []).map { PersonOption(id: $0.staffId, name: $0.staffName, role: "") })
    }

    var staffLabel: String { filter.staffLabel(staffOptions) }

    /// Loads on first show of the tab, not when the Cash Collection screen opens.
    func ensureLoaded() {
        guard !started else { return }
        started = true
        load(refresh: false)
    }

    func filterChanged(_ newFilter: CashFilter) {
        // Today is re-sent even when unchanged: a screen left open overnight means a new day.
        if newFilter == filter && newFilter.period != .today { return }
        filter = newFilter
        expandedStaff = []
        load(refresh: false)
    }

    func onlyStaff(_ id: Int) {
        var next = filter
        next.staffIds = [id]
        filterChanged(next)
    }

    func seeThisMonth() {
        var next = filter
        next.period = .month
        next.month = CashDates.startOfMonth(Date())
        filterChanged(next)
    }

    func toggleExpanded(_ staffId: Int) {
        if expandedStaff.contains(staffId) {
            expandedStaff.remove(staffId)
        } else {
            expandedStaff.insert(staffId)
        }
    }

    func refresh() {
        load(refresh: true)
    }

    private func load(refresh: Bool) {
        job?.cancel()
        if refresh && data != nil {
            isRefreshing = true
        } else {
            isLoading = true
        }
        error = nil

        job = service.denominationSummary(range: filter.dates(), staffIds: filter.staffIds)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self, case .failure(let failure) = completion else { return }
                // A failed refresh keeps the numbers on screen; a failed first load shows the error.
                self.isLoading = false
                self.isRefreshing = false
                self.error = CashError.message(failure)
                if !refresh { self.data = nil }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.data = response
                self.isLoading = false
                self.isRefreshing = false
                self.error = nil
                self.loadVersion += 1
            }
    }
}

extension CashDateRange {

    /// Today, in the `yyyy-MM-dd` shape the endpoints take.
    static var today: CashDateRange {
        let day = CashFormat.apiString(from: Date())
        return CashDateRange(from: day, to: day)
    }

    /// The last `days` days, today included.
    static func lastDays(_ days: Int) -> CashDateRange {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: now) ?? now
        return CashDateRange(from: CashFormat.apiString(from: start), to: CashFormat.apiString(from: now))
    }

    /// The calendar month `date` falls in.
    static func month(of date: Date) -> CashDateRange {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return .allTime }
        let last = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        return CashDateRange(
            from: CashFormat.apiString(from: interval.start),
            to: CashFormat.apiString(from: last)
        )
    }

    var label: String {
        guard let from, let to else { return "All time" }
        if from == to {
            return from == CashFormat.apiString(from: Date()) ? "Today" : CashFormat.pretty(from)
        }
        return "\(CashFormat.pretty(from)) – \(CashFormat.pretty(to))"
    }
}
