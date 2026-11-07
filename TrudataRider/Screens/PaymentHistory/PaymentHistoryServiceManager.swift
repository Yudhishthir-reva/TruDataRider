//
//  PaymentHistoryServiceManager.swift
//  TrudataRider
//

import Foundation
import Combine

final class PaymentHistoryServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    /// Blank filters are left out of the request, which the server reads as "any".
    func fetchPaymentHistory(
        page: Int,
        startDate: String = "",
        endDate: String = "",
        paymentMode: String = "",
        paymentStatus: String = "",
        sellerId: String = ""
    ) -> AnyPublisher<PaymentHistoryResponse, Error> {
        var params: [String: Any] = ["page": page]
        if !startDate.isEmpty { params["start_date"] = startDate }
        if !endDate.isEmpty { params["end_date"] = endDate }
        if !paymentMode.isEmpty { params["payment_type"] = paymentMode }
        if !paymentStatus.isEmpty { params["payment_status"] = paymentStatus }
        if !sellerId.isEmpty { params["seller_id"] = sellerId }

        return networkService.request(
            APIRouter.riderTransactionHistory,
            params: params,
            headers: authHeaders
        )
    }
}
