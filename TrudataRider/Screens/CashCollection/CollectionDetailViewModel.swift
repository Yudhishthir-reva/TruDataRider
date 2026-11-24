//
//  CollectionDetailViewModel.swift
//  TrudataRider
//
//  Android `CollectionDetailViewModel`: one collection, with review (approve / reject) for a
//  reviewer and editing the counts for admin.
//

import Combine
import Foundation

enum ReviewAction {
    case approve, reject

    var isApprove: Bool { self == .approve }
}

/// Android `EditState`.
struct CollectionEditState {
    var declaredText: String
    var counts: DenominationCounts
    var isSaving = false

    var declared: Int { Int(declaredText) ?? 0 }
    var isBalanced: Bool { declared > 0 && counts.cashTotal == declared }
}

final class CollectionDetailViewModel: ObservableObject {

    let access = CashAccess.current

    @Published private(set) var collection: CashCollection?
    @Published private(set) var isLoading = true
    @Published private(set) var loadError: String?
    @Published private(set) var remark = ""
    @Published private(set) var remarkError: String?
    @Published var pendingAction: ReviewAction?
    @Published private(set) var isReviewing = false
    @Published private(set) var edit: CollectionEditState?
    @Published var actionError: String?
    @Published var toast: String?

    private let collectionId: Int
    private let service = CashCollectionServiceManager()
    private var loadJob: AnyCancellable?
    private var actionJob: AnyCancellable?

    init(collectionId: Int) {
        self.collectionId = collectionId
        load()
    }

    private var status: String? { collection?.status.lowercased() }

    var canReview: Bool { access.canReviewAll && status == CashStatus.pending }

    /// The server refuses edits once approved.
    var canEdit: Bool { access.canEditCollection && collection != nil && status != CashStatus.approved }

    var title: String {
        if edit != nil { return "Edit Collection" }
        return canReview ? "Review Collection" : "Collection Detail"
    }

    // MARK: - Load

    func load() {
        isLoading = true
        loadError = nil
        loadJob = service.collectionDetail(id: collectionId)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self, case .failure(let error) = completion else { return }
                self.isLoading = false
                self.loadError = CashError.message(error)
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if let collection = response.data {
                    self.collection = collection
                } else {
                    self.loadError = CashError.server(response.message) ?? CashError.empty
                }
            }
    }

    // MARK: - Review

    func remarkChanged(_ text: String) {
        remark = String(text.prefix(250))
        remarkError = nil
    }

    func requestReview(_ action: ReviewAction) {
        // A rejection has to say why, or the person who submitted has nothing to fix.
        if action == .reject && remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            remarkError = "Add a remark saying why it's rejected"
            actionError = "Add a remark saying why it's rejected. The person who submitted it will see it."
        } else {
            pendingAction = action
        }
    }

    func confirmReview() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        isReviewing = true
        actionError = nil

        actionJob = service.reviewCollection(id: collectionId, approve: action.isApprove, remark: remark)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self, case .failure(let error) = completion else { return }
                let message = CashError.message(error)
                self.isReviewing = false
                self.actionError = message
                // "Only pending collections can be reviewed" means someone else got there first.
                // Android reloads on that 422; the shared client drops the status code, so any
                // server-worded refusal reloads here.
                if message != CashError.offline && message != CashError.generic { self.load() }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isReviewing = false
                guard let reviewed = response.data else {
                    self.actionError = CashError.server(response.message) ?? CashError.empty
                    return
                }
                CashChange.notify(.collection)
                self.remark = ""
                // The review reply has no denominations; keep the ones already shown.
                if var current = self.collection {
                    current.status = reviewed.status.isEmpty
                        ? (action.isApprove ? CashStatus.approved : CashStatus.rejected)
                        : reviewed.status
                    current.remark = reviewed.remark
                    current.reviewedBy = reviewed.reviewedBy ?? current.reviewedBy
                    self.collection = current
                }
                self.toast = CashError.server(response.message)
                    ?? (action.isApprove ? "Collection approved" : "Collection rejected")
            }
    }

    // MARK: - Edit

    func startEdit() {
        guard let collection else { return }
        edit = CollectionEditState(
            declaredText: String(Int(collection.totalAmount)),
            counts: collection.counts.filter { $0.value > 0 }
        )
    }

    func cancelEdit() {
        edit = nil
    }

    func editDeclaredChanged(_ text: String) {
        edit?.declaredText = cashDigitsOnly(text)
    }

    func editCountChanged(_ denomination: Denomination, to count: Int) {
        if count <= 0 {
            edit?.counts.removeValue(forKey: denomination)
        } else {
            edit?.counts[denomination] = count
        }
    }

    func saveEdit() {
        guard let current = edit, !current.isSaving else { return }
        guard current.isBalanced else {
            actionError = current.declared <= 0
                ? "Enter the total cash amount"
                : "The counts add up to \(CashFormat.rupees(current.counts.cashTotal)), not \(CashFormat.rupees(current.declared))."
            return
        }
        edit?.isSaving = true

        actionJob = service.editCollection(id: collectionId, declared: current.declared, counts: current.counts)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self, case .failure(let error) = completion else { return }
                self.edit?.isSaving = false
                self.actionError = CashError.message(error)
            } receiveValue: { [weak self] response in
                guard let self else { return }
                guard response.data != nil else {
                    self.edit?.isSaving = false
                    self.actionError = CashError.server(response.message) ?? CashError.empty
                    return
                }
                CashChange.notify(.collection)
                self.edit = nil
                self.toast = CashError.server(response.message) ?? "Collection updated"
                self.load()
            }
    }
}
