//
//  ProfileServiceManager.swift
//  TrudataRider
//
//

import Foundation
import Combine

// MARK: - Domain Model

struct UserProfileDetail: Equatable {
    let id: String
    let name: String
    let riderCode: String
    let role: String
    let joiningDate: String
    let status: String
    let mobile: String
    let email: String
    let location: String
    let profilePic: String

    var subtitle: String {
        if !riderCode.isEmptyString && !role.isEmptyString {
            return "\(role) (\(riderCode))"
        } else if !role.isEmptyString {
            return role
        } else if !riderCode.isEmptyString {
            return riderCode
        }
        return "Rider"
    }

    var displayEmail: String {
        email.isEmptyString ? "-" : email
    }

    var callURL: URL? {
        let digits = mobile.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://\(digits)")
    }

    var mailURL: URL? {
        guard !email.isEmptyString, email != "-" else { return nil }
        return URL(string: "mailto:\(email.trim)")
    }

    static var preview: UserProfileDetail {
        UserProfileDetail(
            id: "39",
            name: "Arman",
            riderCode: "TD-039",
            role: "Rider",
            joiningDate: "2026-07-31",
            status: "Active",
            mobile: "7657996189",
            email: "-",
            location: "Jaipur, RAJASTHAN",
            profilePic: ""
        )
    }
}

// MARK: - DTO & Decoding

struct UserProfileResponse: Decodable {
    var status: Bool
    var message: String
    var profile: UserProfileDetail?

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    enum ProfileKeys: String, CodingKey {
        case id, name, email, mobile, phone, status, city, state, address, location, role, doj
        case userId = "user_id"
        case riderId = "rider_id"
        case riderCode = "rider_code"
        case employeeCode = "employee_code"
        case code
        case userName = "user_name"
        case fullName = "full_name"
        case roleName = "role_name"
        case designation
        case joiningDate = "joining_date"
        case createdAt = "created_at"
        case profilePic = "profile_pic"
        case profileImage = "profile_image"
        case profileUrl = "profile_url"
        case image
        case user
        case profile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? true
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.first ?? ""
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }

        var profileContainer: KeyedDecodingContainer<ProfileKeys>?

        if let dataContainer = try? container.nestedContainer(keyedBy: ProfileKeys.self, forKey: .data) {
            if dataContainer.contains(.user),
               let nestedUser = try? dataContainer.nestedContainer(keyedBy: ProfileKeys.self, forKey: .user) {
                profileContainer = nestedUser
            } else if dataContainer.contains(.profile),
                      let nestedProfile = try? dataContainer.nestedContainer(keyedBy: ProfileKeys.self, forKey: .profile) {
                profileContainer = nestedProfile
            } else {
                profileContainer = dataContainer
            }
        }

        if let pc = profileContainer {
            let id = pc.decodeStringLeniently(forKey: .id)
                ?? pc.decodeStringLeniently(forKey: .userId)
                ?? pc.decodeIntLeniently(forKey: .id).map(String.init)
                ?? UserDefaultManager.shared.getUserDefaultsString(key: .userId)

            let name = pc.decodeStringLeniently(forKey: .name)
                ?? pc.decodeStringLeniently(forKey: .userName)
                ?? pc.decodeStringLeniently(forKey: .fullName)
                ?? UserDefaultManager.shared.getUserDefaultsString(key: .userName)

            let riderCode = pc.decodeStringLeniently(forKey: .riderCode)
                ?? pc.decodeStringLeniently(forKey: .riderId)
                ?? pc.decodeStringLeniently(forKey: .employeeCode)
                ?? pc.decodeStringLeniently(forKey: .code)
                ?? ""

            let role = pc.decodeStringLeniently(forKey: .role)
                ?? pc.decodeStringLeniently(forKey: .roleName)
                ?? pc.decodeStringLeniently(forKey: .designation)
                ?? UserDefaultManager.shared.getUserDefaultsString(key: .userRole)

            let joiningDate = pc.decodeStringLeniently(forKey: .joiningDate)
                ?? pc.decodeStringLeniently(forKey: .doj)
                ?? pc.decodeStringLeniently(forKey: .createdAt)
                ?? ""

            let status = pc.decodeStringLeniently(forKey: .status)
                ?? "Active"

            let mobile = pc.decodeStringLeniently(forKey: .mobile)
                ?? pc.decodeStringLeniently(forKey: .phone)
                ?? UserDefaultManager.shared.getUserDefaultsString(key: .userMobile)

            let email = pc.decodeStringLeniently(forKey: .email)
                ?? "-"

            let city = pc.decodeStringLeniently(forKey: .city) ?? ""
            let state = pc.decodeStringLeniently(forKey: .state) ?? ""
            let address = pc.decodeStringLeniently(forKey: .address) ?? ""
            let rawLocation = pc.decodeStringLeniently(forKey: .location) ?? ""

            let location: String
            if !rawLocation.isEmptyString {
                location = rawLocation
            } else if !city.isEmptyString && !state.isEmptyString {
                location = "\(city), \(state)"
            } else if !city.isEmptyString {
                location = city
            } else if !address.isEmptyString {
                location = address
            } else {
                location = "-"
            }

            let profilePic = pc.decodeStringLeniently(forKey: .profilePic)
                ?? pc.decodeStringLeniently(forKey: .profileImage)
                ?? pc.decodeStringLeniently(forKey: .profileUrl)
                ?? pc.decodeStringLeniently(forKey: .image)
                ?? ""

            self.profile = UserProfileDetail(
                id: id,
                name: name,
                riderCode: riderCode,
                role: role,
                joiningDate: joiningDate,
                status: status,
                mobile: mobile,
                email: email,
                location: location,
                profilePic: profilePic
            )
        } else {
            self.profile = nil
        }
    }
}

// MARK: - Service Manager

class ProfileServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    func fetchUserProfile() -> AnyPublisher<UserProfileResponse, Error> {
        networkService.request(
            APIRouter.loggedInUserProfile,
            params: [:],
            headers: UserDefaultManager.shared.authHeader
        )
    }
}
