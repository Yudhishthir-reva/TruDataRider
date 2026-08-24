//
//  AchievementHistoryViewModel.swift
//  TrudataRider
//

import Foundation
import Combine

enum AchievementViewMode: String, CaseIterable, Identifiable {
    case report = "Report"
    case list = "List"
    var id: String { rawValue }
}

final class AchievementHistoryViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var data: AchievementHistoryData?
    @Published var startDate = ""
    @Published var endDate = ""
    @Published var selectedPreset: DeliveryHistoryDatePreset = .today
    @Published var viewMode: AchievementViewMode = .report

    private var cancellable: AnyCancellable?
    private let service = AchievementHistoryServiceManager()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    func onAppear() {
        if data == nil {
            applyPreset(.today, fetch: true)
        }
    }

    func refresh() {
        fetch()
    }

    func selectPreset(_ preset: DeliveryHistoryDatePreset) {
        applyPreset(preset, fetch: true)
    }

    func updateStartDate(_ date: Date) {
        startDate = dateFormatter.string(from: date)
        selectedPreset = .custom
        fetch()
    }

    func updateEndDate(_ date: Date) {
        endDate = dateFormatter.string(from: date)
        selectedPreset = .custom
        fetch()
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
        if fetch { self.fetch() }
    }

    private func fetch() {
        cancellable?.cancel()
        isLoading = true
        errorMessage = nil

        cancellable = service.fetchAchievements(startDate: startDate, endDate: endDate)
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
                self.data = response.data
                self.errorMessage = nil
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
