// Android `BillRegisterRemoveCancelTest.kt`, ported: shapes from staging's `bill-register/detail`
// after remove-order and cancel (people and shops made up). Run from the repo root:
// swiftc TrudataRider/Core/Network/LenientDecoding.swift TrudataRider/Screens/CashCollection/CashCollectionModels.swift Tests/BillRegisterRemoveCancelChecks.swift -o /tmp/bill-remove-checks && /tmp/bill-remove-checks
import Foundation

@main
struct BillRegisterRemoveCancelChecks {
    static func order(_ id: Int, _ status: String, removedBy: String = "", removedAt: String? = nil, reason: String? = nil) -> String {
        """
        {"register_order_id":\(50 + id),"order_id":\(id),"order_no":"#2026-27\\/\(id)","seller_name":"Seller \(id)",
         "seller_shop_name":"Shop \(id)","seller_mobile":9000000\(id),"beat_name":"Test Beat","staff_name":"Test SP",
         "order_amount":"100.00","pending_amount":"100.00","current_pending":100,"payment_status":"\(status)",
         "cleared_at":null,"removed_by":"\(removedBy)","removed_at":\(removedAt.map { "\"\($0)\"" } ?? "null"),
         "remove_reason":\(reason.map { "\"\($0)\"" } ?? "null"),"delivery_date":"05-Oct-2026"}
        """
    }

    static func register(_ status: String, _ extra: String, _ orders: String) -> BillRegister {
        let json = """
        {"id":5,"beat_ids":[19],"beat_names":["Test Beat"],"assigned_to_id":1,"assigned_to":"admin",
         "assigned_by":"admin","status":"\(status)","cleared_at":null,"created_at":"26-Oct-2026 12:47 PM",
         \(extra),"orders":[\(orders)]}
        """
        return try! JSONDecoder().decode(BillRegister.self, from: Data(json.utf8))
    }

    static func pendingRegisterWithARemovedBill() {
        let r = register(
            "pending",
            #""cancelled_by":"","cancelled_at":null,"cancel_reason":null,"total_orders":3,"pending_orders":2,"cleared_orders":0,"cancelled_orders":0,"removed_orders":1,"total_amount":200,"pending_amount":200"#,
            [
                order(1, "removed", removedBy: "admin", removedAt: "2026-10-26 12:47:57", reason: "App probe: remove one bill"),
                order(2, "pending"),
                order(3, "pending")
            ].joined(separator: ",")
        )
        precondition(r.isPending)
        precondition(r.cancelledBy == nil, "a blank cancelled_by is no one")
        precondition(r.activeOrders == 2)

        let removed = r.orders[0]
        precondition(removed.isRemoved)
        precondition(!removed.isPending)
        precondition(removed.removedBy == "admin")
        precondition(removed.removeReason == "App probe: remove one bill")
        precondition(billStamp(removed.removedAt) == "26-Oct-2026 12:47 PM")
        precondition(removed.sellerMobile == "90000001")

        let pending = r.orders.dropFirst()
        precondition(pending.allSatisfy { $0.isPending && !$0.isRemoved })
        precondition(pending.allSatisfy { $0.removedBy == nil }, "a blank removed_by is no one")
    }

    static func cancelledRegisterFreesItsPendingBills() {
        let r = register(
            "cancelled",
            #""cancelled_by":"admin","cancelled_at":"2026-10-26 12:47:58","cancel_reason":"App probe: cancel","total_orders":3,"pending_orders":0,"cleared_orders":0,"cancelled_orders":2,"removed_orders":1,"total_amount":200,"pending_amount":0"#,
            [
                order(1, "removed", removedBy: "admin", removedAt: "2026-10-26 12:47:57"),
                order(2, "cancelled"),
                order(3, "cancelled")
            ].joined(separator: ",")
        )
        precondition(r.isCancelled)
        precondition(!r.isPending)
        precondition(!r.isCleared)
        precondition(r.cancelledBy == "admin")
        precondition(r.cancelReason == "App probe: cancel")
        precondition(billStamp(r.cancelledAt) == "26-Oct-2026 12:47 PM")
        precondition(r.cancelledOrders == 2)
        precondition(r.activeOrders == 2)
        // Freed bills are neither pending nor removed, so nothing can be ticked.
        precondition(r.orders.dropFirst().allSatisfy { $0.isCancelled && !$0.isPending && !$0.isRemoved })
        precondition(!r.orders.contains { $0.isPending })
    }

    static func removingTheOnlyBillCancelsTheRegister() {
        let r = register(
            "cancelled",
            #""cancelled_by":"admin","cancelled_at":"2026-10-26 12:48:00","cancel_reason":"All bills removed from register","total_orders":1,"pending_orders":0,"cleared_orders":0,"cancelled_orders":0,"removed_orders":1,"total_amount":0,"pending_amount":0"#,
            order(1, "removed", removedBy: "admin", removedAt: "2026-10-26 12:48:00")
        )
        precondition(r.isCancelled)
        precondition(r.activeOrders == 0)
        precondition(r.totalAmount == 0)
        precondition(r.orders.count == 1 && r.orders[0].isRemoved)
    }

    static func stampsTheServerAlreadyFormattedAreShownAsSent() {
        precondition(billStamp("26-Oct-2026 12:47 PM") == "26-Oct-2026 12:47 PM")
        precondition(billStamp("") == nil)
        precondition(billStamp(nil) == nil)
    }

    static func main() {
        pendingRegisterWithARemovedBill()
        cancelledRegisterFreesItsPendingBills()
        removingTheOnlyBillCancelsTheRegister()
        stampsTheServerAlreadyFormattedAreShownAsSent()
        print("BillRegisterRemoveCancelChecks: all passed")
    }
}
