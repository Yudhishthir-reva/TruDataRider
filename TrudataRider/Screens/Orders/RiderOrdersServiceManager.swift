//
//  RiderOrdersServiceManager.swift
//  TrudataRider
//

import Foundation
import Combine

class RiderOrdersServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    func fetchAssignedOrders(riderLocation: String) -> AnyPublisher<RiderOrdersResponse, Error> {
        networkService.request(
            APIRouter.orderAssignByRiderList,
            params: ["rider_location": riderLocation],
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func updateOrderStatus(orderId: String) -> AnyPublisher<UpdateOrderStatusResponse, Error> {
        networkService.request(
            APIRouter.orderStatusUpdate,
            params: ["order_id": orderId],
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func startDelivery(riderLocation: String) -> AnyPublisher<StatusMessageResponse, Error> {
        networkService.request(
            APIRouter.orderStartDelivery,
            params: ["rider_location": riderLocation],
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func markDelivered(orderId: String, riderLocation: String) -> AnyPublisher<StatusMessageResponse, Error> {
        networkService.request(
            APIRouter.orderDelivery,
            params: [
                "order_id": orderId,
                "rider_location": riderLocation
            ],
            headers: UserDefaultManager.shared.authHeader
        )
    }
}
