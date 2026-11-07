//
//  CashCollectionScreen.swift
//  TrudataRider
//
//  Three tabs behind one screen, as on Android: submit today's cash, look back over what has been
//  submitted, and (for reviewers) the denomination summary.
//

import SwiftUI

struct CashCollectionScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CashCollectionViewModel()
    @StateObject private var summaryViewModel = DenominationSummaryViewModel()

    var onHome: () -> Void

    var body: some View {
        ZStack {
            CcColors.page.ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Cash Collection",
                    onBack: { dismiss() },
                    onHome: onHome,
                    onRefresh: refreshActiveTab
                )

                ScrollView {
                    LazyVStack(spacing: 10) {
                        CcSegmented(options: tabs, selection: $viewModel.tab)
                            .padding(.bottom, 2)

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
            }

            if viewModel.tab == .submit {
                VStack {
                    Spacer()
                    CcBottomActionBar {
                        CountSummary(declared: viewModel.declared, counts: viewModel.counts)
                        CcSecondaryButton(title: "Clear", systemImage: "arrow.counterclockwise") {
                            viewModel.clearForm()
                        }
                        .frame(width: 110)
                        CcPrimaryButton(
                            title: "Submit",
                            systemImage: "paperplane.fill",
                            isLoading: viewModel.isSubmitting
                        ) {
                            viewModel.requestSubmit()
                        }
                        .frame(width: 140)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if viewModel.collections.isEmpty {
                viewModel.loadList()
            }
        }
        .onChange(of: viewModel.tab) { tab in
            if tab == .summary {
                summaryViewModel.ensureLoaded()
            }
        }
        .alert("Submit this cash?", isPresented: $viewModel.isConfirming) {
            Button("Cancel", role: .cancel) {}
            Button("Submit") { viewModel.submit() }
        } message: {
            Text("\(CashFormat.rupees(viewModel.declared)) — \(viewModel.noteCount) notes and \(viewModel.coinCount) coins. The counts can't be changed once a reviewer approves them.")
        }
        .alert("Cash submitted", isPresented: Binding(
            get: { viewModel.submitted != nil },
            set: { if !$0 { viewModel.dismissSubmitted() } }
        )) {
            Button("Done") { viewModel.dismissSubmitted() }
        } message: {
            if let submitted = viewModel.submitted {
                Text("\(CashFormat.rupees(submitted.totalAmount)) is now waiting for review.")
            }
        }
        .alert("Can't submit", isPresented: Binding(
            get: { viewModel.formError != nil },
            set: { if !$0 { viewModel.formError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.formError = nil }
        } message: {
            Text(viewModel.formError ?? "")
        }
    }

    // MARK: - Tabs

    private var tabs: [(value: CollectionTab, title: String)] {
        [
            (.submit, "Submit"),
            (.list, viewModel.listTitle),
            (.summary, "Summary")
        ]
    }

    private func refreshActiveTab() {
        switch viewModel.tab {
        case .submit:
            break
        case .list:
            viewModel.loadList(refresh: true)
        case .summary:
            summaryViewModel.load()
        }
    }

    // MARK: - Submit

    private var submitTab: some View {
        VStack(spacing: 10) {
            DenominationFormView(
                declaredText: $viewModel.declaredText,
                counts: viewModel.counts,
                declaredError: viewModel.declaredError,
                onDeclaredChange: { viewModel.declaredChanged($0) },
                onCountChange: { viewModel.countChanged($0, to: $1) }
            )

            CcSection(title: "Submit remark", systemImage: "square.and.pencil") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Optional")
                        .font(.system(size: 11.5))
                        .foregroundStyle(CcColors.textMuted)
                    TextField(
                        "e.g. Cash collected from morning route",
                        text: $viewModel.remark,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                    .font(.system(size: 14))
                    .padding(10)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(CcColors.border, lineWidth: 1)
                    )
                }
            }

            // Clears the bottom action bar so the last field stays reachable.
            Color.clear.frame(height: 96)
        }
    }

    // MARK: - List

    private var listTab: some View {
        VStack(spacing: 10) {
            CcFilterChipRow(options: rangeOptions, selection: rangeSelection)

            if viewModel.access.canReviewAll {
                CcFilterChipRow(
                    options: [
                        (nil, "All"),
                        (CashStatus.pending, "Pending"),
                        (CashStatus.approved, "Approved"),
                        (CashStatus.rejected, "Rejected")
                    ],
                    selection: Binding(
                        get: { viewModel.statusFilter },
                        set: { viewModel.statusFilterChanged($0) }
                    )
                )
            }

            CcContentState(
                isLoading: viewModel.isLoadingList && viewModel.collections.isEmpty,
                errorMessage: viewModel.collections.isEmpty ? viewModel.listError : nil,
                isEmpty: viewModel.collections.isEmpty,
                emptyTitle: "No collections yet",
                emptyBody: viewModel.access.canReviewAll
                    ? "Nothing has been submitted for this period."
                    : "Cash you submit will show up here with its approval status.",
                emptyImage: "indianrupeesign.circle",
                onRetry: { viewModel.loadList(refresh: true) }
            ) {
                VStack(spacing: 8) {
                    ForEach(viewModel.collections) { collection in
                        NavigationLink {
                            CollectionDetailScreen(collectionId: collection.id, onHome: onHome)
                        } label: {
                            CollectionRow(
                                collection: collection,
                                showSubmitter: viewModel.access.canReviewAll
                            )
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if collection.id == viewModel.collections.last?.id {
                                viewModel.loadMore()
                            }
                        }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .tint(CcColors.primary)
                            .padding(.vertical, 12)
                    }
                }
            }
        }
    }

    private var rangeOptions: [(value: String?, title: String)] {
        [(nil, "All time"), ("today", "Today"), ("7", "Last 7 days"), ("30", "Last 30 days")]
    }

    private var rangeSelection: Binding<String?> {
        Binding(
            get: {
                guard !viewModel.range.isAllTime else { return nil }
                if viewModel.range == .today { return "today" }
                if viewModel.range == .lastDays(7) { return "7" }
                if viewModel.range == .lastDays(30) { return "30" }
                return nil
            },
            set: { key in
                switch key {
                case "today": viewModel.rangeChanged(.today)
                case "7": viewModel.rangeChanged(.lastDays(7))
                case "30": viewModel.rangeChanged(.lastDays(30))
                default: viewModel.rangeChanged(.allTime)
                }
            }
        )
    }
}

// MARK: - Row

struct CollectionRow: View {
    let collection: CashCollection
    var showSubmitter: Bool

    var body: some View {
        HStack(spacing: 12) {
            CcIconDisc(systemImage: "indianrupeesign", accent: CcColors.primary, size: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(CashFormat.rupees(collection.totalAmount))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(CcColors.text)

                if showSubmitter, let name = collection.submittedBy?.name, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CcColors.textMuted)
                }

                Text(CashFormat.pretty(collection.submittedAt))
                    .font(.system(size: 11.5))
                    .foregroundStyle(CcColors.textFaint)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                CcStatusPill(status: collection.status)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CcColors.textFaint)
            }
        }
        .padding(12)
        .background(CcColors.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(CcColors.border, lineWidth: 1)
        )
    }
}

// MARK: - Summary tab

struct DenominationSummaryView: View {

    @ObservedObject var viewModel: DenominationSummaryViewModel

    var body: some View {
        VStack(spacing: 10) {
            CcFilterChipRow(
                options: [(nil, "All time"), ("today", "Today"), ("7", "Last 7 days"), ("30", "Last 30 days")],
                selection: Binding(
                    get: {
                        if viewModel.range.isAllTime { return nil }
                        if viewModel.range == .today { return "today" }
                        if viewModel.range == .lastDays(7) { return "7" }
                        if viewModel.range == .lastDays(30) { return "30" }
                        return nil
                    },
                    set: { key in
                        switch key {
                        case "today": viewModel.rangeChanged(.today)
                        case "7": viewModel.rangeChanged(.lastDays(7))
                        case "30": viewModel.rangeChanged(.lastDays(30))
                        default: viewModel.rangeChanged(.allTime)
                        }
                    }
                )
            )

            CcContentState(
                isLoading: viewModel.isLoading && viewModel.summary == nil,
                errorMessage: viewModel.summary == nil ? viewModel.errorMessage : nil,
                isEmpty: (viewModel.summary?.totalEntries ?? 0) == 0,
                emptyTitle: "Nothing counted yet",
                emptyBody: "Once cash is submitted for this period, the note and coin totals show up here.",
                emptyImage: "chart.bar",
                onRetry: { viewModel.load() }
            ) {
                VStack(spacing: 10) {
                    totalHero
                    notesCoinsCard
                    denominationBars
                    if viewModel.access.canReviewAll, !viewModel.staffWise.isEmpty {
                        staffBreakdown
                    }
                }
            }
        }
    }

    private var totalHero: some View {
        CcHero {
            CcHeroLabel(text: viewModel.range.label)
            Text(CashFormat.rupees(viewModel.summary?.grandTotalAmount ?? 0))
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(.white)
            HStack(spacing: 12) {
                CcHeroStat(
                    label: "Entries",
                    value: String(viewModel.summary?.totalEntries ?? 0)
                )
                CcHeroStat(label: "Notes", value: CashFormat.rupees(viewModel.notesTotal))
                CcHeroStat(label: "Coins", value: CashFormat.rupees(viewModel.coinsTotal))
            }
        }
    }

    private var notesCoinsCard: some View {
        CcSection(title: "Notes vs coins", systemImage: "chart.pie") {
            VStack(alignment: .leading, spacing: 10) {
                GeometryReader { proxy in
                    HStack(spacing: 0) {
                        CcColors.primary
                            .frame(width: proxy.size.width * viewModel.notesShare)
                        CcColors.warn
                    }
                }
                .frame(height: 10)
                .clipShape(Capsule())

                HStack {
                    LegendRow(
                        color: CcColors.primary,
                        label: "Notes",
                        amount: CashFormat.rupees(viewModel.notesTotal)
                    )
                    Spacer()
                    LegendRow(
                        color: CcColors.warn,
                        label: "Coins",
                        amount: CashFormat.rupees(viewModel.coinsTotal)
                    )
                }

                Text("\((viewModel.notesShare * 1000).rounded() / 10, specifier: "%.1f")% in notes")
                    .font(.system(size: 11.5))
                    .foregroundStyle(CcColors.textMuted)
            }
        }
    }

    private var denominationBars: some View {
        CcSection(title: "By denomination", systemImage: "list.bullet") {
            let grand = max(viewModel.summary?.grandTotalAmount ?? 0, 1)
            VStack(spacing: 10) {
                ForEach(viewModel.lines) { line in
                    DenominationBarRow(line: line, fraction: line.total / grand)
                }
            }
        }
    }

    private var staffBreakdown: some View {
        CcSection(title: "By staff", systemImage: "person.2") {
            VStack(spacing: 8) {
                ForEach(viewModel.staffWise) { staff in
                    StaffSummaryRow(
                        staff: staff,
                        isExpanded: viewModel.expandedStaff.contains(staff.staffId),
                        onToggle: { viewModel.toggleStaff(staff.staffId) }
                    )
                }
            }
        }
    }
}

private struct LegendRow: View {
    let color: Color
    let label: String
    let amount: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(CcColors.textMuted)
            Text(amount)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(CcColors.text)
        }
    }
}

private struct DenominationBarRow: View {
    let line: SummaryDenomination
    let fraction: Double

    var body: some View {
        let tint = line.denomination.map(denominationTint) ?? CcColors.primary

        VStack(spacing: 5) {
            HStack(spacing: 10) {
                if let denomination = line.denomination {
                    DenominationBadge(denomination: denomination)
                } else {
                    Text(line.label)
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 60, alignment: .leading)
                }

                Text("× \(line.qty)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(CcColors.text)

                Spacer(minLength: 8)

                Text(CashFormat.rupees(line.total))
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(CcColors.text)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    CcColors.track
                    tint.frame(width: max(proxy.size.width * fraction, 2))
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
        }
    }
}

private struct StaffSummaryRow: View {
    let staff: StaffSummary
    let isExpanded: Bool
    var onToggle: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    Text(initials(staff.staffName))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(CcColors.primary)
                        .frame(width: 34, height: 34)
                        .background(CcColors.container, in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(staff.staffName.isEmpty ? "—" : staff.staffName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(CcColors.text)
                        Text("\(staff.entries) \(staff.entries == 1 ? "entry" : "entries")")
                            .font(.system(size: 11.5))
                            .foregroundStyle(CcColors.textMuted)
                    }

                    Spacer(minLength: 8)

                    Text(CashFormat.rupees(staff.totalAmount))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(CcColors.text)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CcColors.textFaint)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                FlowChips(lines: staff.denominations.filter { $0.qty > 0 })
            }
        }
        .padding(10)
        .background(CcColors.page, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init)?.uppercased() }.joined()
        return letters.isEmpty ? "?" : letters
    }
}

/// The per-staff denomination chips, wrapped onto as many rows as they need.
private struct FlowChips: View {
    let lines: [SummaryDenomination]

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 92), spacing: 6)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(lines) { line in
                HStack(spacing: 4) {
                    if let denomination = line.denomination {
                        Circle()
                            .fill(denominationTint(denomination))
                            .frame(width: 7, height: 7)
                    }
                    Text("\(line.label) × \(line.qty)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(CcColors.text)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.white, in: Capsule())
                .overlay(Capsule().stroke(CcColors.border, lineWidth: 1))
            }
        }
    }
}
