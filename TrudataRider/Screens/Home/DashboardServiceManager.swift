//
//  DashboardServiceManager.swift
//  TrudataRider
//

import Foundation
import Combine

class DashboardServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    func loadHome(deviceId: String) -> AnyPublisher<DashboardResponse, Error> {
        networkService.request(
            APIRouter.homeV2,
            params: ["device_id": deviceId],
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func fetchLocationConfig() -> AnyPublisher<LocationConfigResponse, Error> {
        let userId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        return networkService.request(
            APIRouter.locationConfig,
            params: ["user_id": userId],
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func logout() -> AnyPublisher<StatusMessageResponse, Error> {
        let userId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        return networkService.request(
            APIRouter.logout,
            params: ["userId": userId],
            headers: UserDefaultManager.shared.authHeader
        )
    }
}
