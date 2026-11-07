// Android `BillCreateConfirmTest.kt`, ported: what the create screen asks about before it throws
// picks away. Run from the repo root:
// swiftc TrudataRider/Core/Network/LenientDecoding.swift TrudataRider/Screens/CashCollection/CashCollectionModels.swift Tests/BillCreateConfirmChecks.swift -o /tmp/bill-create-checks && /tmp/bill-create-checks
import Foundation

@main
struct BillCreateConfirmChecks {
    /// `BeatOrder` only decodes, so the bills are built from `beat-orders` rows.
    static func order(_ id: Int, beat: Int, amount: Double = 100) -> BeatOrder {
        let json = "{\"order_id\":\(id),\"order_no\":\"#\(id)\",\"beat_id\":\(beat),\"pending_amount\":\(amount)}"
        return try! JSONDecoder().decode(BeatOrder.self, from: Data(json.utf8))
    }

    static func main() {
        let state = BillCreatePicks(
            selectedBeats: [1, 2],
            orders: [order(10, beat: 1), order(11, beat: 1, amount: 250), order(20, beat: 2)],
            selectedOrders: [10, 11]
        )

        // droppingABeatWithPicksIsCaught
        precondition(state.droppedBy([2]).map(\.orderId) == [10, 11])
        precondition(state.droppedBy([2]).reduce(0) { $0 + $1.pendingAmount } == 350.0)
        precondition(state.droppedBy([]).count == 2)

        // addingOrDroppingAnUnpickedBeatIsNot
        precondition(state.droppedBy([1]).isEmpty)
        precondition(state.droppedBy([1, 2, 3]).isEmpty)

        // leavingAsksOnlyWhileThereAreUnsavedPicks
        precondition(state.hasPicks)
        var none = state
        none.selectedOrders = []
        precondition(!none.hasPicks)
        var created = state
        created.createdId = 7
        precondition(!created.hasPicks, "created registers are saved")

        print("BillCreateConfirmChecks: all passed")
    }
}
