//
//  CashCollectionScreen.swift
//  TrudataRider
//
//  Android `CashCollectionScreen`: submit cash, look back over what has been submitted, and (for
//  reviewers) the denomination summary.
//

import SwiftUI

/// `denomination-summary` answers 403 to sale persons and riders today (v2 lists it as admin-only),
/// so the Summary tab is shown to reviewers only. Flip this once the server returns a staff member's
/// own summary to them.
private let summaryForEveryone = false

struct CashCollectionScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CashCollectionViewModel()
    @StateObject private var summaryViewModel = DenominationSummaryViewModel()

    var onHome: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SellersAppBar(
                title: "Cash Collection",
                onBack: { dismiss() },
                onHome: onHome,
                onRefresh: refreshAction
            )

            ScrollView {
                LazyVStack(spacing: 10) {
                    CashSegmented(options: tabs, selection: viewModel.tab) { viewModel.selectTab($0) }

                    switch viewModel.tab {
                    case .submit:
                        submitTab
                    case .list:
                        listTab
                    case .summary:
                        DenominationSummaryView(viewModel: summaryViewModel)
                    }
                }
                .padding(12)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if viewModel.tab == .submit {
                    CashActionTray {
                        CashCountSummary(declared: viewModel.declared, counts: viewModel.counts)
                    } buttons: {
                        CashSecondaryButton(title: "Clear", systemImage: "arrow.counterclockwise") {
                            viewModel.clearForm()
                        }
                        .containerRelativeFrame(.horizontal) { width, _ in (width - 42) * 0.34 }
                        CashPrimaryButton(title: "Submit", systemImage: "paperplane.fill", isLoading: viewModel.isSubmitting) {
                            viewModel.requestSubmit()
                        }
                    }
                }
            }
        }
        .background(CcColors.page.ignoresSafeArea())
        .navigationBarHidden(true)
        .onChange(of: viewModel.tab) { _, tab in
            if tab == .summary { summaryViewModel.ensureLoaded() }
        }
        .overlay { dialogs }
    }

    // MARK: - Tabs

    private var tabs: [(value: CollectionTab, title: String)] {
        var options: [(value: CollectionTab, title: String)] = [(.submit, "Submit"), (.list, viewModel.listTitle)]
        if summaryForEveryone || viewModel.access.canReviewAll {
            options.append((.summary, "Summary"))
        }
        return options
    }

    private var refreshAction: (() -> Void)? {
        switch viewModel.tab {
        case .submit: return nil
        case .list: return { viewModel.refresh() }
        case .summary: return { summaryViewModel.refresh() }
        }
    }

    // MARK: - Submit

    private var submitTab: some View {
        VStack(spacing: 10) {
            DenominationFormView(
                declaredText: viewModel.declaredText,
                counts: viewModel.counts,
                declaredError: viewModel.declaredError,
                onDeclaredChange: { viewModel.declaredChanged($0) },
                onCountChange: { viewModel.countChanged($0, to: $1) }
            )

            CashSection(title: "Submit remark", systemImage: "text.bubble", subtitle: "Optional") {
                CashTextField(
                    text: .constant(viewModel.remark),
                    placeholder: "e.g. Cash collected from morning route",
                    minLines: 2,
                    onChange: { viewModel.remarkChanged($0) }
                )
            }
        }
    }

    // MARK: - List

    private var listTab: some View {
        VStack(spacing: 10) {
            CashFilterBar(filter: viewModel.filter, staffOptions: viewModel.staffOptions) {
                viewModel.filterChanged($0)
            }

            if viewModel.access.canReviewAll {
                CashChipRow(
                    options: [
                        (nil, "All"),
                        (CashStatus.pending, "Pending"),
                        (CashStatus.approved, "Approved"),
                        (CashStatus.rejected, "Rejected")
                    ],
                    selection: viewModel.statusFilter
                ) { viewModel.statusFilterChanged($0) }
            }

            CollectionList(
                list: viewModel.list,
                showSubmitter: viewModel.access.canReviewAll,
                emptyText: viewModel.emptyText,
                onHome: onHome,
                onRetry: { viewModel.refresh() },
                onLoadMore: { viewModel.loadMore() }
            )
        }
    }

    // MARK: - Dialogs

    @ViewBuilder
    private var dialogs: some View {
        if let error = viewModel.formError {
            CashErrorDialog(message: error, title: "Check the counts") { viewModel.formError = nil }
        } else if viewModel.isConfirming {
            CashConfirmDialog(
                title: "Submit \(CashFormat.rupees(viewModel.declared))?",
                message: "\(viewModel.pieces) notes and coins adding up to \(CashFormat.rupees(viewModel.counted)). "
                    + "It goes to your admin for approval. You can't change it after submitting.",
                confirmTitle: "Submit",
                systemImage: "paperplane.fill",
                onConfirm: { viewModel.submit() },
                onDismiss: { viewModel.isConfirming = false }
            )
        } else if let submitted = viewModel.submitted {
            SubmittedDialog(
                collection: submitted,
                buttonTitle: viewModel.access.canReviewAll ? "View collections" : "View my collections",
                onDone: { viewModel.acknowledgeSubmitted() }
            )
        }
    }
}

/// Android's "Cash submitted" pop-up.
private struct SubmittedDialog: View {
    let collection: CashCollection
    let buttonTitle: String
    var onDone: () -> Void

    var body: some View {
        CcDialog(onDismiss: onDone) {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(CcColors.ok)
                Text("Cash submitted")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(CcColors.text)
                Text(CashFormat.rupees(collection.totalAmount))
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(CcColors.text)
                CcStatusPill(status: collection.status.isEmpty ? CashStatus.pending : collection.status)
                Text([collection.submittedAt, "Waiting for approval"].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 13))
                    .foregroundStyle(CcColors.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        } buttons: {
            CashPrimaryButton(title: buttonTitle, action: onDone)
        }
    }
}

// MARK: - List

/// Android `collectionList`: rows, or the loading / error / empty state standing in for them.
struct CollectionList: View {
    let list: CashListState<CashCollection>
    let showSubmitter: Bool
    let emptyText: String
    var onHome: () -> Void
    var onRetry: () -> Void
    var onLoadMore: () -> Void

    var body: some View {
        if list.isLoading && list.items.isEmpty {
            CcLoadingBlock()
        } else if let error = list.error, list.items.isEmpty {
            CashErrorState(message: error, onRetry: onRetry)
        } else if list.loaded && list.items.isEmpty {
            CashEmptyState(title: "Nothing here yet", message: emptyText)
        } else {
            LazyVStack(spacing: 10) {
                if list.total > 0 {
                    Text("\(list.total) collection\(list.total == 1 ? "" : "s") · \(CashFormat.rupees(list.items.reduce(0) { $0 + $1.totalAmount })) shown")
                        .font(.system(size: 12))
                        .foregroundStyle(CcColors.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
                ForEach(list.items) { collection in
                    NavigationLink {
                        CollectionDetailScreen(collectionId: collection.id, onHome: onHome)
                    } label: {
                        CollectionRow(collection: collection, showSubmitter: showSubmitter)
                    }
                    .buttonStyle(.plain)
                    .cashLoadMore(collection, in: list.items, action: onLoadMore)
                }
                if list.isLoadingMore {
                    CcLoadingBlock()
                }
            }
        }
    }
}

/// Android `CollectionRow`.
struct CollectionRow: View {
    let collection: CashCollection
    var showSubmitter: Bool

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 3) {
                Text(CashFormat.rupees(collection.totalAmount))
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(CcColors.text)

                if showSubmitter, let submitter = collection.submittedBy {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(CcColors.textMuted)
                        Text(submitter.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CcColors.text)
                    }
                }

                Text(collection.submittedAt ?? "#\(collection.id)")
                    .font(.system(size: 12))
                    .foregroundStyle(CcColors.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            CcStatusPill(status: collection.status)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CcColors.textFaint)
        }
        .padding(12)
        .background(CcColors.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(CcColors.border, lineWidth: 1))
        .contentShape(Rectangle())
    }
}
