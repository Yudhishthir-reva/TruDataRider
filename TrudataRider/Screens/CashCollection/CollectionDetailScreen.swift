//
//  CollectionDetailScreen.swift
//  TrudataRider
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
        ZStack {
            CcColors.page.ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Collection",
                    onBack: { dismiss() },
                    onHome: onHome,
                    onRefresh: { viewModel.load() }
                )

                ScrollView {
                    VStack(spacing: 10) {
                        if viewModel.isLoading && viewModel.collection == nil {
                            CcLoadingBlock()
                        } else if let loadError = viewModel.loadError, viewModel.collection == nil {
                            CcErrorState(message: loadError) { viewModel.load() }
                        } else if let collection = viewModel.collection {
                            if viewModel.isEditing {
                                editNotice
                                DenominationFormView(
                                    declaredText: $viewModel.editDeclaredText,
                                    counts: viewModel.editCounts,
                                    onDeclaredChange: { viewModel.editDeclaredChanged($0) },
                                    onCountChange: { viewModel.editCountChanged($0, to: $1) }
                                )
                            } else {
                                hero(collection)
                                breakup(collection)
                                submitRemark(collection)
                                reviewInfo(collection)
                                reviewRemarkField
                            }
                        }

                        // Clears the pinned action bar.
                        if actionBarIsVisible {
                            Color.clear.frame(height: 80)
                        }
                    }
                    .padding(12)
                }
            }

            if actionBarIsVisible {
                VStack {
                    Spacer()
                    actionBar
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if viewModel.collection == nil {
                viewModel.load()
            }
        }
        .alert(confirmTitle, isPresented: Binding(
            get: { viewModel.pendingAction != nil },
            set: { if !$0 { viewModel.pendingAction = nil } }
        )) {
            Button("Cancel", role: .cancel) { viewModel.pendingAction = nil }
            Button(viewModel.pendingAction?.isApprove == true ? "Approve" : "Reject") {
                viewModel.confirmReview()
            }
        } message: {
            Text(confirmBody)
        }
        .alert("Can't continue", isPresented: Binding(
            get: { viewModel.actionError != nil },
            set: { if !$0 { viewModel.actionError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.actionError = nil }
        } message: {
            Text(viewModel.actionError ?? "")
        }
        .alert("Done", isPresented: Binding(
            get: { viewModel.successMessage != nil },
            set: { if !$0 { viewModel.successMessage = nil } }
        )) {
            Button("OK") { viewModel.successMessage = nil }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
    }

    // MARK: - Action bar

    private var actionBarIsVisible: Bool {
        viewModel.isEditing || viewModel.canReview || viewModel.canEdit
    }

    @ViewBuilder
    private var actionBar: some View {
        CcBottomActionBar {
            if viewModel.isEditing {
                CcSecondaryButton(title: "Cancel", systemImage: "xmark", tint: CcColors.textMuted) {
                    viewModel.cancelEditing()
                }
                CcPrimaryButton(title: "Save changes", systemImage: "checkmark", isLoading: viewModel.isSaving) {
                    viewModel.saveEdit()
                }
            } else if viewModel.canReview {
                CcSecondaryButton(
                    title: "Reject",
                    systemImage: "xmark",
                    tint: CcColors.err,
                    isEnabled: !viewModel.isReviewing
                ) {
                    viewModel.requestReview(.reject)
                }
                CcPrimaryButton(
                    title: "Approve",
                    systemImage: "checkmark",
                    isLoading: viewModel.isReviewing
                ) {
                    viewModel.requestReview(.approve)
                }
            } else if viewModel.canEdit {
                CcSecondaryButton(title: "Edit counts", systemImage: "pencil") {
                    viewModel.startEditing()
                }
            }
        }
    }

    private var confirmTitle: String {
        let amount = CashFormat.rupees(viewModel.collection?.totalAmount ?? 0)
        return viewModel.pendingAction?.isApprove == true ? "Approve \(amount)?" : "Reject \(amount)?"
    }

    private var confirmBody: String {
        let amount = CashFormat.rupees(viewModel.collection?.totalAmount ?? 0)
        let who = viewModel.collection?.submittedBy?.name ?? "this person"
        if viewModel.pendingAction?.isApprove == true {
            return "This confirms you received \(amount) from \(who). Approved collections can't be edited."
        }
        return "\(who) will see it as rejected with your remark."
    }

    // MARK: - Sections

    private func hero(_ collection: CashCollection) -> some View {
        CcHero {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    CcHeroLabel(text: "Collection #\(collection.id)")
                    Text(CashFormat.rupees(collection.totalAmount))
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 8)
                CcStatusPill(status: collection.status)
            }

            if let name = collection.submittedBy?.name, !name.isEmpty {
                Text("Submitted by \(name)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            if let submittedAt = collection.submittedAt, !submittedAt.isEmpty {
                Text(submittedAt)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private func breakup(_ collection: CashCollection) -> some View {
        // Zero rows are noise on a read-only breakup; the ones that were counted are what matters.
        let lines = collection.denominations.filter { $0.qty > 0 && $0.denomination != nil }

        return CcSection(title: "Denomination details", systemImage: "banknote") {
            if lines.isEmpty {
                Text("No denomination breakup was sent for this collection.")
                    .font(.system(size: 13))
                    .foregroundStyle(CcColors.textMuted)
            } else {
                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        Text("Currency").frame(width: 70, alignment: .leading)
                        Text("Quantity").frame(maxWidth: .infinity, alignment: .center)
                        Text("Total").frame(width: 96, alignment: .trailing)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(CcColors.textFaint)

                    ForEach(lines) { line in
                        BreakupRow(line: line)
                    }

                    Divider().background(CcColors.divider)

                    HStack {
                        Text("Total")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(CcColors.text)
                        Spacer()
                        Text(CashFormat.rupees(lines.reduce(0) { $0 + $1.total }))
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(CcColors.primary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func submitRemark(_ collection: CashCollection) -> some View {
        if let remark = collection.submitRemark, !remark.isEmptyString {
            CcSection(title: "Submit remark", systemImage: "square.and.pencil") {
                Text(remark)
                    .font(.system(size: 13))
                    .foregroundStyle(CcColors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func reviewInfo(_ collection: CashCollection) -> some View {
        let hasRemark = !(collection.remark ?? "").isEmptyString
        if hasRemark || collection.reviewedBy != nil {
            CcSection(title: "Review", systemImage: "info.circle", accent: CcColors.info) {
                VStack(alignment: .leading, spacing: 4) {
                    if let name = collection.reviewedBy?.name, !name.isEmpty {
                        Text("Reviewed by \(name)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CcColors.text)
                    }
                    if let remark = collection.remark, !remark.isEmptyString {
                        Text("“\(remark)”")
                            .font(.system(size: 13))
                            .foregroundStyle(CcColors.textMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var reviewRemarkField: some View {
        if viewModel.canReview {
            CcSection(title: "Remark", systemImage: "square.and.pencil") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Required when rejecting")
                        .font(.system(size: 11.5))
                        .foregroundStyle(CcColors.textMuted)

                    TextField("e.g. Verified with the cash in hand", text: $viewModel.remark, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(viewModel.remarkError == nil ? CcColors.border : CcColors.err, lineWidth: 1)
                        )

                    if let remarkError = viewModel.remarkError {
                        Text(remarkError)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(CcColors.err)
                    }
                }
            }
        }
    }

    private var editNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(CcColors.warn)
            Text("Change the counts or the total. They must still add up. The collection stays pending after saving.")
                .font(.system(size: 12.5))
                .foregroundStyle(CcColors.warn)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(CcColors.warnBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct BreakupRow: View {
    let line: DenominationLine

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if let denomination = line.denomination {
                    DenominationBadge(denomination: denomination)
                } else {
                    Text(line.label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(CcColors.text)
                }
            }
            .frame(width: 70, alignment: .leading)

            VStack(spacing: 1) {
                Text(String(line.qty))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(CcColors.text)
                if line.denomination?.kind == .note, line.qty >= 100 {
                    Text(DenominationBundle.text(line.qty))
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
}

/// Notes come in bundles of 100; showing that makes a miscount of a whole bundle obvious.
enum DenominationBundle {
    static func text(_ count: Int) -> String {
        let bundles = count / 100
        let loose = count % 100
        return "\(bundles) bundle\(bundles > 1 ? "s" : "")" + (loose > 0 ? " + \(loose)" : "")
    }
}
