//
//  DenominationSummaryViewModel.swift
//  TrudataRider
//

import Foundation
import Combine

final class DenominationSummaryViewModel: ObservableObject {

    @Published var summary: SummaryTotals?
    @Published var staffWise: [StaffSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var expandedStaff: Set<Int> = []
    /// Today by default: the summary is most often opened to check the day's cash.
    @Published var range: CashDateRange = .today

    let access = CashAccess.current

    private var hasLoaded = false
    private let service = CashCollectionServiceManager()
    private var cancellables = Set<AnyCancellable>()

    /// The summary tab is lazy — it only fetches the first time it is opened.
    func ensureLoaded() {
        guard !hasLoaded else { return }
        load()
    }

    func load() {
        guard !isLoading else { return }
        hasLoaded = true
        isLoading = true
        errorMessage = nil

        service.denominationSummary(range: range, staffIds: [])
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
                self.summary = response.summary
                self.staffWise = response.staffWise
            }
            .store(in: &cancellables)
    }

    func rangeChanged(_ newRange: CashDateRange) {
        range = newRange
        load()
    }

    func toggleStaff(_ staffId: Int) {
        if expandedStaff.contains(staffId) {
            expandedStaff.remove(staffId)
        } else {
            expandedStaff.insert(staffId)
        }
    }

    /// The counted denominations, biggest first, with the zero rows dropped.
    var lines: [SummaryDenomination] {
        (summary?.denominations ?? [])
            .filter { $0.qty > 0 }
            .sorted { $0.total > $1.total }
    }

    var notesTotal: Double {
        total(ofKind: .note)
    }

    var coinsTotal: Double {
        total(ofKind: .coin)
    }

    private func total(ofKind kind: Denomination.Kind) -> Double {
        let lines: [SummaryDenomination] = summary?.denominations ?? []
        var sum: Double = 0
        for line in lines where line.denomination?.kind == kind {
            sum += line.total
        }
        return sum
    }

    var notesShare: Double {
        let grand = notesTotal + coinsTotal
        guard grand > 0 else { return 0 }
        return notesTotal / grand
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
