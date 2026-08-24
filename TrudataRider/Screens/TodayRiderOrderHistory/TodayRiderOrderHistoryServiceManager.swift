//
//  TodayRiderOrderHistoryServiceManager.swift
//  TrudataRider
//

import Foundation
import Combine

// MARK: - Domain

struct DeliveryHistoryOrder: Identifiable, Hashable {
    let id: Int
    let orderNumber: String
    let sellerShopName: String
    let sellerAddress: String
    let status: String
    let orderDate: String
    let deliveryDate: String
    let totalDistanceKm: Double
    let sellerLatitude: Double
    let sellerLongitude: Double

    var displayDistance: String {
        String(format: "%.1f km", totalDistanceKm)
    }

    var displayDeliveryDate: String {
        let value = deliveryDate.trim
        if value.isEmptyString || value == "0000-00-00" { return "N/A" }
        return value
    }

    var mapsURL: URL? {
        let query = sellerShopName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "http://maps.apple.com/?ll=\(sellerLatitude),\(sellerLongitude)&q=\(query)")
    }
}

struct DeliveryHistorySummary: Identifiable, Hashable {
    var id: String { statusId }
    let statusId: String
    let label: String
    let count: Int
}

// MARK: - DTOs

struct DeliveryHistoryResponse: Decodable {
    var status: Bool
    var message: String
    var currentPage: Int
    var lastPage: Int
    var total: Int
    var riderName: String
    var orders: [DeliveryHistoryOrder]
    var summary: [DeliveryHistorySummary]

    enum CodingKeys: String, CodingKey {
        case status, message, total, data, summary
        case currentPage = "current_page"
        case lastPage = "last_page"
        case riderName = "rider_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.first ?? ""
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 1
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 1
        total = container.decodeIntLeniently(forKey: .total) ?? 0
        riderName = container.decodeStringLeniently(forKey: .riderName) ?? ""

        if let page = try? container.decode(DeliveryHistoryPageDto.self, forKey: .data) {
            orders = page.data.map { $0.toDomain() }
            if page.currentPage > 0 { currentPage = page.currentPage }
        } else {
            orders = []
        }

        summary = (try? container.decode([DeliveryHistorySummaryDto].self, forKey: .summary))?.map {
            $0.toDomain()
        } ?? []
    }
}

private struct DeliveryHistoryPageDto: Decodable {
    var currentPage: Int
    var data: [DeliveryHistoryItemDto]

    enum CodingKeys: String, CodingKey {
        case data
        case currentPage = "current_page"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 1
        data = (try? container.decode([DeliveryHistoryItemDto].self, forKey: .data)) ?? []
    }
}

private struct DeliveryHistoryItemDto: Decodable {
    var orderId: Int
    var orderNo: String
    var sellerShopName: String
    var sellerAddress: String
    var sellerLatitude: String
    var sellerLongitude: String
    var status: String
    var orderDate: String
    var deliveryDate: String
    var totalDistance: String

    enum CodingKeys: String, CodingKey {
        case status
        case orderId = "order_id"
        case orderNo = "order_no"
        case sellerShopName = "seller_shop_name"
        case sellerAddress = "seller_address"
        case sellerLatitude = "seller_latitude"
        case sellerLongitude = "seller_longitude"
        case orderDate = "order_date"
        case deliveryDate = "delivery_date"
        case totalDistance = "total_distance"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = container.decodeIntLeniently(forKey: .orderId) ?? 0
        orderNo = container.decodeStringLeniently(forKey: .orderNo) ?? ""
        sellerShopName = container.decodeStringLeniently(forKey: .sellerShopName) ?? ""
        sellerAddress = container.decodeStringLeniently(forKey: .sellerAddress) ?? ""
        sellerLatitude = container.decodeStringLeniently(forKey: .sellerLatitude) ?? "0"
        sellerLongitude = container.decodeStringLeniently(forKey: .sellerLongitude) ?? "0"
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        orderDate = container.decodeStringLeniently(forKey: .orderDate) ?? ""
        deliveryDate = container.decodeStringLeniently(forKey: .deliveryDate) ?? ""
        totalDistance = container.decodeStringLeniently(forKey: .totalDistance) ?? "0"
    }

    func toDomain() -> DeliveryHistoryOrder {
        DeliveryHistoryOrder(
            id: orderId,
            orderNumber: orderNo,
            sellerShopName: sellerShopName,
            sellerAddress: sellerAddress,
            status: status,
            orderDate: orderDate,
            deliveryDate: deliveryDate,
            totalDistanceKm: Double(totalDistance) ?? 0,
            sellerLatitude: Double(sellerLatitude) ?? 0,
            sellerLongitude: Double(sellerLongitude) ?? 0
        )
    }
}

private struct DeliveryHistorySummaryDto: Decodable {
    var status: String
    var statusLabel: String
    var count: String

    enum CodingKeys: String, CodingKey {
        case status, count
        case statusLabel = "status_label"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        statusLabel = container.decodeStringLeniently(forKey: .statusLabel) ?? ""
        count = container.decodeStringLeniently(forKey: .count) ?? "0"
    }

    func toDomain() -> DeliveryHistorySummary {
        DeliveryHistorySummary(
            statusId: status,
            label: statusLabel,
            count: Int(count) ?? 0
        )
    }
}

// MARK: - Service

class TodayRiderOrderHistoryServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    func fetchHistory(
        startDate: String,
        endDate: String,
        dateType: String,
        orderId: String,
        sellerId: String,
        status: String,
        page: Int
    ) -> AnyPublisher<DeliveryHistoryResponse, Error> {
        var params: [String: Any] = ["page": "\(page)"]
        if !startDate.isEmptyString { params["start_date"] = startDate }
        if !endDate.isEmptyString { params["end_date"] = endDate }
        if !dateType.isEmptyString, dateType != "date" { params["date_type"] = dateType }
        if !orderId.isEmptyString { params["order_id"] = orderId }
        if !sellerId.isEmptyString { params["seller_id"] = sellerId }
        if !status.isEmptyString { params["status"] = status }

        return networkService.request(
            APIRouter.riderDeliveryHistory,
            params: params,
            headers: UserDefaultManager.shared.authHeader
        )
    }
}
