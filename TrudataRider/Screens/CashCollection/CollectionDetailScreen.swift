//
//  CollectionDetailScreen.swift
//  TrudataRider
//
//  Android `CollectionDetailScreen`: the hero, the denomination breakup, the remarks, and — for a
//  reviewer — approve / reject, or (admin) editing the counts.
//

import SwiftUI

struct CollectionDetailScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CollectionDetailViewModel

    var onHome: () -> Void

    init(collectionId: Int, onHome: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: CollectionDetailViewModel(collectionId: collectionId))
        self.onHome = onHome
    }

    var body: some View {
        VStack(spacing: 0) {
            SellersAppBar(
                title: viewModel.title,
                onBack: { if viewModel.edit != nil { viewModel.cancelEdit() } else { dismiss() } },
                onHome: onHome,
                onRefresh: viewModel.edit == nil ? { viewModel.load() } : nil
            )

            ScrollView {
                VStack(spacing: 10) {
                    content
                }
                .padding(12)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
        }
        .background(CcColors.page.ignoresSafeArea())
        .navigationBarHidden(true)
        .cashToast($viewModel.toast)
        .overlay { dialogs }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.collection == nil {
            CcLoadingBlock()
        } else if let error = viewModel.loadError, viewModel.collection == nil {
            CashErrorState(message: error) { viewModel.load() }
        } else if let collection = viewModel.collection {
            if let edit = viewModel.edit {
                EditNotice()
                DenominationFormView(
                    declaredText: edit.declaredText,
                    counts: edit.counts,
                    onDeclaredChange: { viewModel.editDeclaredChanged($0) },
                    onCountChange: { viewModel.editCountChanged($0, to: $1) }
                )
            } else {
                DetailHero(collection: collection)
                Breakup(collection: collection)
                if let remark = collection.submitRemark, !remark.isEmptyString {
                    CashSection(title: "Submit remark", systemImage: "text.bubble") {
                        Text(remark)
                            .font(.system(size: 13))
                            .foregroundStyle(CcColors.textMuted)
                    }
                }
                if !(collection.remark ?? "").isEmptyString || collection.reviewedBy != nil {
                    ReviewInfo(collection: collection)
                }
                if viewModel.canReview {
                    CashSection(title: "Remark", systemImage: "text.bubble", subtitle: "Required when rejecting") {
                        CashTextField(
                            text: .constant(viewModel.remark),
                            placeholder: "e.g. Verified with the cash in hand",
                            error: viewModel.remarkError,
                            minLines: 2,
                            onChange: { viewModel.remarkChanged($0) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Action bar

    @ViewBuilder
    private var actionBar: some View {
        if let edit = viewModel.edit {
            CashActionTray {
                CashCountSummary(declared: edit.declared, counts: edit.counts)
            } buttons: {
                CashSecondaryButton(title: "Cancel", systemImage: "xmark", color: CcColors.textMuted) {
                    viewModel.cancelEdit()
                }
                .containerRelativeFrame(.horizontal) { width, _ in (width - 42) * 0.34 }
                CashPrimaryButton(title: "Save changes", systemImage: "checkmark", isLoading: edit.isSaving) {
                    viewModel.saveEdit()
                }
            }
        } else if viewModel.canReview {
            CashActionTray {
                CashBarSummary(
                    label: "From \(viewModel.collection?.submittedBy?.name ?? "—")",
                    value: CashFormat.rupees(viewModel.collection?.totalAmount ?? 0)
                )
            } buttons: {
                if viewModel.canEdit {
                    CashIconActionButton(systemImage: "pencil", label: "Edit counts", color: CcColors.text) {
                        viewModel.startEdit()
                    }
                }
                CashSecondaryButton(title: "Reject", systemImage: "xmark", color: CcColors.err, isEnabled: !viewModel.isReviewing) {
                    viewModel.requestReview(.reject)
                }
                CashPrimaryButton(title: "Approve", systemImage: "checkmark", isLoading: viewModel.isReviewing) {
                    viewModel.requestReview(.approve)
                }
            }
        } else if viewModel.canEdit {
            CashActionTray {
                CashPrimaryButton(title: "Edit collection", systemImage: "pencil") {
                    viewModel.startEdit()
                }
            }
        }
    }

    // MARK: - Dialogs

    @ViewBuilder
    private var dialogs: some View {
        if let error = viewModel.actionError {
            CashErrorDialog(message: error) { viewModel.actionError = nil }
        } else if let action = viewModel.pendingAction {
            let amount = CashFormat.rupees(viewModel.collection?.totalAmount ?? 0)
            let who = viewModel.collection?.submittedBy?.name ?? "this person"
            CashConfirmDialog(
                title: action.isApprove ? "Approve \(amount)?" : "Reject \(amount)?",
                message: action.isApprove
                    ? "This confirms you received \(amount) from \(who). Approved collections can't be edited."
                    : "\(who) will see it as rejected with your remark.",
                confirmTitle: action.isApprove ? "Approve" : "Reject",
                systemImage: action.isApprove ? "checkmark" : "xmark",
                confirmColor: action.isApprove ? CcColors.primary : CcColors.err,
                onConfirm: { viewModel.confirmReview() },
                onDismiss: { viewModel.pendingAction = nil }
            )
        }
    }
}

// MARK: - Sections

private struct DetailHero: View {
    let collection: CashCollection

    var body: some View {
        CashHero {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    CashHeroLabel(text: "Collection #\(collection.id)")
                    Text(CashFormat.rupees(collection.totalAmount))
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 8)
                CcStatusPill(status: collection.status)
            }
            if let submitter = collection.submittedBy {
                Text("Submitted by \(submitter.name)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 4)
            }
            if let submittedAt = collection.submittedAt {
                Text(submittedAt)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}

private struct Breakup: View {
    let collection: CashCollection

    var body: some View {
        let lines = collection.denominations.compactMap { line in line.denomination.map { ($0, line) } }
        CashSection(title: "Denomination details", systemImage: "banknote") {
            if lines.isEmpty {
                Text("No denomination breakup was sent for this collection.")
                    .font(.system(size: 13))
                    .foregroundStyle(CcColors.textMuted)
            } else {
                HStack(spacing: 0) {
                    Text("Currency").frame(width: 70, alignment: .leading)
                    Text("Quantity").frame(maxWidth: .infinity, alignment: .center)
                    Text("Total").frame(width: 96, alignment: .trailing)
                }
                .font(.system(size: 11))
                .foregroundStyle(CcColors.textFaint)

                // Zero rows are noise on a read-only breakup; the ones that were counted are what matters.
                let counted = lines.filter { $0.1.qty > 0 }
                ForEach(counted.indices, id: \.self) { index in
                    let (denomination, line) = counted[index]
                    HStack(spacing: 0) {
                        DenominationBadge(denomination: denomination)
                            .frame(width: 70, alignment: .leading)
                        VStack(spacing: 1) {
                            Text("\(line.qty)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(CcColors.text)
                            if denomination.kind == .note && line.qty >= 100 {
                                Text(cashBundleText(line.qty))
                                    .font(.system(size: 10))
                                    .foregroundStyle(CcColors.textFaint)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        Text(CashFormat.rupees(line.total))
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(CcColors.text)
                            .frame(width: 96, alignment: .trailing)
                    }
                }

                CcColors.divider.frame(height: 1)

                HStack {
                    Text("Total")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(CcColors.text)
                    Spacer()
                    Text(CashFormat.rupees(lines.reduce(0) { $0 + $1.1.total }))
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(CcColors.primary)
                }
            }
        }
    }
}

private struct ReviewInfo: View {
    let collection: CashCollection

    var body: some View {
        CashSection(title: "Review", systemImage: "info.circle.fill", accent: CcColors.info) {
            if let reviewer = collection.reviewedBy {
                Text("Reviewed by \(reviewer.name)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CcColors.text)
            }
            if let remark = collection.remark, !remark.isEmptyString {
                Text("“\(remark)”")
                    .font(.system(size: 13))
                    .foregroundStyle(CcColors.textMuted)
            }
        }
    }
}

private struct EditNotice: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil")
                .font(.system(size: 18, weight: .semibold))
            Text("Change the counts or the total. They must still add up. The collection stays pending after saving.")
                .font(.system(size: 12.5))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(CcColors.warn)
    }
}
