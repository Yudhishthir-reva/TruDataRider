//
//  CollectionDetailViewModel.swift
//  TrudataRider
//

import Foundation
import Combine

enum ReviewAction {
    case approve, reject

    var isApprove: Bool { self == .approve }
}

final class CollectionDetailViewModel: ObservableObject {

    @Published var collection: CashCollection?
    @Published var isLoading = false
    @Published var loadError: String?

    // Review
    @Published var remark = ""
    @Published var remarkError: String?
    @Published var isReviewing = false
    @Published var pendingAction: ReviewAction?
    @Published var actionError: String?
    @Published var successMessage: String?

    // Edit
    @Published var isEditing = false
    @Published var editDeclaredText = ""
    @Published var editCounts: DenominationCounts = [:]
    @Published var isSaving = false

    let access = CashAccess.current

    private let collectionId: Int
    private let service = CashCollectionServiceManager()
    private var cancellables = Set<AnyCancellable>()

    init(collectionId: Int) {
        self.collectionId = collectionId
    }

    /// Only a pending collection can be reviewed, and only by a role that may review.
    var canReview: Bool {
        access.canReviewAll && (collection?.isPending ?? false)
    }

    /// Admin can edit a submission that is not approved yet.
    var canEdit: Bool {
        access.canEditCollection && (collection?.isApproved == false)
    }

    var editDeclared: Int {
        Int(editDeclaredText) ?? 0
    }

    var editCounted: Int {
        editCounts.cashTotal
    }

    var isEditBalanced: Bool {
        editDeclared > 0 && editCounted == editDeclared
    }

    // MARK: - Load

    func load() {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil

        service.collectionDetail(id: collectionId)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.loadError = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if let collection = response.data {
                    self.collection = collection
                } else {
                    self.loadError = response.message.isEmptyString
                        ? "This collection could not be loaded." : response.message
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Review

    func requestReview(_ action: ReviewAction) {
        // A rejection without a reason is no use to the person who submitted it.
        if action == .reject, remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            remarkError = "Add a remark so they know why it was rejected."
            return
        }
        remarkError = nil
        pendingAction = action
    }

    func confirmReview() {
        guard let action = pendingAction, !isReviewing else { return }
        pendingAction = nil
        isReviewing = true

        service.reviewCollection(id: collectionId, approve: action.isApprove, remark: remark)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isReviewing = false
                if case .failure(let error) = completion {
                    self.actionError = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isReviewing = false
                if let collection = response.data {
                    self.collection = collection
                    self.remark = ""
                    self.successMessage = action.isApprove ? "Collection approved." : "Collection rejected."
                } else {
                    self.actionError = response.message.isEmptyString
                        ? "The review could not be saved." : response.message
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Edit

    func startEditing() {
        guard let collection else { return }
        editDeclaredText = String(Int(collection.totalAmount.rounded()))
        editCounts = collection.counts
        isEditing = true
    }

    func cancelEditing() {
        isEditing = false
        editCounts = [:]
        editDeclaredText = ""
    }

    func editDeclaredChanged(_ text: String) {
        editDeclaredText = CashCollectionViewModel.digitsOnly(text)
    }

    func editCountChanged(_ denomination: Denomination, to count: Int) {
        editCounts[denomination] = max(0, count)
    }

    func saveEdit() {
        guard !isSaving else { return }
        guard isEditBalanced else {
            actionError = "The counts add up to \(CashFormat.rupees(editCounted)), not \(CashFormat.rupees(editDeclared)). Fix the counts or the total."
            return
        }

        isSaving = true

        service.editCollection(id: collectionId, declared: editDeclared, counts: editCounts)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isSaving = false
                if case .failure(let error) = completion {
                    self.actionError = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isSaving = false
                if let collection = response.data {
                    self.collection = collection
                    self.isEditing = false
                    self.successMessage = "Changes saved. The collection is still pending."
                } else {
                    self.actionError = response.message.isEmptyString
                        ? "The changes could not be saved." : response.message
                }
            }
            .store(in: &cancellables)
    }
}
