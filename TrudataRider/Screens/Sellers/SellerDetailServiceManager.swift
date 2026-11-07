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
        guard !email.isEmptyString, email.isValidEmail() else { return nil }
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

    enum ProfileKeys: String, CodingKey {
        case id, name, email, mobile, status, city, state, address, beat, latitude, longitude
        case shopName = "shop_name"
        case sellerId = "seller_id"
        case profilePic = "profile_pic"
        case profile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.first ?? ""
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }

        // Rider API returns seller fields directly under `data`.
        // Admin-style responses may nest them under `data.profile`.
        if let dataContainer = try? container.nestedContainer(keyedBy: ProfileKeys.self, forKey: .data) {
            let profileContainer =
                (try? dataContainer.nestedContainer(keyedBy: ProfileKeys.self, forKey: .profile))
                ?? dataContainer

            let id = profileContainer.decodeIntLeniently(forKey: .id) ?? 0
            let name = profileContainer.decodeStringLeniently(forKey: .name) ?? ""
            let shopName = profileContainer.decodeStringLeniently(forKey: .shopName) ?? ""

            if id > 0 || !name.isEmptyString || !shopName.isEmptyString {
                profile = SellerProfileDetail(
                    id: id,
                    name: name,
                    shopName: shopName,
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
