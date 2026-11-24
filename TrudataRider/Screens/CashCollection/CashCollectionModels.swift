//
//  CashCollectionModels.swift
//  TrudataRider
//
//  Ported from the Android app's `cashcollection` module. Field names and status strings are the
//  server's, so the two platforms read the same replies.
//

import Foundation

// MARK: - Denominations

/// Every note and coin the backend counts, in the order the form lists them.
///
/// `apiKey` is the request field (`note_500`, `coin_1` …) and, with `kind`, how a detail response's
/// `{label, type}` rows are matched back. The ₹5 note is still issued in small numbers and the API
/// counts it, so it stays even though most people only carry the coin.
enum Denomination: String, CaseIterable, Identifiable, Hashable {
    case note500, note200, note100, note50, note20, note10, note5
    case coin20, coin10, coin5, coin2, coin1

    enum Kind: String {
        case note, coin
    }

    var id: String { apiKey }

    var apiKey: String {
        switch self {
        case .note500: return "note_500"
        case .note200: return "note_200"
        case .note100: return "note_100"
        case .note50: return "note_50"
        case .note20: return "note_20"
        case .note10: return "note_10"
        case .note5: return "note_5"
        case .coin20: return "coin_20"
        case .coin10: return "coin_10"
        case .coin5: return "coin_5"
        case .coin2: return "coin_2"
        case .coin1: return "coin_1"
        }
    }

    var value: Int {
        switch self {
        case .note500: return 500
        case .note200: return 200
        case .note100: return 100
        case .note50: return 50
        case .note20, .coin20: return 20
        case .note10, .coin10: return 10
        case .note5, .coin5: return 5
        case .coin2: return 2
        case .coin1: return 1
        }
    }

    var kind: Kind {
        switch self {
        case .note500, .note200, .note100, .note50, .note20, .note10, .note5: return .note
        case .coin20, .coin10, .coin5, .coin2, .coin1: return .coin
        }
    }

    var label: String { "₹\(value)" }

    static let notes = allCases.filter { $0.kind == .note }
    static let coins = allCases.filter { $0.kind == .coin }

    /// Matches a detail row back to a case. Labels arrive as "₹500"; older docs show "500". Read the
    /// digits either way.
    static func from(label: String, type: String) -> Denomination? {
        let digits = label.split(separator: ".").first.map(String.init) ?? label
        guard let value = Int(digits.filter(\.isNumber)) else { return nil }
        let kind = type.trimmingCharacters(in: .whitespaces).lowercased()
        return allCases.first { $0.value == value && $0.kind.rawValue == kind }
    }
}

/// Counts per denomination. Missing entries are zero.
typealias DenominationCounts = [Denomination: Int]

extension Dictionary where Key == Denomination, Value == Int {

    var cashTotal: Int {
        reduce(0) { $0 + $1.key.value * $1.value }
    }

    func pieces(ofKind kind: Denomination.Kind) -> Int {
        filter { $0.key.kind == kind }.reduce(0) { $0 + $1.value }
    }
}

// MARK: - Shared primitives

struct PersonRef: Decodable, Hashable, Identifiable {
    var id: Int
    var name: String

    enum CodingKeys: String, CodingKey {
        case id, name
    }

    init(id: Int = 0, name: String = "") {
        self.id = id
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
    }
}

struct PageMeta: Decodable, Hashable {
    var total: Int
    var currentPage: Int
    var lastPage: Int

    enum CodingKeys: String, CodingKey {
        case total
        case currentPage = "current_page"
        case lastPage = "last_page"
    }

    init(total: Int = 0, currentPage: Int = 1, lastPage: Int = 1) {
        self.total = total
        self.currentPage = currentPage
        self.lastPage = lastPage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = container.decodeIntLeniently(forKey: .total) ?? 0
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 1
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 1
    }

    var hasMore: Bool { currentPage < lastPage }
}

/// A paged reply: rows in `data`, paging in `meta`. Both are optional on some endpoints, so a
/// missing `meta` degrades to a single page rather than failing the response.
struct PagedResponse<Item: Decodable>: Decodable {
    var items: [Item]
    var meta: PageMeta
    var message: String
    /// `status` (or `success`); false is a failure even on HTTP 200. Missing reads as true.
    var status: Bool

    enum CodingKeys: String, CodingKey {
        case data, meta, message, status, success
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
            ?? container.decodeBoolLeniently(forKey: .success)
            ?? true
        items = (try? container.decodeIfPresent([Item].self, forKey: .data)) ?? []
        meta = (try? container.decodeIfPresent(PageMeta.self, forKey: .meta))
            ?? PageMeta(total: items.count, currentPage: 1, lastPage: 1)
        message = container.decodeStringLeniently(forKey: .message) ?? ""
    }

    var hasMore: Bool { meta.hasMore }
}

/// `{ status, message, data: T }` — the shape every single-object cash endpoint answers with.
struct DataResponse<Payload: Decodable>: Decodable {
    var status: Bool
    var message: String
    var data: Payload?

    enum CodingKeys: String, CodingKey {
        case status, success, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
            ?? container.decodeBoolLeniently(forKey: .success)
            ?? true
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        data = try? container.decodeIfPresent(Payload.self, forKey: .data)
    }
}

/// `date_from` / `date_to` as sent; both nil means all time.
struct CashDateRange: Equatable {
    var from: String?
    var to: String?

    static let allTime = CashDateRange(from: nil, to: nil)

    var isAllTime: Bool { from == nil && to == nil }
}

/// Collection and amount-taken statuses as the server spells them.
enum CashStatus {
    static let pending = "pending"
    static let approved = "approved"
    static let rejected = "rejected"
}

// MARK: - Role access

/// What a signed-in role may do under Utility.
///
/// - Sale person and rider submit their own cash and see only their own submissions.
/// - Accountant and sales manager also see everyone's submissions, approve or reject them, record
///   amount taken and read the ledger, but cannot change a submission's counts.
/// - Admin can do all of that and edit a submission that is not approved yet.
///
/// The server enforces the same split (403 on the admin endpoints); this only decides what to show.
struct CashAccess: Equatable {
    var canReviewAll = false
    var canEditCollection = false
    var canManageAmountTaken = false
    var canViewLedger = false
    var canManageAdvance = false
    var canManageBills = false

    static func forRole(_ role: String?) -> CashAccess {
        switch role?.trimmingCharacters(in: .whitespaces).lowercased() {
        case "admin":
            return CashAccess(
                canReviewAll: true, canEditCollection: true, canManageAmountTaken: true,
                canViewLedger: true, canManageAdvance: true, canManageBills: true
            )
        case "accountant", "sales manager":
            return CashAccess(
                canReviewAll: true, canEditCollection: false, canManageAmountTaken: true,
                canViewLedger: true, canManageAdvance: true, canManageBills: true
            )
        default:
            return CashAccess()
        }
    }

    /// The signed-in user's access.
    ///
    /// Everyone signed in to the rider app is a rider, so the role is fixed here exactly as the
    /// Android app's `AppCashCollectionHost` fixes it. A rider submits cash and sees their own
    /// submissions; the review, amount-taken and ledger screens are never shown. If this app ever
    /// signs in other roles, read `userRole` from the session instead and the gating follows.
    static var current: CashAccess {
        forRole("rider")
    }
}

// MARK: - Cash collection

struct DenominationLine: Decodable, Hashable, Identifiable {
    var label: String
    var type: String
    var qty: Int
    var total: Double

    var id: String { "\(type)-\(label)" }

    enum CodingKeys: String, CodingKey {
        case label, type, qty, total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = container.decodeStringLeniently(forKey: .label) ?? ""
        type = container.decodeStringLeniently(forKey: .type) ?? ""
        qty = container.decodeIntLeniently(forKey: .qty) ?? 0
        total = container.decodeAmountLeniently(forKey: .total) ?? 0
    }

    var denomination: Denomination? { Denomination.from(label: label, type: type) }
}

struct CashCollection: Decodable, Hashable, Identifiable {
    var id: Int
    var totalAmount: Double
    var status: String
    var remark: String?
    var submitRemark: String?
    var submittedAt: String?
    var submittedBy: PersonRef?
    var reviewedBy: PersonRef?
    var denominations: [DenominationLine]

    enum CodingKeys: String, CodingKey {
        case id, status, remark, denominations
        case totalAmount = "total_amount"
        case submitRemark = "submit_remark"
        case submittedAt = "submitted_at"
        case submittedBy = "submitted_by"
        case reviewedBy = "reviewed_by"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        totalAmount = container.decodeAmountLeniently(forKey: .totalAmount) ?? 0
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        remark = container.decodeStringLeniently(forKey: .remark)
        submitRemark = container.decodeStringLeniently(forKey: .submitRemark)
        submittedAt = container.decodeStringLeniently(forKey: .submittedAt)
        submittedBy = try? container.decodeIfPresent(PersonRef.self, forKey: .submittedBy)
        reviewedBy = try? container.decodeIfPresent(PersonRef.self, forKey: .reviewedBy)
        denominations = (try? container.decodeIfPresent([DenominationLine].self, forKey: .denominations)) ?? []
    }

    var isPending: Bool { status.lowercased() == CashStatus.pending }
    var isApproved: Bool { status.lowercased() == CashStatus.approved }
    var isRejected: Bool { status.lowercased() == CashStatus.rejected }

    /// The counts behind this submission, for reopening it in the form.
    var counts: DenominationCounts {
        var result: DenominationCounts = [:]
        for line in denominations {
            guard let denomination = line.denomination else { continue }
            result[denomination, default: 0] += line.qty
        }
        return result
    }
}

struct AmountTaken: Decodable, Hashable, Identifiable {
    var id: Int
    var amount: Double
    var reason: String?
    var remark: String?
    var status: String
    var date: String
    var person: PersonRef?
    var takenBy: PersonRef?

    enum CodingKeys: String, CodingKey {
        case id, amount, reason, remark, status, date, person
        case takenBy = "taken_by"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        amount = container.decodeAmountLeniently(forKey: .amount) ?? 0
        reason = container.decodeStringLeniently(forKey: .reason)
        remark = container.decodeStringLeniently(forKey: .remark)
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        person = try? container.decodeIfPresent(PersonRef.self, forKey: .person)
        takenBy = try? container.decodeIfPresent(PersonRef.self, forKey: .takenBy)
    }

    var isPending: Bool { status.lowercased() == CashStatus.pending }
}

// MARK: - Denomination summary

struct SummaryDenomination: Decodable, Hashable, Identifiable {
    /// The request key (`note_500`, `coin_1` …).
    var field: String
    var label: String
    var qty: Int
    var total: Double

    var id: String { field }

    enum CodingKeys: String, CodingKey {
        case field, label, qty, total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        field = container.decodeStringLeniently(forKey: .field) ?? ""
        label = container.decodeStringLeniently(forKey: .label) ?? ""
        qty = container.decodeIntLeniently(forKey: .qty) ?? 0
        total = container.decodeAmountLeniently(forKey: .total) ?? 0
    }

    var denomination: Denomination? {
        Denomination.allCases.first { $0.apiKey == field }
    }
}

struct SummaryTotals: Decodable, Hashable {
    var totalEntries: Int
    var grandTotalAmount: Double
    var denominations: [SummaryDenomination]

    enum CodingKeys: String, CodingKey {
        case denominations
        case totalEntries = "total_entries"
        case grandTotalAmount = "grand_total_amount"
    }

    init(totalEntries: Int = 0, grandTotalAmount: Double = 0, denominations: [SummaryDenomination] = []) {
        self.totalEntries = totalEntries
        self.grandTotalAmount = grandTotalAmount
        self.denominations = denominations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalEntries = container.decodeIntLeniently(forKey: .totalEntries) ?? 0
        grandTotalAmount = container.decodeAmountLeniently(forKey: .grandTotalAmount) ?? 0
        denominations = (try? container.decodeIfPresent([SummaryDenomination].self, forKey: .denominations)) ?? []
    }
}

struct StaffSummary: Decodable, Hashable, Identifiable {
    var staffId: Int
    var staffName: String
    var entries: Int
    var totalAmount: Double
    var denominations: [SummaryDenomination]

    var id: Int { staffId }

    enum CodingKeys: String, CodingKey {
        case entries, denominations
        case staffId = "staff_id"
        case staffName = "staff_name"
        case totalAmount = "total_amount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        staffId = container.decodeIntLeniently(forKey: .staffId) ?? 0
        staffName = container.decodeStringLeniently(forKey: .staffName) ?? ""
        entries = container.decodeIntLeniently(forKey: .entries) ?? 0
        totalAmount = container.decodeAmountLeniently(forKey: .totalAmount) ?? 0
        denominations = (try? container.decodeIfPresent([SummaryDenomination].self, forKey: .denominations)) ?? []
    }
}

/// `V2/cash-collection/denomination-summary` — the reply is not wrapped in `data`; `summary` and
/// `staff_wise` sit at the top level.
struct DenominationSummaryResponse: Decodable {
    var summary: SummaryTotals
    var staffWise: [StaffSummary]
    var message: String
    var status: Bool

    enum CodingKeys: String, CodingKey {
        case summary, message, status, success
        case staffWise = "staff_wise"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
            ?? container.decodeBoolLeniently(forKey: .success)
            ?? true
        summary = (try? container.decodeIfPresent(SummaryTotals.self, forKey: .summary)) ?? SummaryTotals()
        staffWise = (try? container.decodeIfPresent([StaffSummary].self, forKey: .staffWise)) ?? []
        message = container.decodeStringLeniently(forKey: .message) ?? ""
    }
}

// MARK: - Ledger

enum LedgerType {
    static let collection = "collection"
    static let amountTaken = "amount_taken"
}

/// One line in `V2/cash-collection/ledger`: a collection coming in, or an amount taken out.
/// `balanceAfter` is the cash the staff member held after this line.
struct LedgerEntry: Decodable, Hashable, Identifiable {
    var type: String
    var entryId: Int
    var date: String
    var submittedAt: String?
    var staff: PersonRef?
    var amount: Double
    var status: String
    var remark: String?
    var reason: String?
    var takenBy: PersonRef?
    var balanceAfter: Double?

    /// Rows are unique per type, not per id: collection 4 and amount taken 4 are different lines.
    var id: String { "\(type)-\(entryId)" }

    enum CodingKeys: String, CodingKey {
        case type, id, date, staff, amount, status, remark, reason
        case submittedAt = "submitted_at"
        case takenBy = "taken_by"
        case balanceAfter = "balance_after"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = container.decodeStringLeniently(forKey: .type) ?? LedgerType.collection
        entryId = container.decodeIntLeniently(forKey: .id) ?? 0
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        submittedAt = container.decodeStringLeniently(forKey: .submittedAt)
        staff = try? container.decodeIfPresent(PersonRef.self, forKey: .staff)
        amount = container.decodeAmountLeniently(forKey: .amount) ?? 0
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        remark = container.decodeStringLeniently(forKey: .remark)
        reason = container.decodeStringLeniently(forKey: .reason)
        takenBy = try? container.decodeIfPresent(PersonRef.self, forKey: .takenBy)
        balanceAfter = container.decodeAmountLeniently(forKey: .balanceAfter)
    }

    var isTaken: Bool { type == LedgerType.amountTaken }

    /// Signed: what this line did to the cash in hand.
    var signedAmount: Double { isTaken ? -amount : amount }
}

/// Totals for the whole filter, not just the page.
struct LedgerSummary: Decodable, Hashable {
    var openingBalance: Double
    var totalCollection: Double
    var totalTaken: Double
    var netAmount: Double
    var closingBalance: Double

    enum CodingKeys: String, CodingKey {
        case openingBalance = "opening_balance"
        case totalCollection = "total_collection"
        case totalTaken = "total_taken"
        case netAmount = "net_amount"
        case closingBalance = "closing_balance"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        openingBalance = container.decodeAmountLeniently(forKey: .openingBalance) ?? 0
        totalCollection = container.decodeAmountLeniently(forKey: .totalCollection) ?? 0
        totalTaken = container.decodeAmountLeniently(forKey: .totalTaken) ?? 0
        netAmount = container.decodeAmountLeniently(forKey: .netAmount) ?? 0
        closingBalance = container.decodeAmountLeniently(forKey: .closingBalance) ?? 0
    }
}

struct LedgerDay: Decodable, Hashable, Identifiable {
    var date: String
    var totalCollection: Double
    var totalTaken: Double
    var netAmount: Double

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case date
        case totalCollection = "total_collection"
        case totalTaken = "total_taken"
        case netAmount = "net_amount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        totalCollection = container.decodeAmountLeniently(forKey: .totalCollection) ?? 0
        totalTaken = container.decodeAmountLeniently(forKey: .totalTaken) ?? 0
        netAmount = container.decodeAmountLeniently(forKey: .netAmount) ?? 0
    }
}

/// A ledger page plus the filter-wide figures that ride along with it.
struct LedgerResponse: Decodable {
    var entries: [LedgerEntry]
    var meta: PageMeta
    var summary: LedgerSummary?
    var days: [LedgerDay]
    var message: String
    var status: Bool

    enum CodingKeys: String, CodingKey {
        case data, meta, summary, days, message, status, success
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
            ?? container.decodeBoolLeniently(forKey: .success)
            ?? true
        entries = (try? container.decodeIfPresent([LedgerEntry].self, forKey: .data)) ?? []
        meta = (try? container.decodeIfPresent(PageMeta.self, forKey: .meta))
            ?? PageMeta(total: entries.count, currentPage: 1, lastPage: 1)
        summary = try? container.decodeIfPresent(LedgerSummary.self, forKey: .summary)
        days = (try? container.decodeIfPresent([LedgerDay].self, forKey: .days)) ?? []
        message = container.decodeStringLeniently(forKey: .message) ?? ""
    }

    var hasMore: Bool { meta.hasMore }
}

// MARK: - Payment advance

/// Advance statuses as the server spells them.
enum AdvanceStatus {
    static let pending = "pending"
    static let partial = "partial"
    static let completed = "completed"
    static let cancelled = "cancelled"
    static let onHold = "on_hold"

    static let all = [pending, partial, completed, onHold, cancelled]

    /// Money can still come back against an advance in these.
    static func isOpen(_ status: String) -> Bool {
        [pending, partial, onHold].contains(status.lowercased())
    }

    /// Android `advanceStatusLabel`.
    static func label(_ status: String) -> String {
        switch status.lowercased() {
        case pending: return "Pending"
        case partial: return "Partial"
        case completed: return "Completed"
        case cancelled: return "Cancelled"
        case onHold: return "On Hold"
        default:
            let spaced = status.replacingOccurrences(of: "_", with: " ")
            guard let first = spaced.first else { return "—" }
            return first.uppercased() + spaced.dropFirst()
        }
    }
}

/// The `type` filter, and each list row's `record_type`.
enum AdvanceRecordType {
    static let all = "all"
    static let advance = "advance"
    static let returned = "returned"
}

/// `person.role` comes back null today; the list fills it from the staff list instead.
struct AdvancePerson: Decodable, Hashable, Identifiable {
    var id: Int
    var name: String
    var role: String?

    enum CodingKeys: String, CodingKey {
        case id, name, role
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        role = container.decodeStringLeniently(forKey: .role)
    }
}

/// One payment received against an advance, as nested in `detail.returns`.
struct AdvanceReturn: Decodable, Hashable, Identifiable {
    var id: Int
    var advanceId: Int
    var amount: Double
    var remark: String?
    var attachment: String?
    var date: String
    var receivedBy: PersonRef?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, amount, remark, attachment, date
        case advanceId = "advance_id"
        case receivedBy = "received_by"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        advanceId = container.decodeIntLeniently(forKey: .advanceId) ?? 0
        amount = container.decodeAmountLeniently(forKey: .amount) ?? 0
        remark = container.decodeStringLeniently(forKey: .remark)
        attachment = container.decodeStringLeniently(forKey: .attachment)
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        receivedBy = try? container.decodeIfPresent(PersonRef.self, forKey: .receivedBy)
        createdAt = container.decodeStringLeniently(forKey: .createdAt)
    }
}

/// `give`, `receive`, `detail` and `update-status` all answer with this; only `detail` fills `returns`.
struct Advance: Decodable, Hashable, Identifiable {
    var id: Int
    var amount: Double
    var outstanding: Double
    var purpose: String?
    var attachment: String?
    var status: String
    var date: String
    var person: AdvancePerson?
    var givenBy: PersonRef?
    var createdAt: String?
    var returns: [AdvanceReturn]

    enum CodingKeys: String, CodingKey {
        case id, amount, outstanding, purpose, attachment, status, date, person, returns
        case givenBy = "given_by"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        amount = container.decodeAmountLeniently(forKey: .amount) ?? 0
        outstanding = container.decodeAmountLeniently(forKey: .outstanding) ?? 0
        purpose = container.decodeStringLeniently(forKey: .purpose)
        attachment = container.decodeStringLeniently(forKey: .attachment)
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        person = try? container.decodeIfPresent(AdvancePerson.self, forKey: .person)
        givenBy = try? container.decodeIfPresent(PersonRef.self, forKey: .givenBy)
        createdAt = container.decodeStringLeniently(forKey: .createdAt)
        returns = (try? container.decodeIfPresent([AdvanceReturn].self, forKey: .returns)) ?? []
    }

    var returned: Double { amount - outstanding }
    var isOpen: Bool { AdvanceStatus.isOpen(status) }
}

/// One line of `all-list` / `my-list`: an advance given, or a payment returned against one. The two
/// share the list, so fields that belong to one kind only are optional.
struct AdvanceRecord: Decodable, Hashable, Identifiable {
    var recordType: String
    var recordId: Int
    /// Returned rows only: the advance this payment went against.
    var parentAdvanceId: Int?
    var amount: Double
    var outstanding: Double?
    var purpose: String?
    var remark: String?
    var attachment: String?
    /// Advance rows only; a returned row has no status of its own.
    var status: String?
    var date: String
    var person: AdvancePerson?
    var givenBy: PersonRef?
    var receivedBy: PersonRef?
    var createdAt: String?

    /// Advance 3 and return 3 are different rows.
    var id: String { "\(recordType)-\(recordId)" }

    enum CodingKeys: String, CodingKey {
        case id, amount, outstanding, purpose, remark, attachment, status, date, person
        case recordType = "record_type"
        case advanceId = "advance_id"
        case givenBy = "given_by"
        case receivedBy = "received_by"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recordType = container.decodeStringLeniently(forKey: .recordType) ?? AdvanceRecordType.advance
        recordId = container.decodeIntLeniently(forKey: .id) ?? 0
        parentAdvanceId = container.decodeIntLeniently(forKey: .advanceId)
        amount = container.decodeAmountLeniently(forKey: .amount) ?? 0
        outstanding = container.decodeAmountLeniently(forKey: .outstanding)
        purpose = container.decodeStringLeniently(forKey: .purpose)
        remark = container.decodeStringLeniently(forKey: .remark)
        attachment = container.decodeStringLeniently(forKey: .attachment)
        status = container.decodeStringLeniently(forKey: .status)
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        person = try? container.decodeIfPresent(AdvancePerson.self, forKey: .person)
        givenBy = try? container.decodeIfPresent(PersonRef.self, forKey: .givenBy)
        receivedBy = try? container.decodeIfPresent(PersonRef.self, forKey: .receivedBy)
        createdAt = container.decodeStringLeniently(forKey: .createdAt)
    }

    var isReturn: Bool { recordType == AdvanceRecordType.returned }

    /// The advance to open when the row is tapped.
    var advanceId: Int { isReturn ? (parentAdvanceId ?? 0) : recordId }
}

/// Filter-wide totals. A manager's list fills the first three, a sale person's or rider's own list
/// the last two.
struct AdvanceSummary: Decodable, Hashable {
    var advanceGiven: Double
    var paymentReceived: Double
    var pendingReturn: Double
    var advanceReceived: Double
    var returned: Double

    enum CodingKeys: String, CodingKey {
        case returned
        case advanceGiven = "advance_given"
        case paymentReceived = "payment_received"
        case pendingReturn = "pending_return"
        case advanceReceived = "advance_received"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        advanceGiven = container.decodeAmountLeniently(forKey: .advanceGiven) ?? 0
        paymentReceived = container.decodeAmountLeniently(forKey: .paymentReceived) ?? 0
        pendingReturn = container.decodeAmountLeniently(forKey: .pendingReturn) ?? 0
        advanceReceived = container.decodeAmountLeniently(forKey: .advanceReceived) ?? 0
        returned = container.decodeAmountLeniently(forKey: .returned) ?? 0
    }
}

struct AdvanceListResponse: Decodable {
    var items: [AdvanceRecord]
    var meta: PageMeta
    var summary: AdvanceSummary?
    var message: String
    var status: Bool

    enum CodingKeys: String, CodingKey {
        case data, meta, summary, message, status, success
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
            ?? container.decodeBoolLeniently(forKey: .success)
            ?? true
        items = (try? container.decodeIfPresent([AdvanceRecord].self, forKey: .data)) ?? []
        meta = (try? container.decodeIfPresent(PageMeta.self, forKey: .meta))
            ?? PageMeta(total: items.count, currentPage: 1, lastPage: 1)
        summary = try? container.decodeIfPresent(AdvanceSummary.self, forKey: .summary)
        message = container.decodeStringLeniently(forKey: .message) ?? ""
    }

    var hasMore: Bool { meta.hasMore }
}

/// What `all-list` is narrowed by; blanks and nils are left out of the request.
struct AdvanceQuery: Equatable {
    var type: String = AdvanceRecordType.all
    var range: CashDateRange = .allTime
    var status: String?
    var roleId: Int?
    var search: String = ""
    var staffIds: Set<Int> = []
}

// MARK: - Bill register

/// Register and register-order statuses as the server spells them.
enum BillStatus {
    static let pending = "pending"
    static let cleared = "cleared"
    /// A register a manager called off; its orders went back to unassigned.
    static let cancelled = "cancelled"
    /// An order taken out of its register; kept as history, out of the totals.
    static let removed = "removed"
}

private extension KeyedDecodingContainer {
    /// Android's `FlexStringSerializer`: `removed_by` / `cancelled_by` come as "" when no one did it,
    /// and a blank name must read as no one rather than as "Removed by ".
    func decodeNameLeniently(forKey key: Key) -> String? {
        let text = decodeStringLeniently(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }
}

/// `removed_at` / `cancelled_at` come raw ("2026-10-26 12:47:57"); this shows them like the server's
/// own formatted dates ("26-Oct-2026 12:47 PM"). Anything else is shown as sent.
func billStamp(_ raw: String?) -> String? {
    guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
    let parse = DateFormatter()
    parse.locale = Locale(identifier: "en_US_POSIX")
    parse.dateFormat = "yyyy-MM-dd HH:mm:ss"
    guard let date = parse.date(from: raw) else { return raw }
    let show = DateFormatter()
    show.locale = Locale(identifier: "en_US_POSIX")
    show.dateFormat = "dd-MMM-yyyy hh:mm a"
    return show.string(from: date)
}

func billCount(_ n: Int) -> String { "\(n) bill" + (n == 1 ? "" : "s") }

/// The create screen's picks, apart from the view model so the rules can be checked on their own
/// (Android `BillCreateUiState`).
struct BillCreatePicks {
    var selectedBeats: Set<Int> = []
    var orders: [BeatOrder] = []
    var selectedOrders: Set<Int> = []
    /// Set once created; the picks are saved from then on.
    var createdId: Int?

    var picked: [BeatOrder] { orders.filter { selectedOrders.contains($0.orderId) } }

    /// Picked bills that switching to beats `ids` would untick.
    func droppedBy(_ ids: Set<Int>) -> [BeatOrder] { picked.filter { !ids.contains($0.beatId) } }

    /// Picks not yet saved: worth a word before leaving the screen.
    var hasPicks: Bool { !selectedOrders.isEmpty && createdId == nil }
}

struct Beat: Decodable, Hashable, Identifiable {
    var id: Int
    var name: String
    var status: Int
    var isDelete: Int

    enum CodingKeys: String, CodingKey {
        case id, name, status
        case isDelete = "is_delete"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        status = container.decodeIntLeniently(forKey: .status) ?? 1
        isDelete = container.decodeIntLeniently(forKey: .isDelete) ?? 0
    }

    var isActive: Bool { status == 1 && isDelete == 0 }
}

/// `beat-list` answers with Laravel's paginator: rows in `data.data`, `last_page` beside them.
struct BeatListResponse: Decodable {
    var beats: [Beat]
    var currentPage: Int
    var lastPage: Int
    var message: String

    private struct Paginator: Decodable {
        var data: [Beat]
        var currentPage: Int
        var lastPage: Int

        enum CodingKeys: String, CodingKey {
            case data
            case currentPage = "current_page"
            case lastPage = "last_page"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            data = (try? container.decodeIfPresent([Beat].self, forKey: .data)) ?? []
            currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 1
            lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 1
        }
    }

    enum CodingKeys: String, CodingKey {
        case data, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let paginator = try? container.decodeIfPresent(Paginator.self, forKey: .data)
        beats = paginator?.data ?? []
        currentPage = paginator?.currentPage ?? 1
        lastPage = paginator?.lastPage ?? 1
        message = container.decodeStringLeniently(forKey: .message) ?? ""
    }
}

/// A delivered order with payment pending, from `bill-register/beat-orders`. `isAssigned` orders
/// already sit in a register and must not be put in another (the server doesn't stop it).
struct BeatOrder: Decodable, Hashable, Identifiable {
    var orderId: Int
    var orderNo: String
    var sellerName: String?
    var sellerShopName: String?
    var sellerMobile: String?
    var beatId: Int
    var beatName: String?
    var staffName: String?
    var totalPrice: Double
    var pendingAmount: Double
    var deliveryDate: String?
    var orderDate: String?
    var isAssigned: Bool
    var billRegisterId: Int?
    var billRegisterAssignedToName: String?
    var billRegisterStatus: String?

    var id: Int { orderId }

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case orderNo = "order_no"
        case sellerName = "seller_name"
        case sellerShopName = "seller_shop_name"
        case sellerMobile = "seller_mobile"
        case beatId = "beat_id"
        case beatName = "beat_name"
        case staffName = "staff_name"
        case totalPrice = "total_price"
        case pendingAmount = "pending_amount"
        case deliveryDate = "delivery_date"
        case orderDate = "order_date"
        case isAssigned = "is_assigned"
        case billRegisterId = "bill_register_id"
        case billRegisterAssignedToName = "bill_register_assigned_to_name"
        case billRegisterStatus = "bill_register_status"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = container.decodeIntLeniently(forKey: .orderId) ?? 0
        orderNo = container.decodeStringLeniently(forKey: .orderNo) ?? ""
        sellerName = container.decodeStringLeniently(forKey: .sellerName)
        sellerShopName = container.decodeStringLeniently(forKey: .sellerShopName)
        sellerMobile = container.decodeStringLeniently(forKey: .sellerMobile)
        beatId = container.decodeIntLeniently(forKey: .beatId) ?? 0
        beatName = container.decodeStringLeniently(forKey: .beatName)
        staffName = container.decodeStringLeniently(forKey: .staffName)
        totalPrice = container.decodeAmountLeniently(forKey: .totalPrice) ?? 0
        pendingAmount = container.decodeAmountLeniently(forKey: .pendingAmount) ?? 0
        deliveryDate = container.decodeStringLeniently(forKey: .deliveryDate)
        orderDate = container.decodeStringLeniently(forKey: .orderDate)
        isAssigned = container.decodeBoolLeniently(forKey: .isAssigned) ?? false
        billRegisterId = container.decodeIntLeniently(forKey: .billRegisterId)
        billRegisterAssignedToName = container.decodeStringLeniently(forKey: .billRegisterAssignedToName)
        billRegisterStatus = container.decodeStringLeniently(forKey: .billRegisterStatus)
    }

    var shopLabel: String {
        let shop = sellerShopName?.trimmingCharacters(in: .whitespaces) ?? ""
        if !shop.isEmpty { return shop }
        return sellerName?.trimmingCharacters(in: .whitespaces) ?? "—"
    }
}

struct BeatOrdersPayload: Decodable {
    var total: Int
    var orders: [BeatOrder]

    enum CodingKeys: String, CodingKey {
        case total, orders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = container.decodeIntLeniently(forKey: .total) ?? 0
        orders = (try? container.decodeIfPresent([BeatOrder].self, forKey: .orders)) ?? []
    }
}

/// One order inside a register (`detail.orders`). `paymentStatus` is pending or cleared; removed once
/// taken out of the register; cancelled when the register was cancelled with it still pending.
/// `removedAt` comes raw (`yyyy-MM-dd HH:mm:ss`), unlike the formatted dates beside it.
struct RegisterOrder: Decodable, Hashable, Identifiable {
    var registerOrderId: Int
    var orderId: Int
    var orderNo: String
    var sellerName: String?
    var sellerShopName: String?
    var sellerMobile: String?
    var beatName: String?
    var staffName: String?
    var orderAmount: Double
    var pendingAmount: Double
    /// The order's pending payment right now, which can have dropped since the register was made.
    var currentPending: Double
    var paymentStatus: String
    var clearedAt: String?
    var deliveryDate: String?
    var removedBy: String?
    var removedAt: String?
    var removeReason: String?

    var id: Int { registerOrderId }

    enum CodingKeys: String, CodingKey {
        case registerOrderId = "register_order_id"
        case orderId = "order_id"
        case orderNo = "order_no"
        case sellerName = "seller_name"
        case sellerShopName = "seller_shop_name"
        case sellerMobile = "seller_mobile"
        case beatName = "beat_name"
        case staffName = "staff_name"
        case orderAmount = "order_amount"
        case pendingAmount = "pending_amount"
        case currentPending = "current_pending"
        case paymentStatus = "payment_status"
        case clearedAt = "cleared_at"
        case deliveryDate = "delivery_date"
        case removedBy = "removed_by"
        case removedAt = "removed_at"
        case removeReason = "remove_reason"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        registerOrderId = container.decodeIntLeniently(forKey: .registerOrderId) ?? 0
        orderId = container.decodeIntLeniently(forKey: .orderId) ?? 0
        orderNo = container.decodeStringLeniently(forKey: .orderNo) ?? ""
        sellerName = container.decodeStringLeniently(forKey: .sellerName)
        sellerShopName = container.decodeStringLeniently(forKey: .sellerShopName)
        sellerMobile = container.decodeStringLeniently(forKey: .sellerMobile)
        beatName = container.decodeStringLeniently(forKey: .beatName)
        staffName = container.decodeStringLeniently(forKey: .staffName)
        orderAmount = container.decodeAmountLeniently(forKey: .orderAmount) ?? 0
        pendingAmount = container.decodeAmountLeniently(forKey: .pendingAmount) ?? 0
        currentPending = container.decodeAmountLeniently(forKey: .currentPending) ?? 0
        paymentStatus = container.decodeStringLeniently(forKey: .paymentStatus) ?? BillStatus.pending
        clearedAt = container.decodeStringLeniently(forKey: .clearedAt)
        deliveryDate = container.decodeStringLeniently(forKey: .deliveryDate)
        removedBy = container.decodeNameLeniently(forKey: .removedBy)
        removedAt = container.decodeStringLeniently(forKey: .removedAt)
        removeReason = container.decodeStringLeniently(forKey: .removeReason)
    }

    var isCleared: Bool { paymentStatus.lowercased() == BillStatus.cleared }
    var isRemoved: Bool { paymentStatus.lowercased() == BillStatus.removed }
    var isCancelled: Bool { paymentStatus.lowercased() == BillStatus.cancelled }
    /// Still to collect: the only orders that can be cleared.
    var isPending: Bool { paymentStatus.lowercased() == BillStatus.pending }

    var shopLabel: String {
        let shop = sellerShopName?.trimmingCharacters(in: .whitespaces) ?? ""
        if !shop.isEmpty { return shop }
        return sellerName?.trimmingCharacters(in: .whitespaces) ?? "—"
    }
}

/// A register as listed; `detail` adds `orders`. `totalOrders` counts removed orders too, while
/// `totalAmount` leaves them out. `cancelledAt` comes raw, like `RegisterOrder.removedAt`.
struct BillRegister: Decodable, Hashable, Identifiable {
    var id: Int
    var beatNames: [String]
    var assignedToId: Int?
    var assignedTo: String?
    var assignedBy: String?
    var status: String
    var totalOrders: Int
    var pendingOrders: Int
    var clearedOrders: Int
    var removedOrders: Int
    /// Orders still pending when the register was cancelled.
    var cancelledOrders: Int
    var totalAmount: Double
    var pendingAmount: Double
    var clearedAt: String?
    var createdAt: String?
    var cancelledBy: String?
    var cancelledAt: String?
    var cancelReason: String?
    var orders: [RegisterOrder]

    enum CodingKeys: String, CodingKey {
        case id, status, orders
        case beatNames = "beat_names"
        case assignedToId = "assigned_to_id"
        case assignedTo = "assigned_to"
        case assignedBy = "assigned_by"
        case totalOrders = "total_orders"
        case pendingOrders = "pending_orders"
        case clearedOrders = "cleared_orders"
        case removedOrders = "removed_orders"
        case cancelledOrders = "cancelled_orders"
        case totalAmount = "total_amount"
        case pendingAmount = "pending_amount"
        case clearedAt = "cleared_at"
        case createdAt = "created_at"
        case cancelledBy = "cancelled_by"
        case cancelledAt = "cancelled_at"
        case cancelReason = "cancel_reason"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        beatNames = (try? container.decodeIfPresent([String].self, forKey: .beatNames)) ?? []
        assignedToId = container.decodeIntLeniently(forKey: .assignedToId)
        assignedTo = container.decodeStringLeniently(forKey: .assignedTo)
        assignedBy = container.decodeStringLeniently(forKey: .assignedBy)
        status = container.decodeStringLeniently(forKey: .status) ?? BillStatus.pending
        totalOrders = container.decodeIntLeniently(forKey: .totalOrders) ?? 0
        pendingOrders = container.decodeIntLeniently(forKey: .pendingOrders) ?? 0
        clearedOrders = container.decodeIntLeniently(forKey: .clearedOrders) ?? 0
        removedOrders = container.decodeIntLeniently(forKey: .removedOrders) ?? 0
        cancelledOrders = container.decodeIntLeniently(forKey: .cancelledOrders) ?? 0
        totalAmount = container.decodeAmountLeniently(forKey: .totalAmount) ?? 0
        pendingAmount = container.decodeAmountLeniently(forKey: .pendingAmount) ?? 0
        clearedAt = container.decodeStringLeniently(forKey: .clearedAt)
        createdAt = container.decodeStringLeniently(forKey: .createdAt)
        cancelledBy = container.decodeNameLeniently(forKey: .cancelledBy)
        cancelledAt = container.decodeStringLeniently(forKey: .cancelledAt)
        cancelReason = container.decodeStringLeniently(forKey: .cancelReason)
        orders = (try? container.decodeIfPresent([RegisterOrder].self, forKey: .orders)) ?? []
    }

    var isCleared: Bool { status.lowercased() == BillStatus.cleared }
    var isCancelled: Bool { status.lowercased() == BillStatus.cancelled }
    var isPending: Bool { status.lowercased() == BillStatus.pending }
    /// The orders still counted in the register: everything but the removed ones.
    var activeOrders: Int { max(totalOrders - removedOrders, 0) }

    var beatsLabel: String {
        beatNames.isEmpty ? "—" : beatNames.joined(separator: ", ")
    }
}

/// `bill-register/list` pages a fixed 10 and puts the paging fields at the top level rather than
/// under `meta`.
struct BillRegisterListResponse: Decodable {
    /// False when the server refused (it still answers 200); the page then shows `message`.
    var status: Bool
    var items: [BillRegister]
    var meta: PageMeta
    var message: String

    enum CodingKeys: String, CodingKey {
        case status, data, total, message
        case currentPage = "current_page"
        case lastPage = "last_page"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? true
        items = (try? container.decodeIfPresent([BillRegister].self, forKey: .data)) ?? []
        meta = PageMeta(
            total: container.decodeIntLeniently(forKey: .total) ?? items.count,
            currentPage: container.decodeIntLeniently(forKey: .currentPage) ?? 1,
            lastPage: container.decodeIntLeniently(forKey: .lastPage) ?? 1
        )
        message = container.decodeStringLeniently(forKey: .message) ?? ""
    }

    var hasMore: Bool { meta.hasMore }
}

/// `bill-register/create` answers with the new register's id under `data`.
struct BillRegisterCreateResponse: Decodable {
    var billRegisterId: Int
    var message: String

    private struct Payload: Decodable {
        var billRegisterId: Int

        enum CodingKeys: String, CodingKey {
            case billRegisterId = "bill_register_id"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            billRegisterId = container.decodeIntLeniently(forKey: .billRegisterId) ?? 0
        }
    }

    enum CodingKeys: String, CodingKey {
        case data, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        billRegisterId = (try? container.decodeIfPresent(Payload.self, forKey: .data))?.billRegisterId ?? 0
        message = container.decodeStringLeniently(forKey: .message) ?? ""
    }
}

/// Android `PersonOption`: someone a register can be assigned to, as the person picker lists them.
struct PersonOption: Hashable, Identifiable {
    var id: Int
    var name: String
    var role: String

    /// "Name (Role)", or just the name when the role is blank, as the picker field and the create
    /// summary show it.
    var nameWithRole: String { role.isEmpty ? name : "\(name) (\(role))" }
}

/// Android `PeopleState`: the staff list behind the person picker.
struct PeopleState: Equatable {
    var items: [PersonOption] = []
    var isLoading = false
    var error: String?
}

/// `staff-list`: `{ status, data: [{ id, name, role_id }] }`, where `role_id` carries the role's
/// name. Rows without an id or a name can't be assigned anything and are dropped.
struct StaffPeopleResponse: Decodable {
    var status: Bool
    var message: String
    var people: [PersonOption]

    private struct Row: Decodable {
        var id: Int
        var name: String
        var role: String

        enum CodingKeys: String, CodingKey {
            case id, name
            case role = "role_id"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = container.decodeIntLeniently(forKey: .id) ?? 0
            name = container.decodeStringLeniently(forKey: .name)?.trimmingCharacters(in: .whitespaces) ?? ""
            role = container.decodeStringLeniently(forKey: .role)?.trimmingCharacters(in: .whitespaces) ?? ""
        }
    }

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? true
        message = container.decodeStringLeniently(forKey: .message) ?? ""
        let rows = (try? container.decodeIfPresent([Row].self, forKey: .data)) ?? []
        people = rows
            .filter { $0.id > 0 && !$0.name.isEmpty }
            .map { PersonOption(id: $0.id, name: $0.name, role: $0.role) }
    }
}

extension Notification.Name {
    /// Android `CashCollectionBus.Change.BillRegister`: a register was created, cleared or
    /// reassigned, so the list refreshes in place.
    static let billRegisterChanged = Notification.Name("billRegisterChanged")
}
