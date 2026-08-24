//
//  TravelHistoryServiceManager.swift
//  TrudataRider
//

import Foundation
import Combine

// MARK: - Domain

struct RiderTravelHistoryData {
    let totalTravelled: Double
    let todayTravelled: Double
    let sellerWiseTravelled: [SellerWiseTravel]
    let failedOrders: [TravelFailedOrder]

    var totalDistanceLabel: String {
        String(format: "%.1f km", totalTravelled)
    }

    var todayDistanceLabel: String {
        String(format: "%.1f km", todayTravelled)
    }
}

struct SellerWiseTravel: Identifiable, Hashable {
    var id: String { sellerId.isEmpty ? shopName + sellerName : sellerId }
    let sellerId: String
    let sellerName: String
    let shopName: String
    let totalDistance: Double

    var title: String {
        shopName.isEmptyString ? sellerName : shopName
    }

    var distanceLabel: String {
        String(format: "%.1f km", totalDistance)
    }
}

struct TravelFailedOrder: Identifiable, Hashable {
    let id: Int
    let orderId: String
    let dateTime: String
    let latitude: Double
    let longitude: Double
    let remark: String
    let sellerName: String

    var displayDate: String {
        let value = dateTime.trim
        if value.count >= 10 { return String(value.prefix(10)) }
        return value.isEmptyString ? "N/A" : value
    }

    var mapsURL: URL? {
        guard latitude != 0 || longitude != 0 else { return nil }
        return URL(string: "http://maps.apple.com/?ll=\(latitude),\(longitude)&q=Failed%20Order")
    }
}

// MARK: - DTOs

struct TravelHistoryResponse: Decodable {
    var status: Bool
    var message: String
    var data: RiderTravelHistoryData?

    enum CodingKeys: String, CodingKey {
        case status, message, data
        case failedOrderData = "failed_order_data"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.first ?? ""
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }

        let travel = try? container.decode(TravelHistoryDataDto.self, forKey: .data)
        let failed = try? container.decode(FailedOrderDataDto.self, forKey: .failedOrderData)

        if let travel {
            data = RiderTravelHistoryData(
                totalTravelled: Double(travel.totalTravelled) ?? 0,
                todayTravelled: Double(travel.todayTravelled) ?? 0,
                sellerWiseTravelled: travel.sellerWiseTravelled.map { $0.toDomain() },
                failedOrders: failed?.orders.map { $0.toDomain() } ?? []
            )
        } else if status {
            data = RiderTravelHistoryData(
                totalTravelled: 0,
                todayTravelled: 0,
                sellerWiseTravelled: [],
                failedOrders: failed?.orders.map { $0.toDomain() } ?? []
            )
        } else {
            data = nil
        }
    }
}

private struct TravelHistoryDataDto: Decodable {
    var totalTravelled: String
    var todayTravelled: String
    var sellerWiseTravelled: [SellerWiseTravelledDto]

    enum CodingKeys: String, CodingKey {
        case totalTravelled = "total_travelled"
        case todayTravelled = "today_travelled"
        case sellerWiseTravelled = "seller_wise_travelled"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalTravelled = container.decodeStringLeniently(forKey: .totalTravelled) ?? "0"
        todayTravelled = container.decodeStringLeniently(forKey: .todayTravelled) ?? "0"
        sellerWiseTravelled = (try? container.decode([SellerWiseTravelledDto].self, forKey: .sellerWiseTravelled)) ?? []
    }
}

private struct SellerWiseTravelledDto: Decodable {
    var sellerId: String
    var sellerName: String
    var shopName: String
    var totalDistance: Double

    enum CodingKeys: String, CodingKey {
        case sellerId = "seller_id"
        case sellerName = "seller_name"
        case shopName = "shop_name"
        case totalDistance = "total_distance"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sellerId = container.decodeStringLeniently(forKey: .sellerId) ?? ""
        sellerName = container.decodeStringLeniently(forKey: .sellerName) ?? ""
        shopName = container.decodeStringLeniently(forKey: .shopName) ?? ""
        totalDistance = container.decodeDoubleLeniently(forKey: .totalDistance) ?? 0
    }

    func toDomain() -> SellerWiseTravel {
        SellerWiseTravel(
            sellerId: sellerId,
            sellerName: sellerName,
            shopName: shopName,
            totalDistance: totalDistance
        )
    }
}

private struct FailedOrderDataDto: Decodable {
    var orders: [FailedOrderDto]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orders = (try? container.decode([FailedOrderDto].self, forKey: .orders)) ?? []
    }

    enum CodingKeys: String, CodingKey { case orders }
}

private struct FailedOrderDto: Decodable {
    var id: Int
    var orderId: String
    var dateTime: String
    var lat: String
    var lng: String
    var remark: String
    var seller: FailedOrderSellerDto?

    enum CodingKeys: String, CodingKey {
        case id, lat, lng, remark, seller
        case orderId = "order_id"
        case dateTime = "date_time"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        orderId = container.decodeStringLeniently(forKey: .orderId) ?? ""
        dateTime = container.decodeStringLeniently(forKey: .dateTime) ?? ""
        lat = container.decodeStringLeniently(forKey: .lat) ?? "0"
        lng = container.decodeStringLeniently(forKey: .lng) ?? "0"
        remark = container.decodeStringLeniently(forKey: .remark) ?? ""
        seller = try? container.decode(FailedOrderSellerDto.self, forKey: .seller)
    }

    func toDomain() -> TravelFailedOrder {
        TravelFailedOrder(
            id: id,
            orderId: orderId,
            dateTime: dateTime,
            latitude: Double(lat) ?? 0,
            longitude: Double(lng) ?? 0,
            remark: remark,
            sellerName: seller?.name ?? "N/A"
        )
    }
}

private struct FailedOrderSellerDto: Decodable {
    var name: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decodeStringLeniently(forKey: .name) ?? ""
    }

    enum CodingKeys: String, CodingKey { case name }
}

// MARK: - Service

class TravelHistoryServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    func fetchTravelHistory(startDate: String, endDate: String) -> AnyPublisher<TravelHistoryResponse, Error> {
        var params: [String: Any] = [:]
        if !startDate.isEmptyString { params["start_date"] = startDate }
        if !endDate.isEmptyString { params["end_date"] = endDate }

        return networkService.request(
            APIRouter.riderTravelHistory,
            params: params,
            headers: UserDefaultManager.shared.authHeader
        )
    }
}
