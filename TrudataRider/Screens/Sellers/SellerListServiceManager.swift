//
//  SellerListServiceManager.swift
//  TrudataRider
//

import Foundation
import Combine

// MARK: - Models

struct RegisteredSeller: Identifiable, Hashable {
    let id: Int
    let name: String
    let shopName: String
    let mobile: String
    let city: String
    let beat: String
    let status: String
    let email: String
    let address: String
    let latitude: String
    let longitude: String
    let profilePic: String

    var isActive: Bool {
        status.caseInsensitiveCompare("Active") == .orderedSame || status == "1"
    }

    var statusLabel: String { isActive ? "ACTIVE" : "INACTIVE" }

    var cardTitle: String {
        shopName.isEmptyString ? name : "\(name) (\(shopName))"
    }
}

struct SellerListResponse: Decodable {
    var status: Bool
    var message: String
    var sellers: [RegisteredSeller]
    var currentPage: Int
    var lastPage: Int

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

        if let page = try? container.decode(SellerListPageDto.self, forKey: .data) {
            sellers = page.data.map { $0.toDomain() }
            currentPage = page.currentPage
            lastPage = page.lastPage
        } else {
            sellers = []
            currentPage = 1
            lastPage = 1
        }
    }
}

private struct SellerListPageDto: Decodable {
    var currentPage: Int
    var lastPage: Int
    var data: [SellerListItemDto]

    enum CodingKeys: String, CodingKey {
        case data
        case currentPage = "current_page"
        case lastPage = "last_page"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 1
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 1
        data = (try? container.decode([SellerListItemDto].self, forKey: .data)) ?? []
    }
}

private struct SellerListItemDto: Decodable {
    var id: Int
    var name: String
    var shopName: String
    var mobile: String
    var cityId: String
    var beatId: String
    var status: String
    var email: String
    var address: String
    var latitude: String
    var longitude: String
    var profilePic: String

    enum CodingKeys: String, CodingKey {
        case id, name, mobile, status, email, address, latitude, longitude
        case shopName = "shop_name"
        case cityId = "city_id"
        case beatId = "beat_id"
        case profilePic = "profile_pic"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeIntLeniently(forKey: .id) ?? 0
        name = c.decodeStringLeniently(forKey: .name) ?? ""
        shopName = c.decodeStringLeniently(forKey: .shopName) ?? ""
        mobile = c.decodeStringLeniently(forKey: .mobile) ?? ""
        cityId = c.decodeStringLeniently(forKey: .cityId) ?? ""
        beatId = c.decodeStringLeniently(forKey: .beatId) ?? ""
        status = c.decodeStringLeniently(forKey: .status) ?? ""
        email = c.decodeStringLeniently(forKey: .email) ?? ""
        address = c.decodeStringLeniently(forKey: .address) ?? ""
        latitude = c.decodeStringLeniently(forKey: .latitude) ?? ""
        longitude = c.decodeStringLeniently(forKey: .longitude) ?? ""
        profilePic = c.decodeStringLeniently(forKey: .profilePic) ?? ""
    }

    func toDomain() -> RegisteredSeller {
        RegisteredSeller(
            id: id,
            name: name,
            shopName: shopName,
            mobile: mobile,
            city: cityId,
            beat: beatId,
            status: status,
            email: email,
            address: address,
            latitude: latitude,
            longitude: longitude,
            profilePic: profilePic
        )
    }
}

// MARK: - Service

class SellerListServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    func fetchSellers(
        page: Int,
        shopName: String,
        status: String
    ) -> AnyPublisher<SellerListResponse, Error> {
        var params: [String: Any] = ["page": "\(page)"]
        if !shopName.isEmptyString { params["shop_name"] = shopName }
        if !status.isEmptyString { params["status"] = status }

        return networkService.request(
            APIRouter.sellerList2,
            params: params,
            headers: UserDefaultManager.shared.authHeader
        )
    }
}
