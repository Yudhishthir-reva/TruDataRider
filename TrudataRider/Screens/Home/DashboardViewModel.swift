//
//  DashboardViewModel.swift
//  TrudataRider
//

import SwiftUI
import Combine

class DashboardViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var response: DashboardResponse?
    @Published var isLoggingOut = false

    private var cancellables = Set<AnyCancellable>()
    private let service = DashboardServiceManager()
    private var hasInitialLoadCompleted = false

    private static let homeRoutes: Set<String> = [
        "rider_orders",
        "rider_order_history",
        "rider_travel_history",
        "vehicle_overview",
        "support"
    ]

    var screenTitle: String {
        let title = response?.data?.screenTitle ?? ""
        return title.isEmptyString ? UserDefaultManager.shared.getUserDefaultsString(key: .userName) : title
    }

    var displayRole: String {
        let raw = response?.role ?? UserDefaultManager.shared.getUserDefaultsString(key: .userRole)
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var profileUrl: String {
        response?.data?.profileUrl ?? ""
    }

    var maintenanceMode: Bool {
        response?.maintenanceMode ?? false
    }

    var attendanceScreen: Bool {
        response?.attendanceScreen ?? false
    }

    var attendanceRoute: String {
        let route = response?.attendanceRoute ?? "attendance"
        return route.isEmptyString ? "attendance" : route
    }

    var allItems: [DashboardItem] {
        response?.data?.items ?? []
    }

    var homeItems: [DashboardItem] {
        allItems.filter { Self.homeRoutes.contains($0.route) }
    }

    func items(for type: RiderOperationsType) -> [DashboardItem] {
        allItems.filter { type.routes.contains($0.route) }
    }

    func loadHome(isRefresh: Bool = false) {
        if isRefresh || response != nil {
            isRefreshing = true
        } else {
            isLoading = true
        }
        errorMessage = nil

        service.loadHome(deviceId: DeviceInfo.current().deviceId)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                self.isRefreshing = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] model in
                guard let self else { return }
                self.isLoading = false
                self.isRefreshing = false
                if model.status {
                    self.response = model
                    if !model.role.isEmptyString {
                        UserDefaultManager.shared.setUserDefaultsString(value: model.role, key: .userRole)
                    }
                    self.hasInitialLoadCompleted = true
                    self.errorMessage = nil
                    self.fetchLocationConfig()
                } else {
                    self.errorMessage = model.message.isEmptyString ? "Failed to load dashboard." : model.message
                }
            }
            .store(in: &cancellables)
    }

    func loadHomeIfNeeded() {
        if !hasInitialLoadCompleted {
            loadHome()
        }
    }

    func loadHomeForResume() {
        if hasInitialLoadCompleted {
            loadHome(isRefresh: true)
        } else {
            loadHome()
        }
    }

    func logout() {
        isLoggingOut = true
        service.logout()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.finishLogout()
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }

    func softLogout() {
        finishLogout()
    }

    private func finishLogout() {
        isLoggingOut = false
        UserDefaultManager.shared.resetUserData()
        AppRootManager.shared.switchToAuth()
    }

    private func fetchLocationConfig() {
        service.fetchLocationConfig()
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { response in
                guard response.status, let data = response.data else { return }
                UserDefaultManager.shared.updateLocationConfig(data)
            })
            .store(in: &cancellables)
    }
}
