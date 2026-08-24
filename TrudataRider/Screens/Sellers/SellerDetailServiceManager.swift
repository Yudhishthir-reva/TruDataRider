//
//  SellerDetailServiceManager.swift
//  TrudataRider
//

import Foundation
import Combine

struct SellerProfileDetail {
    let id: Int
    let name: String
    let shopName: String
    let email: String
    let mobile: String
    let address: String
    let sellerCode: String
    let status: String
    let profilePic: String
    let latitude: String
    let longitude: String
    let beat: String
    let city: String

    var isActive: Bool {
        status.caseInsensitiveCompare("Active") == .orderedSame || status == "1"
    }

    var statusLabel: String { isActive ? "Active" : "Inactive" }

    var mapsURL: URL? {
        let lat = Double(latitude) ?? 0
        let lng = Double(longitude) ?? 0
        guard lat != 0 || lng != 0 else { return nil }
        let query = shopName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "http://maps.apple.com/?ll=\(lat),\(lng)&q=\(query)")
    }

    var mailURL: URL? {
        guard !email.isEmptyString else { return nil }
        return URL(string: "mailto:\(email.trim)")
    }

    var callURL: URL? {
        let digits = mobile.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://\(digits)")
    }
}

struct SellerProfileResponse: Decodable {
    var status: Bool
    var message: String
    var profile: SellerProfileDetail?

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    enum DataKeys: String, CodingKey {
        case profile
    }

    enum ProfileKeys: String, CodingKey {
        case id, name, email, mobile, status, city, state, address, beat, latitude, longitude
        case shopName = "shop_name"
        case sellerId = "seller_id"
        case profilePic = "profile_pic"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.first ?? ""
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }

        if let data = try? container.nestedContainer(keyedBy: DataKeys.self, forKey: .data),
           let profileContainer = try? data.nestedContainer(keyedBy: ProfileKeys.self, forKey: .profile) {
            profile = SellerProfileDetail(
                id: profileContainer.decodeIntLeniently(forKey: .id) ?? 0,
                name: profileContainer.decodeStringLeniently(forKey: .name) ?? "",
                shopName: profileContainer.decodeStringLeniently(forKey: .shopName) ?? "",
                email: profileContainer.decodeStringLeniently(forKey: .email) ?? "",
                mobile: profileContainer.decodeStringLeniently(forKey: .mobile) ?? "",
                address: profileContainer.decodeStringLeniently(forKey: .address) ?? "",
                sellerCode: profileContainer.decodeStringLeniently(forKey: .sellerId) ?? "",
                status: profileContainer.decodeStringLeniently(forKey: .status) ?? "",
                profilePic: profileContainer.decodeStringLeniently(forKey: .profilePic) ?? "",
                latitude: profileContainer.decodeStringLeniently(forKey: .latitude) ?? "",
                longitude: profileContainer.decodeStringLeniently(forKey: .longitude) ?? "",
                beat: profileContainer.decodeStringLeniently(forKey: .beat) ?? "",
                city: profileContainer.decodeStringLeniently(forKey: .city) ?? ""
            )
        } else {
            profile = nil
        }
    }
}

class SellerDetailServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    func fetchProfile(sellerId: String) -> AnyPublisher<SellerProfileResponse, Error> {
        networkService.request(
            APIRouter.sellerProfile,
            params: ["seller_id": sellerId],
            headers: UserDefaultManager.shared.authHeader
        )
    }
}
