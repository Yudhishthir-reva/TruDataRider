//
//  TodayRiderOrderHistoryViewModel.swift
//  TrudataRider
//

import Foundation
import Combine

enum DeliveryHistoryDatePreset: String, CaseIterable, Identifiable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case lastWeek = "Last Week"
    case custom = "Custom"

    var id: String { rawValue }

    static var selectable: [DeliveryHistoryDatePreset] {
        [.today, .yesterday, .thisWeek, .lastWeek]
    }
}

final class TodayRiderOrderHistoryViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var orders: [DeliveryHistoryOrder] = []
    @Published var summary: [DeliveryHistorySummary] = []
    @Published var orderIdSearch = ""
    @Published var startDate = ""
    @Published var endDate = ""
    @Published var selectedPreset: DeliveryHistoryDatePreset = .today
    @Published var orderStatus = ""
    @Published var dateType = "date"

    private var currentPage = 1
    private var lastPage = 1
    private var canLoadMore = true
    private var searchCancellable: AnyCancellable?
    private var fetchCancellable: AnyCancellable?
    private let service = TodayRiderOrderHistoryServiceManager()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var totalDeliveries: Int {
        summary.first(where: { $0.statusId.lowercased() == "all" })?.count ?? orders.count
    }

    var statusFilters: [DeliveryHistorySummary] {
        summary.filter { $0.statusId.lowercased() != "all" }
    }

    func onAppear() {
        if orders.isEmpty {
            applyPreset(.today, fetch: true)
        }
    }

    func refresh() {
        resetAndFetch()
    }

    func retry() {
        resetAndFetch()
    }

    func loadMoreIfNeeded(currentItem: DeliveryHistoryOrder) {
        guard canLoadMore, !isLoading, !isLoadingMore else { return }
        guard let index = orders.firstIndex(where: { $0.id == currentItem.id }) else { return }
        if index >= orders.count - 3 {
            currentPage += 1
            fetch(isInitialLoad: false)
        }
    }

    func onSearchChanged(_ query: String) {
        orderIdSearch = query
        searchCancellable?.cancel()
        searchCancellable = Just(query)
            .delay(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] value in
                guard let self else { return }
                if value.isEmptyString || value.trim.count >= 3 {
                    self.resetAndFetch()
                }
            }
    }

    func selectPreset(_ preset: DeliveryHistoryDatePreset) {
        applyPreset(preset, fetch: true)
    }

    func updateStartDate(_ date: Date) {
        startDate = dateFormatter.string(from: date)
        selectedPreset = .custom
        resetAndFetch()
    }

    func updateEndDate(_ date: Date) {
        endDate = dateFormatter.string(from: date)
        selectedPreset = .custom
        resetAndFetch()
    }

    func applyFilters(status: String) {
        orderStatus = status
        resetAndFetch()
    }

    func resetFilters() {
        orderStatus = ""
        dateType = "date"
        resetAndFetch()
    }

    func parsedDate(from string: String) -> Date {
        dateFormatter.date(from: string) ?? Date()
    }

    private func applyPreset(_ preset: DeliveryHistoryDatePreset, fetch: Bool) {
        guard preset != .custom else { return }
        let range = dateRange(for: preset)
        startDate = dateFormatter.string(from: range.start)
        endDate = dateFormatter.string(from: range.end)
        selectedPreset = preset
        if fetch { resetAndFetch() }
    }

    private func resetAndFetch() {
        currentPage = 1
        canLoadMore = true
        errorMessage = nil
        fetch(isInitialLoad: true)
    }

    private func fetch(isInitialLoad: Bool) {
        fetchCancellable?.cancel()
        if isInitialLoad {
            isLoading = true
        } else {
            isLoadingMore = true
        }

        fetchCancellable = service.fetchHistory(
            startDate: startDate,
            endDate: endDate,
            dateType: dateType,
            orderId: orderIdSearch.trim,
            sellerId: "",
            status: orderStatus,
            page: currentPage
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isLoading = false
            self.isLoadingMore = false
            if case .failure(let error) = completion {
                self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isLoading = false
            self.isLoadingMore = false
            if response.status {
                let newOrders = response.orders
                if isInitialLoad {
                    self.orders = newOrders
                } else {
                    let existing = Set(self.orders.map(\.id))
                    self.orders.append(contentsOf: newOrders.filter { !existing.contains($0.id) })
                }
                self.summary = response.summary
                self.currentPage = response.currentPage
                self.lastPage = max(response.lastPage, 1)
                self.canLoadMore = self.currentPage < self.lastPage
                self.errorMessage = nil
            } else {
                if isInitialLoad { self.orders = [] }
                self.errorMessage = response.message.isEmptyString
                    ? "No delivery history found for the selected filters."
                    : response.message
            }
        }
    }

    private func dateRange(for preset: DeliveryHistoryDatePreset) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        switch preset {
        case .today:
            return (today, today)
        case .yesterday:
            let day = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            return (day, day)
        case .thisWeek:
            let weekday = calendar.component(.weekday, from: today)
            // Make Monday start of week
            let daysFromMonday = (weekday + 5) % 7
            let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
            return (monday, today)
        case .lastWeek:
            let weekday = calendar.component(.weekday, from: today)
            let daysFromMonday = (weekday + 5) % 7
            let thisMonday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
            let lastMonday = calendar.date(byAdding: .day, value: -7, to: thisMonday) ?? today
            let lastSunday = calendar.date(byAdding: .day, value: 6, to: lastMonday) ?? today
            return (lastMonday, lastSunday)
        case .custom:
            return (today, today)
        }
    }
}
