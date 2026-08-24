//
//  TravelHistoryViewModel.swift
//  TrudataRider
//

import Foundation
import Combine

enum TravelHistoryTab: Int, CaseIterable, Identifiable {
    case overview = 0
    case failedOrders = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .overview: return "Travel Overview"
        case .failedOrders: return "Failed Orders"
        }
    }
}

final class TravelHistoryViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var travelData: RiderTravelHistoryData?
    @Published var startDate = ""
    @Published var endDate = ""
    @Published var selectedPreset: DeliveryHistoryDatePreset = .today
    @Published var selectedTab: TravelHistoryTab = .overview

    private var fetchCancellable: AnyCancellable?
    private let service = TravelHistoryServiceManager()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    func onAppear() {
        if travelData == nil {
            applyPreset(.today, fetch: true)
        }
    }

    func refresh() {
        resetAndFetch()
    }

    func retry() {
        resetAndFetch()
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
        travelData = nil
        errorMessage = nil
        fetch()
    }

    private func fetch() {
        fetchCancellable?.cancel()
        isLoading = true

        fetchCancellable = service.fetchTravelHistory(startDate: startDate, endDate: endDate)
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
                if response.status, let data = response.data {
                    self.travelData = data
                    self.errorMessage = nil
                } else {
                    self.travelData = nil
                    self.errorMessage = response.message.isEmptyString
                        ? "No travel history found for the selected date range."
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
