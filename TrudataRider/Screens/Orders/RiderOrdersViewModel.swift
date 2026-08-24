//
//  RiderOrdersViewModel.swift
//  TrudataRider
//

import SwiftUI
import Combine
import CoreLocation

class RiderOrdersViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var isStartingDelivery = false
    @Published var updatingOrderId: String?
    @Published var errorMessage: String?
    @Published var toastMessage: String?
    @Published var selectedTab: RiderOrdersTab = .awaiting
    @Published var pickupOrders: [RiderOrder] = []
    @Published var collectedOrders: [RiderOrder] = []
    @Published var toDeliverOrders: [RiderOrder] = []
    @Published var deliveredOrders: [RiderOrder] = []

    private var cancellables = Set<AnyCancellable>()
    private let service = RiderOrdersServiceManager()
    private let locationHelper = LocationHelper()

    var availableTabs: [RiderOrdersTab] {
        var tabs: [RiderOrdersTab] = [.awaiting]
        if !toDeliverOrders.isEmpty { tabs.append(.toDeliver) }
        tabs.append(.completed)
        return tabs
    }

    var canStartDelivery: Bool {
        pickupOrders.isEmpty && !collectedOrders.isEmpty
    }

    var headerTitle: String {
        selectedTab.screenTitle
    }

    func loadOrders() {
        if pickupOrders.isEmpty && collectedOrders.isEmpty && toDeliverOrders.isEmpty && deliveredOrders.isEmpty {
            isLoading = true
        }
        errorMessage = nil

        resolveLocation { [weak self] location in
            guard let self else { return }
            guard let location else {
                self.isLoading = false
                self.errorMessage = "Location unavailable. Please enable location services and retry."
                return
            }
            self.fetchOrders(riderLocation: location)
        }
    }

    func markPickedUp(_ order: RiderOrder) {
        guard updatingOrderId == nil else { return }
        updatingOrderId = order.orderId

        service.updateOrderStatus(orderId: order.orderId)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.updatingOrderId = nil
                    self?.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.updatingOrderId = nil
                if response.status {
                    self.toastMessage = response.message.isEmptyString ? "Order picked up successfully!" : response.message
                    self.loadOrders()
                } else {
                    self.toastMessage = response.message.isEmptyString ? "Unable to update order." : response.message
                }
            }
            .store(in: &cancellables)
    }

    func startDelivery() {
        guard !isStartingDelivery else { return }
        isStartingDelivery = true

        resolveLocation { [weak self] location in
            guard let self else { return }
            guard let location else {
                self.isStartingDelivery = false
                self.toastMessage = "Location unavailable."
                return
            }

            self.service.startDelivery(riderLocation: location)
                .receive(on: RunLoop.main)
                .sink { [weak self] completion in
                    self?.isStartingDelivery = false
                    if case .failure(let error) = completion {
                        self?.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                    }
                } receiveValue: { [weak self] response in
                    self?.isStartingDelivery = false
                    self?.toastMessage = response.message.isEmptyString ? "Delivery started." : response.message
                    if response.status {
                        self?.loadOrders()
                    }
                }
                .store(in: &cancellables)
        }
    }

    func markDelivered(_ order: RiderOrder) {
        guard updatingOrderId == nil else { return }
        updatingOrderId = order.orderId

        resolveLocation { [weak self] location in
            guard let self else { return }
            guard let location else {
                self.updatingOrderId = nil
                self.toastMessage = "Location unavailable."
                return
            }

            self.service.markDelivered(orderId: order.orderId, riderLocation: location)
                .receive(on: RunLoop.main)
                .sink { [weak self] completion in
                    self?.updatingOrderId = nil
                    if case .failure(let error) = completion {
                        self?.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                    }
                } receiveValue: { [weak self] response in
                    self?.updatingOrderId = nil
                    self?.toastMessage = response.message
                    if response.status {
                        self?.loadOrders()
                    }
                }
                .store(in: &cancellables)
        }
    }

    private func fetchOrders(riderLocation: String) {
        service.fetchAssignedOrders(riderLocation: riderLocation)
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
                    let orders = response.data.map { $0.toDomain() }
                    self.pickupOrders = orders.filter { $0.status == .assign }
                    self.collectedOrders = orders.filter { $0.status == .pickup }
                    self.toDeliverOrders = orders.filter { $0.status == .toDeliver }
                    self.deliveredOrders = orders.filter { $0.status == .delivered }
                    self.errorMessage = nil
                    if !self.availableTabs.contains(self.selectedTab) {
                        self.selectedTab = self.availableTabs.first ?? .awaiting
                    }
                } else {
                    self.errorMessage = response.message.isEmptyString ? "No orders for today." : response.message
                }
            }
            .store(in: &cancellables)
    }

    private func resolveLocation(completion: @escaping (String?) -> Void) {
        if let snapshot = locationHelper.snapshot {
            completion(snapshot.coordinateString)
            return
        }

        locationHelper.refreshLocation()

        locationHelper.$snapshot
            .compactMap { $0?.coordinateString }
            .first()
            .timeout(.seconds(12), scheduler: RunLoop.main)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    completion(nil)
                }
            }, receiveValue: { value in
                completion(value)
            })
            .store(in: &cancellables)
    }
}
