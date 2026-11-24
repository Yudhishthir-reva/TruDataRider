//
//  LedgerScreen.swift
//  TrudataRider
//
//  Android `LedgerScreen` / `LedgerViewModel`: `V2/cash-collection/ledger` — collections in and
//  amounts taken out, newest first. The list pages as you scroll; the totals and per-day figures
//  come with each page and cover the whole filter.
//

import Combine
import SwiftUI

final class LedgerViewModel: ObservableObject {

    let access = CashAccess.current

    @Published private(set) var filter = CashFilter(period: .month)
    @Published private(set) var people: [PersonOption] = []
    @Published private(set) var list = CashListState<LedgerEntry>()
    /// Filter-wide figures from the first page; nil until it arrives.
    @Published private(set) var summary: LedgerSummary?
    /// Per-day totals across the whole filter, so a day split over two pages still adds up.
    @Published private(set) var days: [String: LedgerDay] = [:]
    @Published private(set) var summaryVersion = 0
    /// The amount-taken line opened from the list; there is no detail endpoint for these.
    @Published var openTaken: LedgerEntry?

    private let service = CashCollectionServiceManager()
    private var cancellables = Set<AnyCancellable>()

    private lazy var pager = CashPager<LedgerEntry>(
        read: { [weak self] in self?.list },
        write: { [weak self] change in
            guard let self else { return }
            change(&self.list)
        },
        fetch: { [weak self] page in
            guard let self else { return Empty().eraseToAnyPublisher() }
            return self.fetch(page: page)
        }
    )

    init() {
        reload(refresh: false)
        if access.canReviewAll {
            CashPeople.load()
                .receive(on: RunLoop.main)
                .sink { _ in } receiveValue: { [weak self] people in self?.people = people }
                .store(in: &cancellables)
        }
        CashChange.publisher
            .sink { [weak self] _ in self?.reload(refresh: true) }
            .store(in: &cancellables)
    }

    /// A running balance only means something for one person's cash.
    var showsBalance: Bool { !access.canReviewAll || filter.staffIds.count == 1 }

    var staffOptions: [PersonOption]? {
        guard access.canReviewAll else { return nil }
        return cashMergePeople(people, list.items.compactMap { entry in
            entry.staff.map { PersonOption(id: $0.id, name: $0.name, role: "") }
        })
    }

    func filterChanged(_ value: CashFilter) {
        if value == filter && value.period != .today { return }
        filter = value
        reload(refresh: false)
    }

    func refresh() { reload(refresh: true) }

    func loadMore() { pager.loadMore() }

    private func reload(refresh: Bool) {
        if !refresh {
            summary = nil
            days = [:]
        }
        pager.load(refresh: refresh)
    }

    /// Hands the pager its rows and keeps the totals that came with them.
    private func fetch(page: Int) -> AnyPublisher<CashPage<LedgerEntry>, Error> {
        service.ledger(range: filter.dates(), staffIds: filter.staffIds, page: page)
            .receive(on: RunLoop.main)
            .map { [weak self] response in
                if let self {
                    self.summary = response.summary ?? (page > 1 ? self.summary : nil)
                    var merged = page == 1 ? [:] : self.days
                    for day in response.days { merged[day.date] = day }
                    self.days = merged
                    if page == 1 { self.summaryVersion += 1 }
                }
                return CashPage(items: response.entries, meta: response.meta)
            }
            .eraseToAnyPublisher()
    }
}

struct LedgerScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LedgerViewModel()
    @State private var openCollection: Int?

    var onHome: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SellersAppBar(
                title: "Ledger",
                onBack: { dismiss() },
                onHome: onHome,
                onRefresh: { viewModel.refresh() }
            )

            ScrollView {
                LazyVStack(spacing: 10) {
                    CashFilterBar(filter: viewModel.filter, staffOptions: viewModel.staffOptions) {
                        viewModel.filterChanged($0)
                    }
                    LedgerHero(viewModel: viewModel)
                        .cashEntrance(version: viewModel.summaryVersion, index: 0)
                    entries
                }
                .padding(12)
            }
        }
        .background(CcColors.page.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationDestination(item: $openCollection) { CollectionDetailScreen(collectionId: $0, onHome: onHome) }
        .overlay {
            if let entry = viewModel.openTaken {
                TakenDialog(entry: entry) { viewModel.openTaken = nil }
            }
        }
    }

    @ViewBuilder
    private var entries: some View {
        let list = viewModel.list
        if list.isLoading && list.items.isEmpty {
            CcLoadingBlock()
        } else if let error = list.error, list.items.isEmpty {
            CashErrorState(message: error) { viewModel.refresh() }
        } else if list.loaded && list.items.isEmpty {
            CashEmptyState(title: "No entries", message: "Nothing was collected or taken \(viewModel.filter.periodPhrase).", systemImage: "book")
        } else {
            // Newest first, as the server sends them; a header wherever the day changes.
            ForEach(groups(list.items), id: \.date) { group in
                DayHeader(date: group.date, entries: group.entries, day: viewModel.days[group.date])
                ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                    LedgerEntryRow(
                        entry: entry,
                        first: index == 0,
                        last: index == group.entries.count - 1,
                        showBalance: viewModel.showsBalance
                    ) {
                        if entry.isTaken { viewModel.openTaken = entry } else { openCollection = entry.entryId }
                    }
                    .cashLoadMore(entry, in: list.items) { viewModel.loadMore() }
                }
            }
            if list.isLoadingMore {
                CcLoadingBlock()
            }
            if !list.hasMore && list.items.count > 3 {
                Text("That's every entry \(viewModel.filter.periodPhrase).")
                    .font(.system(size: 12))
                    .foregroundStyle(CcColors.textFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
    }

    private func groups(_ items: [LedgerEntry]) -> [(date: String, entries: [LedgerEntry])] {
        var result: [(date: String, entries: [LedgerEntry])] = []
        for item in items {
            if let index = result.firstIndex(where: { $0.date == item.date }) {
                result[index].entries.append(item)
            } else {
                result.append((item.date, [item]))
            }
        }
        return result
    }
}

private struct LedgerHero: View {
    @ObservedObject var viewModel: LedgerViewModel

    var body: some View {
        let items = viewModel.list.items
        let summary = viewModel.summary
        // Before the filter-wide figures arrive, show what is loaded.
        let collected = summary?.totalCollection ?? items.filter { !$0.isTaken }.reduce(0) { $0 + $1.amount }
        let taken = summary?.totalTaken ?? items.filter(\.isTaken).reduce(0) { $0 + $1.amount }
        let net = summary?.netAmount ?? (collected - taken)
        CashHero {
            CashHeroLabel(text: "Net cash")
            CashCountingAmount(target: net, version: viewModel.summaryVersion)
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(.white)
            Text(viewModel.filter.periodLabel + (viewModel.filter.staffIds.isEmpty ? "" : " · \(viewModel.filter.staffIds.count) staff"))
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.8))
            HStack(spacing: 6) {
                CashHeroStat(label: "Collected", value: "+" + CashFormat.rupees(collected))
                CashHeroStat(label: "Taken", value: taken > 0 ? "−" + CashFormat.rupees(taken) : CashFormat.rupees(0))
                CashHeroStat(label: "Entries", value: "\(viewModel.list.total)")
                    .containerRelativeFrame(.horizontal) { width, _ in (width - 64) * 0.7 / 2.7 }
            }
            .padding(.top, 6)
            if let summary {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Opening balance").font(.system(size: 10)).foregroundStyle(.white.opacity(0.72))
                        Text(CashFormat.rupees(summary.openingBalance)).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Closing balance").font(.system(size: 10)).foregroundStyle(.white.opacity(0.72))
                        Text(CashFormat.rupees(summary.closingBalance)).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.top, 2)
            }
        }
    }
}

private struct DayHeader: View {
    let date: String
    let entries: [LedgerEntry]
    let day: LedgerDay?

    var body: some View {
        // The server's day totals cover the whole day even when only part of it has paged in.
        let collected = day?.totalCollection ?? entries.filter { !$0.isTaken }.reduce(0) { $0 + $1.amount }
        let taken = day?.totalTaken ?? entries.filter(\.isTaken).reduce(0) { $0 + $1.amount }
        let net = day?.netAmount ?? (collected - taken)
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(CcColors.text)
                Text("+" + CashFormat.rupees(collected) + (taken > 0 ? "  ·  −" + CashFormat.rupees(taken) : ""))
                    .font(.system(size: 11.5))
                    .foregroundStyle(CcColors.textMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("Net").font(.system(size: 10)).foregroundStyle(CcColors.textFaint)
                Text(CashFormat.rupees(net))
                    .font(.system(size: 13.5, weight: .heavy))
                    .foregroundStyle(net < 0 ? CcColors.err : CcColors.primary)
            }
        }
        .padding(.top, 6)
        .padding(.horizontal, 4)
    }

    private var label: String {
        guard let parsed = CashFormat.date(fromApi: date), date.count >= 10 else { return date }
        let calendar = CashDates.calendar
        if calendar.isDateInToday(parsed) { return "Today" }
        if calendar.isDateInYesterday(parsed) { return "Yesterday" }
        return CashDates.format(parsed, "EEE, d MMM yyyy")
    }
}

/// One line on a timeline rail: green for cash in, red for cash taken out.
private struct LedgerEntryRow: View {
    let entry: LedgerEntry
    let first: Bool
    let last: Bool
    let showBalance: Bool
    var onTap: () -> Void

    var body: some View {
        let accent = entry.isTaken ? CcColors.err : CcColors.ok
        let accentBg = entry.isTaken ? CcColors.errBg : CcColors.okBg
        HStack(spacing: 10) {
            Group {
                if entry.isTaken {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(accent)
                } else {
                    Text(cashInitials(entry.staff?.name ?? ""))
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(CcColors.primary)
                }
            }
            .frame(width: 38, height: 38)
            .background(entry.isTaken ? accentBg : CcColors.container, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.staff?.name ?? "—")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(CcColors.text)
                        .lineLimit(1)
                    if !entry.status.isEmpty && entry.status.lowercased() != CashStatus.approved {
                        CcStatusPill(status: entry.status)
                    }
                }
                Text([timeOf(entry.submittedAt), entry.isTaken ? (entry.reason?.nilIfEmpty ?? "Amount taken") : "Collection #\(entry.entryId)"]
                    .compactMap { $0 }
                    .joined(separator: " · "))
                    .font(.system(size: 11.5))
                    .foregroundStyle(CcColors.textMuted)
                    .lineLimit(1)
                if entry.isTaken, let takenBy = entry.takenBy {
                    Text("Taken by \(takenBy.name)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(CcColors.textMuted)
                        .lineLimit(1)
                }
                if let remark = entry.remark?.nilIfEmpty {
                    Text("“\(remark)”")
                        .font(.system(size: 11.5))
                        .italic()
                        .foregroundStyle(CcColors.textMuted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 1) {
                Text((entry.isTaken ? "−" : "+") + CashFormat.rupees(entry.amount))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(entry.isTaken ? CcColors.err : CcColors.text)
                if showBalance, let balance = entry.balanceAfter {
                    Text("Bal \(CashFormat.rupees(balance))")
                        .font(.system(size: 10.5))
                        .foregroundStyle(CcColors.textFaint)
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CcColors.textFaint)
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(CcColors.border, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .padding(.vertical, 4)
        .padding(.leading, 28)
        .background(alignment: .leading) {
            VStack(spacing: 0) {
                (first ? Color.clear : CcColors.border).frame(width: 2, height: 22)
                Circle()
                    .fill(accent)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(accentBg, lineWidth: 2))
                (last ? Color.clear : CcColors.border).frame(width: 2).frame(maxHeight: .infinity)
            }
            .frame(width: 22)
        }
    }
}

/// An amount taken has no detail endpoint, so the ledger line itself is the whole record.
private struct TakenDialog: View {
    let entry: LedgerEntry
    var onDismiss: () -> Void

    var body: some View {
        CcDialog(onDismiss: onDismiss) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "minus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(CcColors.err)
                        .frame(width: 40, height: 40)
                        .background(CcColors.errBg, in: Circle())
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Amount taken").font(.system(size: 12)).foregroundStyle(CcColors.textMuted)
                        Text("−" + CashFormat.rupees(entry.amount))
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(CcColors.err)
                    }
                    Spacer()
                    if !entry.status.isEmpty { CcStatusPill(status: entry.status) }
                }
                VStack(spacing: 8) {
                    line("From", entry.staff?.name ?? "—")
                    line("Taken by", entry.takenBy?.name ?? "—")
                    line("Reason", entry.reason?.nilIfEmpty ?? "—")
                    let when = [dayOf(entry.date), timeOf(entry.submittedAt)].compactMap { $0 }.joined(separator: ", ")
                    line("When", when.isEmpty ? "—" : when)
                    if let balance = entry.balanceAfter { line("Balance after", CashFormat.rupees(balance)) }
                    if let remark = entry.remark?.nilIfEmpty { line("Remark", remark) }
                    line("Reference", "#\(entry.entryId)")
                }
                .padding(12)
                .background(CcColors.page, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        } buttons: {
            Button(action: onDismiss) {
                Text("Close")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(CcColors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(CcColors.container, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func line(_ label: String, _ value: String) -> some View {
        CashDetailLine(label: label, value: value, labelWidth: 104, trailingValue: true)
    }
}

/// "2026-09-30 14:30:00" → "2:30 PM". The older "30 Sep 2026, 02:30 PM" still reads; a bare date
/// gives nothing.
private func timeOf(_ submittedAt: String?) -> String? {
    guard let raw = submittedAt?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    for pattern in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm"] {
        parser.dateFormat = pattern
        if let date = parser.date(from: raw) { return CashDates.format(date, "h:mm a") }
    }
    guard let range = raw.range(of: ", ") else { return nil }
    let rest = String(raw[range.upperBound...])
    return rest.isEmpty ? nil : rest
}

private func dayOf(_ date: String) -> String? {
    if let parsed = CashFormat.date(fromApi: date), date.count >= 10 { return CashDates.format(parsed, "d MMM yyyy") }
    return date.isEmpty ? nil : date
}
