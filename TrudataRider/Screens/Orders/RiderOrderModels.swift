//
//  RiderOrderModels.swift
//  TrudataRider
//

import Foundation

enum RiderOrderStatus: String {
    case assign = "Assign"
    case pickup = "Pickup"
    case toDeliver = "To Deliver"
    case delivered = "Delivered"
    case cancelled = "Cancel"
    case returned = "Return"

    var title: String {
        switch self {
        case .assign: return "To Pick Up"
        case .pickup: return "Collected"
        case .toDeliver: return "To Deliver"
        case .delivered: return "Delivered"
        case .cancelled: return "Cancelled"
        case .returned: return "Returned"
        }
    }
}

struct RiderOrder: Identifiable {
    var id: String { orderId }
    let orderId: String
    let orderNo: String
    let shopName: String
    let date: String
    let distance: String
    let address: String
    let sellerPhone: String
    let latitude: String
    let longitude: String
    let statusRaw: String
    let staffName: String
    let staffMobile: String
    let remark: String
    let audioRemark: String
    let remarks: [RiderOrderRemark]

    var status: RiderOrderStatus {
        RiderOrderStatus(rawValue: statusRaw) ?? .assign
    }

    var displayDistance: String {
        let value = distance.trim
        if value.isEmptyString || value.uppercased() == "N/A" { return "" }
        return value.lowercased().contains("km") ? value : "\(value) Km"
    }

    var salesPersonName: String? {
        staffName.trim.nilIfEmpty
    }

    var showStaffButton: Bool {
        !staffMobile.trim.isEmptyString
    }

    var hasRemarks: Bool {
        !remark.trim.isEmptyString || !audioRemark.trim.isEmptyString || !remarks.isEmpty
    }

    var mapsURL: URL? {
        let lat = Double(latitude) ?? 0
        let lng = Double(longitude) ?? 0
        let query = shopName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "http://maps.apple.com/?ll=\(lat),\(lng)&q=\(query)")
    }
}

struct RiderOrderRemark: Identifiable {
    var id: String { "\(createdAt)-\(createdBy)-\(remark)" }
    let remark: String
    let audioRemark: String
    let createdBy: String
    let createdAt: String
}

struct RiderOrdersResponse: Decodable {
    var status: Bool
    var message: String
    var data: [RiderOrderDto]

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.first ?? ""
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }
        data = (try? container.decode([RiderOrderDto].self, forKey: .data)) ?? []
    }
}

struct RiderOrderDto: Decodable {
    var orderId: String
    var orderNo: String
    var sellerShopName: String
    var orderDate: String
    var distance: String
    var sellerAddress: String
    var mobile: String
    var latitude: String
    var longitude: String
    var status: String
    var staffName: String
    var staffMobile: String
    var remark: String
    var audioRemark: String
    var remarks: [RiderOrderRemarkDto]

    enum CodingKeys: String, CodingKey {
        case distance, mobile, latitude, longitude, status, remarks
        case orderId = "order_id"
        case orderNo = "order_no"
        case sellerShopName = "seller_shop_name"
        case orderDate = "order_date"
        case sellerAddress = "seller_address"
        case staffName = "staff_name"
        case staffMobile = "staff_mobile"
        case remark
        case audioRemark = "audio_remark"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = container.decodeStringLeniently(forKey: .orderId) ?? ""
        orderNo = container.decodeStringLeniently(forKey: .orderNo) ?? ""
        sellerShopName = container.decodeStringLeniently(forKey: .sellerShopName) ?? ""
        orderDate = container.decodeStringLeniently(forKey: .orderDate) ?? ""
        distance = container.decodeStringLeniently(forKey: .distance) ?? ""
        sellerAddress = container.decodeStringLeniently(forKey: .sellerAddress) ?? ""
        mobile = container.decodeStringLeniently(forKey: .mobile) ?? ""
        latitude = container.decodeStringLeniently(forKey: .latitude) ?? ""
        longitude = container.decodeStringLeniently(forKey: .longitude) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        staffName = container.decodeStringLeniently(forKey: .staffName) ?? ""
        staffMobile = container.decodeStringLeniently(forKey: .staffMobile) ?? ""
        remark = container.decodeStringLeniently(forKey: .remark) ?? ""
        audioRemark = container.decodeStringLeniently(forKey: .audioRemark) ?? ""
        remarks = (try? container.decode([RiderOrderRemarkDto].self, forKey: .remarks)) ?? []
    }

    func toDomain() -> RiderOrder {
        RiderOrder(
            orderId: orderId,
            orderNo: orderNo,
            shopName: sellerShopName,
            date: orderDate,
            distance: distance,
            address: sellerAddress,
            sellerPhone: mobile,
            latitude: latitude,
            longitude: longitude,
            statusRaw: status,
            staffName: staffName,
            staffMobile: staffMobile,
            remark: remark,
            audioRemark: audioRemark,
            remarks: remarks.map {
                RiderOrderRemark(
                    remark: $0.remark,
                    audioRemark: $0.audioRemark,
                    createdBy: $0.createdBy,
                    createdAt: $0.createdAt
                )
            }
        )
    }
}

struct RiderOrderRemarkDto: Decodable {
    var remark: String
    var audioRemark: String
    var createdBy: String
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case remark
        case audioRemark = "audio_remark"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        remark = container.decodeStringLeniently(forKey: .remark) ?? ""
        audioRemark = container.decodeStringLeniently(forKey: .audioRemark) ?? ""
        createdBy = container.decodeStringLeniently(forKey: .createdBy) ?? ""
        createdAt = container.decodeStringLeniently(forKey: .createdAt) ?? ""
    }
}

struct UpdateOrderStatusResponse: Decodable {
    var status: Bool
    var message: String

    enum CodingKeys: String, CodingKey {
        case status, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.first ?? ""
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }
    }
}

enum RiderOrdersTab: Hashable {
    case awaiting
    case toDeliver
    case completed

    var title: String {
        switch self {
        case .awaiting: return "Awaiting"
        case .toDeliver: return "To Deliver"
        case .completed: return "Completed"
        }
    }

    var screenTitle: String {
        switch self {
        case .awaiting: return "Awaiting Orders"
        case .toDeliver: return "Orders to Deliver"
        case .completed: return "Completed Orders"
        }
    }
}
