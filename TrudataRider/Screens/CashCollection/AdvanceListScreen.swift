//
//  AdvanceListScreen.swift
//  TrudataRider
//
//  Android `AdvanceListScreen` / `AdvanceListViewModel`: advances given and payments returned
//  against them. Managers (admin, accountant, sales manager) get everyone's with search and filters;
//  a sale person or rider gets their own.
//

import Combine
import SwiftUI

/// Roles an advance can be filtered by, with the ids `role_id` expects. Admin isn't given advances.
let advanceRoles: [(id: Int, label: String)] = [(2, "Sales Manager"), (3, "Sale Person"), (4, "Rider"), (5, "Accountant")]

final class AdvanceListViewModel: ObservableObject {

    let access = CashAccess.current

    @Published private(set) var type = AdvanceRecordType.all
    /// All time by default: what is still owed matters whenever it was given.
    @Published private(set) var filter = CashFilter(period: .all)
    @Published private(set) var status: String?
    @Published private(set) var roleId: Int?
    @Published private(set) var search = ""
    @Published private(set) var list = CashListState<AdvanceRecord>()
    @Published private(set) var summary: AdvanceSummary?
    /// Person id → role name. The API leaves `person.role` null, so it comes from the staff list.
    @Published private(set) var roles: [Int: String] = [:]
    @Published private(set) var people: [PersonOption] = []
    /// The advance row whose change-status sheet is open.
    @Published var statusTarget: AdvanceRecord?
    @Published private(set) var isUpdatingStatus = false
    @Published var message: String?
    @Published var error: String?

    private let service = CashCollectionServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var statusJob: AnyCancellable?
    private let searchInput = PassthroughSubject<Void, Never>()

    private lazy var pager = CashPager<AdvanceRecord>(
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
        pager.load()
        if isManager {
            CashPeople.load()
                .receive(on: RunLoop.main)
                .sink { _ in } receiveValue: { [weak self] people in
                    guard let self else { return }
                    self.people = people
                    self.roles = Dictionary(
                        people.filter { !$0.role.isEmpty }.map { ($0.id, $0.role) },
                        uniquingKeysWith: { first, _ in first }
                    )
                }
                .store(in: &cancellables)
        }
        CashChange.publisher
            .sink { [weak self] change in
                guard change == .advance else { return }
                self?.pager.load(refresh: true)
            }
            .store(in: &cancellables)
        searchInput
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] in self?.pager.load() }
            .store(in: &cancellables)
    }

    var isManager: Bool { access.canManageAdvance }

    var title: String { isManager ? "Payment Advance" : "My Payment Advance" }

    func personLabel(_ record: AdvanceRecord) -> String? {
        guard let person = record.person else { return nil }
        let role = (person.role?.isEmptyString == false ? person.role : nil) ?? roles[person.id]
        return person.name + (role.map { " · \($0)" } ?? "")
    }

    var staffOptions: [PersonOption]? {
        guard isManager else { return nil }
        let seen = list.items.compactMap { record in
            record.person.map { PersonOption(id: $0.id, name: $0.name, role: $0.role ?? roles[$0.id] ?? "") }
        }
        return cashMergePeople(people, seen)
    }

    var emptyText: String {
        if !isManager { return "No advance was given to you \(filter.periodPhrase)." }
        if !search.isEmptyString || status != nil || roleId != nil || !filter.staffIds.isEmpty {
            return "No records match these filters."
        }
        return "No advance was given \(filter.periodPhrase). Tap Give Advance to add one."
    }

    // MARK: - Intents

    func typeChanged(_ value: String) {
        guard value != type else { return }
        type = value
        pager.load()
    }

    func filterChanged(_ value: CashFilter) {
        guard value != filter else { return }
        filter = value
        pager.load()
    }

    func statusChanged(_ value: String?) {
        guard value != status else { return }
        status = value
        pager.load()
    }

    func roleChanged(_ value: Int?) {
        guard value != roleId else { return }
        roleId = value
        pager.load()
    }

    func searchChanged(_ text: String) {
        search = text
        searchInput.send()
    }

    func refresh() { pager.load(refresh: true) }

    func loadMore() { pager.loadMore() }

    func setStatus(_ newStatus: String) {
        guard let target = statusTarget, !isUpdatingStatus else { return }
        isUpdatingStatus = true
        statusJob = service.updateAdvanceStatus(id: target.recordId, status: newStatus)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self, case .failure(let failure) = completion else { return }
                self.isUpdatingStatus = false
                self.error = CashError.message(failure)
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isUpdatingStatus = false
                guard let advance = response.data else {
                    self.error = CashError.server(response.message) ?? CashError.empty
                    return
                }
                self.statusTarget = nil
                let label = AdvanceStatus.label(advance.status.isEmpty ? newStatus : advance.status)
                self.message = "\(CashFormat.rupees(target.amount)) advance to \(target.person?.name ?? "staff") set to \(label)"
                // Totals move too (a cancelled advance is no longer pending), so reload rather than patch.
                self.pager.load(refresh: true)
            }
    }

    private func fetch(page: Int) -> AnyPublisher<CashPage<AdvanceRecord>, Error> {
        let query = AdvanceQuery(
            type: type,
            range: filter.dates(),
            // A returned row has no status, so the status filter only applies to advances.
            status: type == AdvanceRecordType.returned ? nil : status,
            roleId: roleId,
            search: search,
            staffIds: isManager ? filter.staffIds : []
        )
        let publisher = isManager
            ? service.advanceAllList(query: query, page: page)
            : service.advanceMyList(query: query, page: page)
        return publisher
            .receive(on: RunLoop.main)
            .map { [weak self] response in
                // The summary covers the whole filter, so the first page's is the one to keep.
                if page == 1 { self?.summary = response.summary }
                return CashPage(items: response.items, meta: response.meta)
            }
            .eraseToAnyPublisher()
    }
}

struct AdvanceListScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AdvanceListViewModel()
    @State private var showGive = false
    @State private var openAdvance: Int?
    @State private var receiveAdvance: Int?

    var onHome: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SellersAppBar(
                title: viewModel.title,
                onBack: { dismiss() },
                onHome: onHome,
                onRefresh: { viewModel.refresh() }
            )

            ScrollView {
                LazyVStack(spacing: 10) {
                    SummaryHero(summary: viewModel.summary, manager: viewModel.isManager)

                    CashSegmented(
                        options: [
                            (AdvanceRecordType.all, "All"),
                            (AdvanceRecordType.advance, viewModel.isManager ? "Advance Given" : "Advance"),
                            (AdvanceRecordType.returned, viewModel.isManager ? "Received" : "Returned")
                        ],
                        selection: viewModel.type
                    ) { viewModel.typeChanged($0) }

                    if viewModel.isManager {
                        managerFilters
                    }

                    CashFilterBar(filter: viewModel.filter, staffOptions: viewModel.staffOptions) {
                        viewModel.filterChanged($0)
                    }

                    records
                }
                .padding(12)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if viewModel.isManager {
                    CashActionTray {
                        CashPrimaryButton(title: "Give Advance", systemImage: "plus.circle.fill") { showGive = true }
                    }
                }
            }
        }
        .background(CcColors.page.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showGive) { GiveAdvanceScreen(onHome: onHome) }
        .navigationDestination(item: $openAdvance) { AdvanceDetailScreen(advanceId: $0, onHome: onHome) }
        .navigationDestination(item: $receiveAdvance) { ReceivePaymentScreen(advanceId: $0, onHome: onHome) }
        .sheet(item: $viewModel.statusTarget) { record in
            AdvanceStatusSheet(
                current: record.status ?? "",
                title: "\(CashFormat.rupees(record.amount)) to \(record.person?.name ?? "staff") · due \(CashFormat.rupees(record.outstanding ?? 0))",
                isSaving: viewModel.isUpdatingStatus,
                onSave: { viewModel.setStatus($0) }
            )
            // A failed save keeps the sheet open, with the error over it.
            .cashErrorDialog($viewModel.error)
        }
        .cashToast($viewModel.message)
        .cashErrorDialog($viewModel.error)
    }

    private var managerFilters: some View {
        VStack(spacing: 8) {
            CashSearchField(
                text: Binding(get: { viewModel.search }, set: { viewModel.searchChanged($0) }),
                placeholder: "Search by name, purpose, remark…",
                showsClear: true
            )
            CashChipRow(
                options: [(nil, "All roles")] + advanceRoles.map { (String($0.id), $0.label) },
                selection: viewModel.roleId.map(String.init)
            ) { viewModel.roleChanged($0.flatMap { Int($0) }) }
            if viewModel.type != AdvanceRecordType.returned {
                CashChipRow(
                    options: [(nil, "Any status")] + AdvanceStatus.all.map { ($0, AdvanceStatus.label($0)) },
                    selection: viewModel.status
                ) { viewModel.statusChanged($0) }
            }
        }
    }

    @ViewBuilder
    private var records: some View {
        let list = viewModel.list
        if list.isLoading && list.items.isEmpty {
            CcLoadingBlock()
        } else if let error = list.error, list.items.isEmpty {
            CashErrorState(message: error) { viewModel.refresh() }
        } else if list.loaded && list.items.isEmpty {
            CashEmptyState(title: "Nothing here", message: viewModel.emptyText)
        } else {
            Text("\(list.total) record\(list.total == 1 ? "" : "s")")
                .font(.system(size: 12))
                .foregroundStyle(CcColors.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            ForEach(list.items) { record in
                AdvanceRecordCard(
                    record: record,
                    person: viewModel.isManager ? viewModel.personLabel(record) : nil,
                    showsMenu: viewModel.isManager,
                    onOpen: { openAdvance = record.advanceId },
                    onReceive: { receiveAdvance = record.recordId },
                    onStatus: { viewModel.statusTarget = record }
                )
                .cashLoadMore(record, in: list.items) { viewModel.loadMore() }
            }
            if list.isLoadingMore {
                CcLoadingBlock()
            }
        }
    }
}

/// The filter-wide totals: given, received and still due (a manager), or received, returned and due (own).
private struct SummaryHero: View {
    let summary: AdvanceSummary?
    let manager: Bool

    var body: some View {
        let given = manager ? (summary?.advanceGiven ?? 0) : (summary?.advanceReceived ?? 0)
        let back = manager ? (summary?.paymentReceived ?? 0) : (summary?.returned ?? 0)
        let due = manager ? (summary?.pendingReturn ?? 0) : max(given - back, 0)
        CashHero {
            CashHeroLabel(text: manager ? "Pending return" : "Still to return")
            Text(CashFormat.rupees(due))
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                CashHeroStat(label: manager ? "Advance given" : "Advance received", value: CashFormat.rupees(given))
                CashHeroStat(label: manager ? "Payment received" : "Returned", value: CashFormat.rupees(back))
            }
            .padding(.top, 6)
        }
    }
}

/// Android `AdvanceRecordCard`: one line of the advance list. `person` and the ⋮ actions are for
/// managers, who see everyone's.
struct AdvanceRecordCard: View {
    let record: AdvanceRecord
    let person: String?
    var showsMenu = false
    var onOpen: () -> Void
    var onReceive: () -> Void = {}
    var onStatus: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(CashDates.pretty(record.date))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CcColors.textMuted)
                CcPill(text: record.isReturn ? "Returned" : "Advance", tone: record.isReturn ? .violet : .info)
                Spacer(minLength: 4)
                Text((record.isReturn ? "+ " : "") + CashFormat.rupees(record.amount))
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(record.isReturn ? CcColors.ok : CcColors.text)
                if showsMenu {
                    menu
                }
            }
            if let person {
                HStack(spacing: 7) {
                    Text(cashInitials(record.person?.name ?? ""))
                        .font(.system(size: 9.5, weight: .heavy))
                        .foregroundStyle(CcColors.primary)
                        .frame(width: 24, height: 24)
                        .background(CcColors.container, in: RoundedRectangle(cornerRadius: 12))
                    Text(person)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(CcColors.text)
                }
            }
            if let note = record.isReturn ? record.remark : record.purpose, !note.isEmptyString {
                Text(note)
                    .font(.system(size: 13))
                    .foregroundStyle(CcColors.text)
            }
            HStack(spacing: 6) {
                Text(footer)
                    .font(.system(size: 12))
                    .foregroundStyle(CcColors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !record.isReturn {
                    let due = record.outstanding ?? 0
                    let status = record.status ?? ""
                    if due > 0 && AdvanceStatus.isOpen(status) && due < record.amount {
                        Text("Due \(CashFormat.rupees(due))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(CcColors.warn)
                    }
                    CashAdvanceStatusPill(status: status)
                }
            }
            .padding(.trailing, showsMenu ? 10 : 0)
        }
        .padding(.leading, 12)
        .padding(.vertical, 12)
        .padding(.trailing, showsMenu ? 2 : 12)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(CcColors.border, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }

    private var footer: String {
        let by = (record.isReturn ? record.receivedBy : record.givenBy)?.name
        let parts: [String?] = [
            by.map { (record.isReturn ? "Received by " : "By ") + $0 },
            record.isReturn ? record.parentAdvanceId.map { "Advance #\($0)" } : nil,
            record.attachment != nil ? "Bill attached" : nil
        ]
        let text = parts.compactMap { $0 }.joined(separator: " · ")
        return text.isEmpty ? " " : text
    }

    /// Android `AdvanceRowMenu`.
    private var menu: some View {
        Menu {
            Button(action: onOpen) { Label("View details", systemImage: "eye") }
            if !record.isReturn && AdvanceStatus.isOpen(record.status ?? "") && (record.outstanding ?? 0) > 0 {
                Button(action: onReceive) { Label("Receive payment", systemImage: "arrow.down.left") }
            }
            if !record.isReturn {
                Button(action: onStatus) { Label("Change status", systemImage: "clock.arrow.circlepath") }
            }
        } label: {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CcColors.textMuted)
                .frame(width: 36, height: 36)
        }
        .accessibilityLabel("Actions")
    }
}

/// Android `ChangeStatusSheet`: pick a new status for an advance; the current one is marked and
/// can't be re-sent.
struct AdvanceStatusSheet: View {
    let current: String
    let title: String
    let isSaving: Bool
    var onSave: (String) -> Void

    @State private var picked: String

    init(current: String, title: String, isSaving: Bool, onSave: @escaping (String) -> Void) {
        self.current = current
        self.title = title
        self.isSaving = isSaving
        self.onSave = onSave
        _picked = State(initialValue: current.lowercased())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Change status")
                .font(.system(size: 18, weight: .heavy))
            Text(title)
                .font(.system(size: 12.5))
                .foregroundStyle(CcColors.textMuted)
            ForEach(AdvanceStatus.all, id: \.self) { status in
                let isOn = status == picked
                Button {
                    picked = status
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: icon(status))
                            .font(.system(size: 19))
                            .foregroundStyle(cashAdvanceTone(status).foreground)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(AdvanceStatus.label(status))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(CcColors.text)
                            Text(hint(status))
                                .font(.system(size: 12))
                                .foregroundStyle(CcColors.textMuted)
                        }
                        Spacer()
                        if status == current.lowercased() {
                            Text("Current")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(CcColors.textMuted)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(isOn ? CcColors.container : .white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isOn ? CcColors.primary : CcColors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            CashPrimaryButton(
                title: "Set to \(AdvanceStatus.label(picked))",
                isEnabled: picked != current.lowercased(),
                isLoading: isSaving
            ) { onSave(picked) }
            .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 20)
        .presentationDetents([.large])
        .presentationBackground(.white)
    }

    /// What each status means, shown under it.
    private func hint(_ status: String) -> String {
        switch status {
        case AdvanceStatus.pending: return "Given, nothing returned yet"
        case AdvanceStatus.partial: return "Some returned, some still due"
        case AdvanceStatus.completed: return "Fully returned"
        case AdvanceStatus.onHold: return "Processing paused for now"
        case AdvanceStatus.cancelled: return "Entered by mistake; not owed"
        default: return ""
        }
    }

    private func icon(_ status: String) -> String {
        switch status {
        case AdvanceStatus.pending: return "hourglass"
        case AdvanceStatus.partial: return "clock.arrow.circlepath"
        case AdvanceStatus.completed: return "checkmark.circle"
        case AdvanceStatus.onHold: return "pause.circle"
        default: return "nosign"
        }
    }
}
