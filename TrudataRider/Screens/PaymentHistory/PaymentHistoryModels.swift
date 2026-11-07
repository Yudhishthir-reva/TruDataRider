//
//  PaymentHistoryModels.swift
//  TrudataRider
//
//  `rider-transaction-history` — the rider's own collected payments, paged and filterable.
//  Ported from the Android app's `PaymentHistoryDto`.
//

import Foundation
import SwiftUI

struct PaymentTransaction: Decodable, Hashable, Identifiable {
    var id: Int
    var date: String
    var chequeClearDate: String?
    var paymentMode: String
    var amount: String
    var deductAmount: String
    var status: String
    var sellerName: String
    var staffName: String
    var imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, date, amount, status, image
        case chequeClearDate = "cheque_clear_date"
        case paymentMode = "payment_mode"
        case deductAmount = "deduct_amount"
        case sellerName = "seller_name"
        case staffName = "staff_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        chequeClearDate = container.decodeStringLeniently(forKey: .chequeClearDate)
        paymentMode = container.decodeStringLeniently(forKey: .paymentMode) ?? ""
        amount = container.decodeStringLeniently(forKey: .amount) ?? "0"
        deductAmount = container.decodeStringLeniently(forKey: .deductAmount) ?? "0"
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        sellerName = container.decodeStringLeniently(forKey: .sellerName) ?? ""
        staffName = container.decodeStringLeniently(forKey: .staffName) ?? ""
        imageUrl = container.decodeStringLeniently(forKey: .image)
    }

    var amountValue: Double {
        Double(amount.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    var deductValue: Double {
        Double(deductAmount.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    var hasImage: Bool {
        guard let imageUrl else { return false }
        return !imageUrl.isEmptyString
    }
}

/// The reply nests the paginator inside `data`, and the rows inside that again.
struct PaymentHistoryResponse: Decodable {
    var status: Bool
    var message: String
    var currentPage: Int
    var lastPage: Int
    var transactions: [PaymentTransaction]

    private struct Outer: Decodable {
        var currentPage: Int
        var lastPage: Int
        var inner: Inner?

        enum CodingKeys: String, CodingKey {
            case data
            case currentPage = "current_page"
            case lastPage = "last_page"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 1
            lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 1
            inner = try? container.decodeIfPresent(Inner.self, forKey: .data)
        }
    }

    private struct Inner: Decodable {
        var rows: [PaymentTransaction]

        enum CodingKeys: String, CodingKey {
            case data
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            rows = (try? container.decodeIfPresent([PaymentTransaction].self, forKey: .data)) ?? []
        }
    }

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        let outer = try? container.decodeIfPresent(Outer.self, forKey: .data)
        currentPage = outer?.currentPage ?? 1
        lastPage = outer?.lastPage ?? 1
        transactions = outer?.inner?.rows ?? []
    }

    var hasMore: Bool { currentPage < lastPage }
}

/// `payment_type` as the server spells it.
struct PaymentType: Identifiable, Hashable {
    let id: String
    let displayName: String

    static let all = PaymentType(id: "", displayName: "All")
    static let cash = PaymentType(id: "1", displayName: "Cash")
    static let cheque = PaymentType(id: "2", displayName: "Cheque")

    static let list = [all, cash, cheque]
}

/// `payment_status` as the server spells it.
struct PaymentApprovalStatus: Identifiable, Hashable {
    let id: String
    let displayName: String

    static let all = PaymentApprovalStatus(id: "", displayName: "All")
    static let pending = PaymentApprovalStatus(id: "0", displayName: "Pending")
    static let approved = PaymentApprovalStatus(id: "1", displayName: "Approved")
    static let unapproved = PaymentApprovalStatus(id: "2", displayName: "Unapproved")

    static let list = [all, pending, approved, unapproved]

    static func from(api value: String) -> PaymentApprovalStatus {
        list.first { $0.id == value } ?? pending
    }

    var color: Color {
        switch id {
        case "1": return DashboardTheme.successGreen
        case "2": return DashboardTheme.dangerRed
        case "0": return DashboardTheme.warningYellow
        default: return DashboardTheme.neutralMedium
        }
    }
}
