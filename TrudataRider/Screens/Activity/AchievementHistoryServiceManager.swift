//
//  AchievementHistoryServiceManager.swift
//  TrudataRider
//

import Foundation
import Combine

// MARK: - Domain

struct AchievementHistoryData {
    let sellerOrderCounts: [AchievementSellerOrders]
    let sellerCollections: [AchievementSellerCollection]
    let paymentModeStats: [AchievementPaymentModeStat]
    let paymentModeMap: [Int: String]

    var totalSellersOrdered: Int {
        sellerOrderCounts.reduce(0) { $0 + $1.orderCount }
    }

    var totalCollection: Double {
        sellerCollections.reduce(0) { $0 + $1.totalAmount }
    }

    var aggregatedPaymentModes: [AchievementPaymentModeSummary] {
        Dictionary(grouping: paymentModeStats, by: \.paymentModeId)
            .map { id, stats in
                AchievementPaymentModeSummary(
                    id: id,
                    label: paymentModeMap[id] ?? "Mode \(id)",
                    transactionCount: stats.reduce(0) { $0 + $1.transactionCount },
                    totalAmount: stats.reduce(0) { $0 + $1.totalAmount }
                )
            }
            .sorted { $0.totalAmount > $1.totalAmount }
    }
}

struct AchievementSellerOrders: Identifiable, Hashable {
    var id: String { sellerId.isEmpty ? sellerName : sellerId }
    let sellerId: String
    let sellerName: String
    let orderCount: Int
}

struct AchievementSellerCollection: Identifiable, Hashable {
    var id: String { sellerId.isEmpty ? sellerName : sellerId }
    let sellerId: String
    let sellerName: String
    let totalAmount: Double
}

struct AchievementPaymentModeStat: Hashable {
    let sellerId: String
    let sellerName: String
    let paymentModeId: Int
    let transactionCount: Int
    let totalAmount: Double
}

struct AchievementPaymentModeSummary: Identifiable, Hashable {
    let id: Int
    let label: String
    let transactionCount: Int
    let totalAmount: Double
}

// MARK: - Response

struct AchievementHistoryResponse: Decodable {
    var data: AchievementHistoryData

    enum CodingKeys: String, CodingKey {
        case todaySellerCount
        case todayCollectionAmount
        case paymentModeWise
        case statusMap
        case status
        case message
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // API may return payload at root or nested under `data`.
        let root = container
        let nested = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)
        let source = nested ?? root

        let sellers = (try? source.decode([SellerOrderCountDto].self, forKey: .todaySellerCount)) ?? []
        let collections = (try? source.decode([SellerCollectionDto].self, forKey: .todayCollectionAmount)) ?? []
        let modes = (try? source.decode([PaymentModeWiseDto].self, forKey: .paymentModeWise)) ?? []
        let statusItems = (try? source.decode([StatusMapItemDto].self, forKey: .statusMap)) ?? []

        var map: [Int: String] = [:]
        for item in statusItems {
            map[item.key] = item.label
        }

        data = AchievementHistoryData(
            sellerOrderCounts: sellers.map {
                AchievementSellerOrders(
                    sellerId: $0.sellerId,
                    sellerName: $0.sellerName,
                    orderCount: Int($0.orderCount) ?? 0
                )
            },
            sellerCollections: collections.map {
                AchievementSellerCollection(
                    sellerId: $0.sellerId,
                    sellerName: $0.sellerName,
                    totalAmount: Double($0.total) ?? 0
                )
            },
            paymentModeStats: modes.map {
                AchievementPaymentModeStat(
                    sellerId: $0.sellerId,
                    sellerName: $0.sellerName,
                    paymentModeId: Int($0.paymentMode) ?? 0,
                    transactionCount: Int($0.count) ?? 0,
                    totalAmount: Double($0.total) ?? 0
                )
            },
            paymentModeMap: map
        )
    }
}

private struct SellerOrderCountDto: Decodable {
    var sellerId: String
    var sellerName: String
    var orderCount: String

    enum CodingKeys: String, CodingKey {
        case sellerId = "seller_id"
        case sellerName = "seller_name"
        case orderCount = "order_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sellerId = c.decodeStringLeniently(forKey: .sellerId) ?? ""
        sellerName = c.decodeStringLeniently(forKey: .sellerName) ?? ""
        orderCount = c.decodeStringLeniently(forKey: .orderCount) ?? "0"
    }
}

private struct SellerCollectionDto: Decodable {
    var sellerId: String
    var sellerName: String
    var total: String

    enum CodingKeys: String, CodingKey {
        case total
        case sellerId = "seller_id"
        case sellerName = "seller_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sellerId = c.decodeStringLeniently(forKey: .sellerId) ?? ""
        sellerName = c.decodeStringLeniently(forKey: .sellerName) ?? ""
        total = c.decodeStringLeniently(forKey: .total) ?? "0"
    }
}

private struct PaymentModeWiseDto: Decodable {
    var sellerId: String
    var sellerName: String
    var paymentMode: String
    var count: String
    var total: String

    enum CodingKeys: String, CodingKey {
        case count, total
        case sellerId = "seller_id"
        case sellerName = "seller_name"
        case paymentMode = "payment_mode"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sellerId = c.decodeStringLeniently(forKey: .sellerId) ?? ""
        sellerName = c.decodeStringLeniently(forKey: .sellerName) ?? ""
        paymentMode = c.decodeStringLeniently(forKey: .paymentMode) ?? "0"
        count = c.decodeStringLeniently(forKey: .count) ?? "0"
        total = c.decodeStringLeniently(forKey: .total) ?? "0"
    }
}

private struct StatusMapItemDto: Decodable {
    var key: Int
    var label: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = c.decodeIntLeniently(forKey: .key) ?? 0
        label = c.decodeStringLeniently(forKey: .label) ?? ""
    }

    enum CodingKeys: String, CodingKey { case key, label }
}

// MARK: - Service

class AchievementHistoryServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    func fetchAchievements(startDate: String, endDate: String) -> AnyPublisher<AchievementHistoryResponse, Error> {
        var params: [String: Any] = [:]
        if !startDate.isEmptyString { params["start_date"] = startDate }
        if !endDate.isEmptyString { params["end_date"] = endDate }

        return networkService.request(
            APIRouter.todayAchievementsDetails,
            params: params,
            headers: UserDefaultManager.shared.authHeader
        )
    }
}
