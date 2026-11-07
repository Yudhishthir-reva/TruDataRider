//
//  AdvanceListScreen.swift
//  TrudataRider
//
//  Advances given and payments returned against them. A manager sees everyone's; a rider or sale
//  person only their own, and the status, role and search filters don't apply to that list.
//

import SwiftUI
import Combine

final class AdvanceListViewModel: ObservableObject {

    @Published var records: [AdvanceRecord] = []
    @Published var summary: AdvanceSummary?
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var query = AdvanceQuery()

    let access = CashAccess.current

    private var page = 1
    private var hasMore = false
    private let service = CashCollectionServiceManager()
    private var cancellables = Set<AnyCancellable>()

    var title: String {
        access.canManageAdvance ? "Payment Advance" : "My Payment Advance"
    }

    func load(refresh: Bool = false) {
        guard !isLoading else { return }
        if refresh { page = 1 }
        isLoading = true
        errorMessage = nil

        listPublisher(page: 1)
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
                self.records = response.items
                self.summary = response.summary
                self.page = response.meta.currentPage
                self.hasMore = response.hasMore
            }
            .store(in: &cancellables)
    }

    func loadMore() {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true

        listPublisher(page: page + 1)
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
                let known = Set(self.records.map(\.id))
                self.records += response.items.filter { !known.contains($0.id) }
                self.page = response.meta.currentPage
                self.hasMore = response.hasMore
            }
            .store(in: &cancellables)
    }

    func typeChanged(_ type: String) {
        query.type = type
        load(refresh: true)
    }

    func statusChanged(_ status: String?) {
        query.status = status
        load(refresh: true)
    }

    private func listPublisher(page: Int) -> AnyPublisher<AdvanceListResponse, Error> {
        access.canManageAdvance
            ? service.advanceAllList(query: query, page: page)
            : service.advanceMyList(query: query, page: page)
    }
}

struct AdvanceListScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AdvanceListViewModel()
    @State private var isGiving = false

    var onHome: () -> Void

    var body: some View {
        ZStack {
            CcColors.page.ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: viewModel.title,
                    onBack: { dismiss() },
                    onHome: onHome,
                    onRefresh: { viewModel.load(refresh: true) }
                )

                ScrollView {
                    LazyVStack(spacing: 10) {
                        if let summary = viewModel.summary {
                            summaryHero(summary)
                        }

                        CcSegmented(
                            options: [
                                (AdvanceRecordType.all, "All"),
                                (AdvanceRecordType.advance, "Advances"),
                                (AdvanceRecordType.returned, "Returns")
                            ],
                            selection: Binding(
                                get: { viewModel.query.type },
                                set: { viewModel.typeChanged($0) }
                            )
                        )

                        if viewModel.access.canManageAdvance {
                            CcFilterChipRow(
                                options: [(nil, "Any status")] + AdvanceStatus.all.map {
                                    (Optional($0), AdvanceStatus.label($0))
                                },
                                selection: Binding(
                                    get: { viewModel.query.status },
                                    set: { viewModel.statusChanged($0) }
                                )
                            )
                        }

                        CcContentState(
                            isLoading: viewModel.isLoading && viewModel.records.isEmpty,
                            errorMessage: viewModel.records.isEmpty ? viewModel.errorMessage : nil,
                            isEmpty: viewModel.records.isEmpty,
                            emptyTitle: "No advances",
                            emptyBody: viewModel.access.canManageAdvance
                                ? "Advances you give to staff will be listed here."
                                : "Advances given to you, and what you have paid back, will show up here.",
                            emptyImage: "indianrupeesign.square",
                            onRetry: { viewModel.load(refresh: true) }
                        ) {
                            VStack(spacing: 8) {
                                ForEach(viewModel.records) { record in
                                    NavigationLink {
                                        AdvanceDetailScreen(advanceId: record.advanceId, onHome: onHome)
                                    } label: {
                                        AdvanceRow(record: record)
                                    }
                                    .buttonStyle(.plain)
                                    .onAppear {
                                        if record.id == viewModel.records.last?.id {
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

                        if viewModel.access.canManageAdvance {
                            Color.clear.frame(height: 80)
                        }
                    }
                    .padding(12)
                }
            }

            if viewModel.access.canManageAdvance {
                VStack {
                    Spacer()
                    CcBottomActionBar {
                        CcPrimaryButton(title: "Give advance", systemImage: "plus") {
                            isGiving = true
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if viewModel.records.isEmpty {
                viewModel.load()
            }
        }
        .sheet(isPresented: $isGiving) {
            GiveAdvanceForm { viewModel.load(refresh: true) }
        }
    }

    private func summaryHero(_ summary: AdvanceSummary) -> some View {
        CcHero {
            if viewModel.access.canManageAdvance {
                CcHeroLabel(text: "Outstanding")
                Text(CashFormat.rupees(summary.pendingReturn))
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.white)
                HStack(spacing: 12) {
                    CcHeroStat(label: "Given", value: CashFormat.rupees(summary.advanceGiven))
                    CcHeroStat(label: "Received back", value: CashFormat.rupees(summary.paymentReceived))
                }
            } else {
                CcHeroLabel(text: "Still to return")
                Text(CashFormat.rupees(summary.advanceReceived - summary.returned))
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.white)
                HStack(spacing: 12) {
                    CcHeroStat(label: "Received", value: CashFormat.rupees(summary.advanceReceived))
                    CcHeroStat(label: "Returned", value: CashFormat.rupees(summary.returned))
                }
            }
        }
    }
}

struct AdvanceRow: View {
    let record: AdvanceRecord

    var body: some View {
        HStack(spacing: 12) {
            CcIconDisc(
                systemImage: record.isReturn ? "arrow.uturn.left" : "arrow.down.left",
                accent: record.isReturn ? CcColors.info : Color(hex: "1D4ED8"),
                size: 38
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(CashFormat.rupees(record.amount))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(CcColors.text)

                if let name = record.person?.name, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CcColors.textMuted)
                }

                Text("\(record.isReturn ? "Returned" : "Advance") · \(CashFormat.pretty(record.date))")
                    .font(.system(size: 11.5))
                    .foregroundStyle(CcColors.textFaint)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                if let status = record.status, !status.isEmpty {
                    CcPill(text: AdvanceStatus.label(status), tone: tone(for: status))
                }
                if let outstanding = record.outstanding, outstanding > 0 {
                    Text("Due \(CashFormat.rupees(outstanding))")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(CcColors.warn)
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

    private func tone(for status: String) -> PillTone {
        switch status.lowercased() {
        case AdvanceStatus.completed: return .ok
        case AdvanceStatus.partial: return .info
        case AdvanceStatus.cancelled: return .err
        case AdvanceStatus.onHold: return .violet
        default: return .warn
        }
    }
}
