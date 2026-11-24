//
//  CashCollectionServiceManager.swift
//  TrudataRider
//
//  `V2/cash-collection/…`, `V2/payment-advance/…` and `bill-register/…` — every call a POST, JSON
//  in (multipart for the two that take an attachment), JSON out. Mirrors the Android module's
//  `CashCollectionApi`.
//

import Foundation
import Combine

final class CashCollectionServiceManager {

    static let pageSize = 15

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    // MARK: - Cash collection

    func submitCollection(
        declared: Int,
        counts: DenominationCounts,
        remark: String = ""
    ) -> AnyPublisher<DataResponse<CashCollection>, Error> {
        var params = denominationBody(declared: declared, counts: counts)
        let trimmed = remark.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            params["remark"] = trimmed
        }
        return cashRequest(APIRouter.cashCollectionSubmit, params: params)
    }

    func editCollection(
        id: Int,
        declared: Int,
        counts: DenominationCounts
    ) -> AnyPublisher<DataResponse<CashCollection>, Error> {
        var params = denominationBody(declared: declared, counts: counts)
        params["id"] = id
        return cashRequest(APIRouter.cashCollectionEdit, params: params)
    }

    /// The caller's own collections.
    func myCollections(
        range: CashDateRange,
        page: Int,
        perPage: Int = pageSize
    ) -> AnyPublisher<PagedResponse<CashCollection>, Error> {
        var params: [String: Any] = ["per_page": perPage, "page": page]
        params.putRange(range)
        return cashRequest(APIRouter.cashCollectionMyList, params: params)
    }

    /// Everyone's collections. A nil `status` asks for every status; an empty `staffIds` for every person.
    func allCollections(
        range: CashDateRange,
        staffIds: Set<Int>,
        status: String?,
        page: Int,
        perPage: Int = pageSize
    ) -> AnyPublisher<PagedResponse<CashCollection>, Error> {
        var params: [String: Any] = ["per_page": perPage, "page": page]
        params.putRange(range)
        params.putStaff(staffIds)
        if let status {
            params["status"] = status
        }
        return cashRequest(APIRouter.cashCollectionAllList, params: params)
    }

    func collectionDetail(id: Int) -> AnyPublisher<DataResponse<CashCollection>, Error> {
        cashRequest(APIRouter.cashCollectionDetail, params: ["id": id])
    }

    func reviewCollection(
        id: Int,
        approve: Bool,
        remark: String
    ) -> AnyPublisher<DataResponse<CashCollection>, Error> {
        var params: [String: Any] = [
            "id": id,
            "action": approve ? CashStatus.approved : CashStatus.rejected
        ]
        let trimmed = remark.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            params["remark"] = trimmed
        }
        return cashRequest(APIRouter.cashCollectionReview, params: params)
    }

    // MARK: - Amount taken

    func addAmountTaken(
        personId: Int,
        amount: Int,
        reason: String,
        remark: String,
        date: String,
        collectionId: Int?
    ) -> AnyPublisher<DataResponse<AmountTaken>, Error> {
        var params: [String: Any] = [
            "person_id": personId,
            "amount": amount,
            "date": date
        ]
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedReason.isEmpty {
            params["reason"] = trimmedReason
        }
        let trimmedRemark = remark.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedRemark.isEmpty {
            params["remark"] = trimmedRemark
        }
        if let collectionId {
            params["collection_id"] = collectionId
        }
        return cashRequest(APIRouter.amountTakenAdd, params: params)
    }

    func amountTakenList(
        range: CashDateRange,
        staffIds: Set<Int>,
        page: Int,
        perPage: Int = pageSize
    ) -> AnyPublisher<PagedResponse<AmountTaken>, Error> {
        var params: [String: Any] = ["per_page": perPage, "page": page]
        params.putRange(range)
        params.putStaff(staffIds)
        return cashRequest(APIRouter.amountTakenList, params: params)
    }

    func updateAmountTakenStatus(id: Int, approve: Bool) -> AnyPublisher<DataResponse<AmountTaken>, Error> {
        let params: [String: Any] = [
            "id": id,
            "status": approve ? CashStatus.approved : CashStatus.rejected
        ]
        return cashRequest(APIRouter.amountTakenUpdateStatus, params: params)
    }

    // MARK: - Summary and ledger

    /// Notes and coins counted across collections, in total and per person.
    ///
    /// Nil dates are left out, which the server reads as all time. An empty `staffIds` is left out
    /// too, which means every staff member (the summary is always the caller's own for a rider or
    /// sale person).
    func denominationSummary(
        range: CashDateRange,
        staffIds: Set<Int>
    ) -> AnyPublisher<DenominationSummaryResponse, Error> {
        var params: [String: Any] = [:]
        params.putRange(range)
        params.putStaff(staffIds)
        // An all-time, all-staff summary sends an empty body; the shared client then skips the
        // Content-Type header, which this endpoint is fine with.
        return cashRequest(APIRouter.denominationSummary, params: params)
    }

    /// Collections in and amounts taken out, newest first, with filter-wide totals and per-day totals.
    /// A sale person or rider gets only their own; a reviewer gets everyone's, narrowed by `staffIds`.
    func ledger(
        range: CashDateRange,
        staffIds: Set<Int>,
        page: Int,
        perPage: Int = pageSize
    ) -> AnyPublisher<LedgerResponse, Error> {
        var params: [String: Any] = ["per_page": perPage, "page": page]
        params.putRange(range)
        params.putStaff(staffIds)
        return cashRequest(APIRouter.cashLedger, params: params)
    }

    // MARK: - Payment advance

    /// A manager hands `amount` to a staff member; the whole of it starts out outstanding.
    func giveAdvance(
        personId: Int,
        amount: Int,
        date: String,
        purpose: String,
        attachment: MultipartFileUpload?
    ) -> AnyPublisher<DataResponse<Advance>, Error> {
        var params: [String: Any] = [
            "person_id": personId,
            "amount": amount,
            "date": date
        ]
        let trimmed = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            params["purpose"] = trimmed
        }
        return cashUpload(APIRouter.advanceGive, params: params, attachment: attachment)
    }

    /// Money coming back against an advance; the server moves it to partial or completed.
    func receiveAdvance(
        advanceId: Int,
        amount: Int,
        date: String,
        remark: String,
        attachment: MultipartFileUpload?
    ) -> AnyPublisher<DataResponse<Advance>, Error> {
        var params: [String: Any] = [
            "advance_id": advanceId,
            "receive_amount": amount,
            "date": date
        ]
        let trimmed = remark.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            params["remark"] = trimmed
        }
        return cashUpload(APIRouter.advanceReceive, params: params, attachment: attachment)
    }

    /// Everyone's advances and returns (manager roles).
    func advanceAllList(
        query: AdvanceQuery,
        page: Int,
        perPage: Int = pageSize
    ) -> AnyPublisher<AdvanceListResponse, Error> {
        var params: [String: Any] = [
            "type": query.type,
            "per_page": perPage,
            "page": page
        ]
        params.putRange(query.range)
        params.putStaff(query.staffIds)
        if let status = query.status {
            params["status"] = status
        }
        if let roleId = query.roleId {
            params["role_id"] = roleId
        }
        let search = query.search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !search.isEmpty {
            params["search"] = search
        }
        return cashRequest(APIRouter.advanceAllList, params: params)
    }

    /// The caller's own advances and returns (sale person, rider). Status, role and search don't apply.
    func advanceMyList(
        query: AdvanceQuery,
        page: Int,
        perPage: Int = pageSize
    ) -> AnyPublisher<AdvanceListResponse, Error> {
        var params: [String: Any] = [
            "type": query.type,
            "per_page": perPage,
            "page": page
        ]
        params.putRange(query.range)
        return cashRequest(APIRouter.advanceMyList, params: params)
    }

    /// One advance with every payment returned against it.
    func advanceDetail(id: Int) -> AnyPublisher<DataResponse<Advance>, Error> {
        cashRequest(APIRouter.advanceDetail, params: ["id": id])
    }

    func updateAdvanceStatus(id: Int, status: String) -> AnyPublisher<DataResponse<Advance>, Error> {
        cashRequest(APIRouter.advanceUpdateStatus, params: ["id": id, "status": status])
    }

    // MARK: - Bill register

    /// One page of beats. `beat-list` pages by 50, so callers walk the pages until `lastPage`.
    func beats(page: Int) -> AnyPublisher<BeatListResponse, Error> {
        networkService.request(APIRouter.beatList, params: ["page": page], headers: authHeaders)
    }

    /// Delivered orders with payment pending in `beatIds`, each marked if already in a register.
    func beatOrders(beatIds: Set<Int>) -> AnyPublisher<DataResponse<BeatOrdersPayload>, Error> {
        networkService.request(
            APIRouter.beatOrders,
            params: ["beat_ids": beatIds.sorted()],
            headers: authHeaders
        )
    }

    func createBillRegister(
        beatIds: Set<Int>,
        orderIds: Set<Int>,
        assignedTo: Int
    ) -> AnyPublisher<BillRegisterCreateResponse, Error> {
        let params: [String: Any] = [
            "beat_ids": beatIds.sorted(),
            "order_ids": orderIds.sorted(),
            "assigned_to": assignedTo
        ]
        return networkService.request(APIRouter.billRegisterCreate, params: params, headers: authHeaders)
    }

    /// A manager gets every register (narrowed by `status` and `assignedTo`); anyone else gets the
    /// registers assigned to them.
    func billRegisters(
        status: String?,
        assignedTo: Int?,
        page: Int,
        orderId: String? = nil
    ) -> AnyPublisher<BillRegisterListResponse, Error> {
        var params: [String: Any] = ["page": page]
        if let status {
            params["status"] = status
        }
        if let assignedTo {
            params["assigned_to"] = assignedTo
        }
        if let orderId, !orderId.trimmingCharacters(in: .whitespaces).isEmpty {
            let trimmed = orderId.trimmingCharacters(in: .whitespaces)
            params["order_id"] = Int(trimmed) ?? trimmed
        }
        return networkService.request(APIRouter.billRegisterList, params: params, headers: authHeaders)
    }

    func billRegisterDetail(id: Int) -> AnyPublisher<DataResponse<BillRegister>, Error> {
        networkService.request(
            APIRouter.billRegisterDetail,
            params: ["bill_register_id": id],
            headers: authHeaders
        )
    }

    func reassignBillRegister(id: Int, assignedTo: Int) -> AnyPublisher<StatusMessageResponse, Error> {
        networkService.request(
            APIRouter.billRegisterAssign,
            params: ["bill_register_id": id, "assigned_to": assignedTo],
            headers: authHeaders
        )
    }

    /// Who a register can be assigned to. Android's rider host has no staff list of its own (only the
    /// manager screens ask, and a rider never sees them); the sales app reads `staff-list`, so this
    /// does too, and the person picker works if a manager role ever signs in here.
    func billPeople() -> AnyPublisher<StaffPeopleResponse, Error> {
        networkService.request(APIRouter.staffList, params: [:], headers: authHeaders)
    }

    /// Clears `orderIds`, or every pending order when it is nil; the register clears itself once all are.
    func clearBillRegister(id: Int, orderIds: Set<Int>?) -> AnyPublisher<StatusMessageResponse, Error> {
        var params: [String: Any] = ["bill_register_id": id]
        if let orderIds {
            params["order_ids"] = orderIds.sorted()
        }
        return networkService.request(APIRouter.billRegisterClear, params: params, headers: authHeaders)
    }

    // MARK: - Request building

    /// Every cash and advance call goes through here: `{status:false}` becomes a failure, and the
    /// failure carries Android's wording (`CashCollectionApi.send`).
    private func cashRequest<T: Decodable & CashServerReply>(
        _ endpoint: RouterManagable,
        params: [String: Any]
    ) -> AnyPublisher<T, Error> {
        let raw: AnyPublisher<T, Error> = networkService.request(endpoint, params: params, headers: authHeaders)
        return raw.cashChecked()
    }

    /// multipart/form-data, for the calls that can carry an attachment (sent as `attachment`).
    private func cashUpload<T: Decodable & CashServerReply>(
        _ endpoint: RouterManagable,
        params: [String: Any],
        attachment: MultipartFileUpload?
    ) -> AnyPublisher<T, Error> {
        let raw: AnyPublisher<T, Error> = networkService.uploadMultipart(
            endpoint,
            params: params,
            file: attachment,
            files: attachment.map { [$0] } ?? [],
            headers: authHeaders
        )
        return raw.cashChecked()
    }

    private func denominationBody(declared: Int, counts: DenominationCounts) -> [String: Any] {
        var params: [String: Any] = ["total_cash_amount": declared]
        // Every field is required by the server, zeros included.
        for denomination in Denomination.allCases {
            params[denomination.apiKey] = counts[denomination] ?? 0
        }
        return params
    }
}

private extension Dictionary where Key == String, Value == Any {

    /// Nil ends are left out; both nil means all time.
    mutating func putRange(_ range: CashDateRange) {
        if let from = range.from {
            self["date_from"] = from
        }
        if let to = range.to {
            self["date_to"] = to
        }
    }

    /// Left out when empty, which the server reads as every person.
    mutating func putStaff(_ staffIds: Set<Int>) {
        guard !staffIds.isEmpty else { return }
        self["staff_ids"] = staffIds.sorted()
    }
}
