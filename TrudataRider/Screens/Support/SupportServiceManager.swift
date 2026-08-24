//
//  SupportServiceManager.swift
//  TrudataRider
//
//  Created by Reva on 21/08/26.
//

import Foundation
import Combine

// MARK: - Models

struct SupportContactItem: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let phoneNumber: String
    let type: SupportContactType

    var formattedNumber: String {
        phoneNumber.isEmptyString ? "9257040297" : phoneNumber
    }

    var callURL: URL? {
        let digits = formattedNumber.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://\(digits)")
    }
}

enum SupportContactType: Equatable {
    case sales
    case rider

    var cardBackgroundColor: String {
        switch self {
        case .sales: return "EBF6EE"
        case .rider: return "FFF3E0"
        }
    }

    var titleColor: String {
        switch self {
        case .sales: return "2E7D32"
        case .rider: return "D9531E"
        }
    }

    var subtitleColor: String {
        switch self {
        case .sales: return "5A6B5C"
        case .rider: return "7D6A58"
        }
    }

    var buttonColor: String {
        switch self {
        case .sales: return "2E7D32"
        case .rider: return "D9531E"
        }
    }
}

// MARK: - Service Manager

class SupportServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    func getEmergencyContacts(salesNumber: String? = nil, riderNumber: String? = nil) -> [SupportContactItem] {
        let sales = (salesNumber?.isEmptyString == false) ? salesNumber! : "9257040297"
        let rider = (riderNumber?.isEmptyString == false) ? riderNumber! : "9257040297"

        return [
            SupportContactItem(
                id: "sales_support",
                title: "Sales Support",
                description: "For order issues, billing queries, and general support",
                phoneNumber: sales,
                type: .sales
            ),
            SupportContactItem(
                id: "rider_support",
                title: "Rider Support",
                description: "For delivery issues, rider assistance, and logistics",
                phoneNumber: rider,
                type: .rider
            )
        ]
    }
}
