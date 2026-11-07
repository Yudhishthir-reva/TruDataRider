//
//  LedgerScreen.swift
//  TrudataRider
//
//  Collections in and amounts taken out, newest first, with the filter-wide totals and the per-day
//  totals the server sends alongside the page.
//

import SwiftUI
import Combine

final class LedgerViewModel: ObservableObject {

    @Published var entries: [LedgerEntry] = []
    @Published var summary: LedgerSummary?
    @Published var days: [LedgerDay] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var range: CashDateRange = .lastDays(30)

    private var page = 1
    private var hasMore = false
    private let service = CashCollectionServiceManager()
    private var cancellables = Set<AnyCancellable>()

    func load(refresh: Bool = false) {
        guard !isLoading else { return }
        if refresh { page = 1 }
        isLoading = true
        errorMessage = nil

        service.ledger(range: range, staffIds: [], page: 1)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                self.entries = response.entries
                self.summary = response.summary
                self.days = response.days
                self.page = response.meta.currentPage
                self.hasMore = response.hasMore
            }
            .store(in: &cancellables)
    }

    func loadMore() {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true

        service.ledger(range: range, staffIds: [], page: page + 1)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoadingMore = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoadingMore = false
                // Rows are unique per type, not per id, so the key carries both.
                let known = Set(self.entries.map(\.id))
                self.entries += response.entries.filter { !known.contains($0.id) }
                self.page = response.meta.currentPage
                self.hasMore = response.hasMore
            }
            .store(in: &cancellables)
    }

    func rangeChanged(_ newRange: CashDateRange) {
        range = newRange
        load(refresh: true)
    }
}

struct LedgerScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LedgerViewModel()

    var onHome: () -> Void

    var body: some View {
        ZStack {
            CcColors.page.ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Ledger",
                    onBack: { dismiss() },
                    onHome: onHome,
                    onRefresh: { viewModel.load(refresh: true) }
                )

                ScrollView {
                    LazyVStack(spacing: 10) {
                        if let summary = viewModel.summary {
                            summaryHero(summary)
                        }

                        CcFilterChipRow(
                            options: [("today", "Today"), ("7", "Last 7 days"), ("30", "Last 30 days"), (nil, "All time")],
                            selection: rangeSelection
                        )

                        if !viewModel.days.isEmpty {
                            dayTotals
                        }

                        CcContentState(
                            isLoading: viewModel.isLoading && viewModel.entries.isEmpty,
                            errorMessage: viewModel.entries.isEmpty ? viewModel.errorMessage : nil,
                            isEmpty: viewModel.entries.isEmpty,
                            emptyTitle: "No movement",
                            emptyBody: "Cash submitted and cash taken out will be listed here for the period you pick.",
                            emptyImage: "book",
                            onRetry: { viewModel.load(refresh: true) }
                        ) {
                            VStack(spacing: 8) {
                                ForEach(viewModel.entries) { entry in
                                    LedgerRow(entry: entry)
                                        .onAppear {
                                            if entry.id == viewModel.entries.last?.id {
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
                    .padding(12)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if viewModel.entries.isEmpty {
                viewModel.load()
            }
        }
    }

    private func summaryHero(_ summary: LedgerSummary) -> some View {
        CcHero {
            CcHeroLabel(text: "Closing balance · \(viewModel.range.label)")
            Text(CashFormat.rupees(summary.closingBalance))
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                CcHeroStat(label: "Opening", value: CashFormat.rupees(summary.openingBalance))
                CcHeroStat(label: "Collected", value: CashFormat.rupees(summary.totalCollection))
                CcHeroStat(label: "Taken", value: CashFormat.rupees(summary.totalTaken))
            }
        }
    }

    private var dayTotals: some View {
        CcSection(title: "Day by day", systemImage: "calendar") {
            VStack(spacing: 6) {
                ForEach(viewModel.days) { day in
                    HStack {
                        Text(CashFormat.pretty(day.date))
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(CcColors.text)
                        Spacer()
                        Text("+\(CashFormat.rupees(day.totalCollection))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(CcColors.ok)
                        Text("−\(CashFormat.rupees(day.totalTaken))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(CcColors.warn)
                        Text(CashFormat.rupees(day.netAmount))
                            .font(.system(size: 12.5, weight: .heavy))
                            .foregroundStyle(CcColors.text)
                            .frame(width: 84, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var rangeSelection: Binding<String?> {
        Binding(
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
    }
}

private struct LedgerRow: View {
    let entry: LedgerEntry

    var body: some View {
        HStack(spacing: 12) {
            CcIconDisc(
                systemImage: entry.isTaken ? "arrow.up.right" : "arrow.down.left",
                accent: entry.isTaken ? CcColors.warn : CcColors.ok,
                size: 36
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.isTaken ? "Amount taken" : "Collection")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(CcColors.text)
                if let name = entry.staff?.name, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(CcColors.textMuted)
                }
                Text(CashFormat.pretty(entry.date))
                    .font(.system(size: 11))
                    .foregroundStyle(CcColors.textFaint)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(CashFormat.rupees(entry.signedAmount))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(entry.isTaken ? CcColors.warn : CcColors.ok)
                if let balance = entry.balanceAfter {
                    Text("Bal \(CashFormat.rupees(balance))")
                        .font(.system(size: 10.5))
                        .foregroundStyle(CcColors.textFaint)
                }
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
