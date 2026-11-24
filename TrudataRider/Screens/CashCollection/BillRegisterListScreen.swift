//
//  BillRegisterListScreen.swift
//  TrudataRider
//
//  Android `BillListScreen`. Managers see every register, filter by status and employee, and start
//  new ones; anyone else sees the registers assigned to them. Everyone can look a register up by an
//  order in it. The rider app signs in riders only, so here it is always "My Bill Register".
//

import SwiftUI
import Combine

final class BillRegisterListViewModel: ObservableObject {

    @Published private(set) var registers: [BillRegister] = []
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    /// A first page has come back (or failed), so an empty list means "none", not "not yet".
    @Published private(set) var loaded = false
    @Published private(set) var errorMessage: String?
    /// Nil is every status. Pending first, as on Android: what is still to collect.
    @Published private(set) var status: String? = BillStatus.pending
    @Published private(set) var employee: PersonOption?
    /// What is typed; `orderId` is what the list is filtered by once the typing settles.
    @Published private(set) var orderIdInput = ""
    @Published private(set) var orderId: String?
    @Published private(set) var people = PeopleState()

    let access = CashAccess.current

    private var page = 1
    private var hasMore = false
    /// The first-page request in flight. A new one replaces it, so a quick filter change can't land
    /// the previous filter's rows (Android `Pager.load` cancels the same way).
    private var firstPage: AnyCancellable?
    private var nextPage: AnyCancellable?
    private var orderSearch: DispatchWorkItem?
    private let service = CashCollectionServiceManager()
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Android `CashCollectionBus`: a register created, cleared or reassigned elsewhere refreshes
        // this list in place.
        NotificationCenter.default.publisher(for: .billRegisterChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.load(refresh: true) }
            .store(in: &cancellables)
    }

    var isManager: Bool { access.canManageBills }

    var title: String { isManager ? "Bill Register" : "My Bill Register" }

    /// The order filter as shown: "#1780" whether or not the "#" was typed.
    var orderIdLabel: String? {
        orderId.map { $0.hasPrefix("#") ? $0 : "#\($0)" }
    }

    /// The first load; later visits keep what is on screen.
    func start() {
        guard !loaded, !isLoading else { return }
        load()
        if isManager { loadPeople() }
    }

    /// `refresh` keeps the rows on screen while the first page reloads; otherwise the list empties
    /// and shows the loader, as a new filter should.
    func load(refresh: Bool = false) {
        firstPage?.cancel()
        nextPage?.cancel()
        isLoadingMore = false
        if !(refresh && !registers.isEmpty) {
            registers = []
            isLoading = true
        }
        errorMessage = nil

        firstPage = request(page: 1)
            .sink { [weak self] result in
                guard let self else { return }
                self.isLoading = false
                self.loaded = true
                switch result {
                case .success(let response):
                    self.registers = response.items
                    self.total = response.meta.total
                    self.page = response.meta.currentPage
                    self.hasMore = response.hasMore
                case .failure(let message):
                    // A failed refresh keeps the rows that are already up.
                    if self.registers.isEmpty { self.errorMessage = message }
                }
                self.firstPage = nil
            }
    }

    func loadMore() {
        guard hasMore, !isLoading, !isLoadingMore, firstPage == nil else { return }
        isLoadingMore = true

        nextPage = request(page: page + 1)
            .sink { [weak self] result in
                guard let self else { return }
                self.isLoadingMore = false
                // A failed next page keeps what is on screen; scrolling to the end again retries.
                if case .success(let response) = result {
                    let known = Set(self.registers.map(\.id))
                    self.registers += response.items.filter { !known.contains($0.id) }
                    self.total = response.meta.total
                    self.page = response.meta.currentPage
                    self.hasMore = response.hasMore
                }
            }
    }

    func setStatus(_ value: String?) {
        guard value != status else { return }
        status = value
        load()
    }

    func setEmployee(_ person: PersonOption?) {
        guard person?.id != employee?.id else { return }
        employee = person
        load()
    }

    /// Typing filters on its own once it pauses for 0.4s; clearing the box drops the filter at once.
    func setOrderIdInput(_ value: String) {
        guard value != orderIdInput else { return }
        orderSearch?.cancel()
        orderIdInput = value
        if value.trimmingCharacters(in: .whitespaces).isEmpty {
            clearOrderId()
            return
        }
        let work = DispatchWorkItem { [weak self] in self?.applyOrderId(forceReload: false) }
        orderSearch = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    /// The search key or the magnifier: search now, and again even if the text hasn't changed.
    func searchOrderId() {
        orderSearch?.cancel()
        applyOrderId(forceReload: true)
    }

    func clearOrderId() {
        orderSearch?.cancel()
        let hadFilter = orderId != nil
        orderIdInput = ""
        orderId = nil
        if hadFilter { load() }
    }

    func loadPeople() {
        people.isLoading = true
        people.error = nil
        service.billPeople()
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self, case .failure(let error) = completion else { return }
                self.people = PeopleState(error: (error as? RequestError)?.errorString ?? "Couldn't load the staff list")
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.people = response.status
                    ? PeopleState(items: response.people)
                    : PeopleState(error: response.message.isEmptyString ? "Couldn't load the staff list" : response.message)
            }
            .store(in: &cancellables)
    }

    private func applyOrderId(forceReload: Bool) {
        let input = orderIdInput.trimmingCharacters(in: .whitespaces)
        guard !input.isEmpty else {
            clearOrderId()
            return
        }
        let changed = input != orderId
        orderIdInput = input
        orderId = input
        if changed || forceReload { load() }
    }

    private enum PageResult {
        case success(BillRegisterListResponse)
        case failure(String)
    }

    /// One page under the current filters. A server "status: false" is a failure like a transport
    /// error, with the server's message when it sent one.
    private func request(page: Int) -> AnyPublisher<PageResult, Never> {
        service.billRegisters(
            status: status,
            assignedTo: isManager ? employee?.id : nil,
            page: page,
            orderId: orderId
        )
        .map { response -> PageResult in
            response.status
                ? .success(response)
                : .failure(response.message.isEmptyString ? "Something went wrong. Try again." : response.message)
        }
        .catch { error in
            Just(.failure((error as? RequestError)?.errorString ?? error.localizedDescription))
        }
        .receive(on: RunLoop.main)
        .eraseToAnyPublisher()
    }
}

struct BillRegisterListScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BillRegisterListViewModel()
    @State private var isCreating = false
    @State private var showEmployee = false

    var onHome: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SellersAppBar(
                title: viewModel.title,
                onBack: { dismiss() },
                onHome: onHome,
                onRefresh: { viewModel.load(refresh: true) }
            )

            ScrollView {
                LazyVStack(spacing: 10) {
                    BillOrderIdField(
                        text: Binding(get: { viewModel.orderIdInput }, set: { viewModel.setOrderIdInput($0) }),
                        supporting: viewModel.orderIdLabel.map { "Showing registers for order \($0)" }
                            ?? "Searches automatically within the selected filters",
                        onSearch: { viewModel.searchOrderId() },
                        onClear: { viewModel.clearOrderId() }
                    )

                    BillSegmented(
                        options: [
                            (BillStatus.pending, "Pending"),
                            (BillStatus.cleared, "Cleared"),
                            (BillStatus.cancelled, "Cancelled"),
                            (nil, "All")
                        ],
                        selection: viewModel.status,
                        onSelect: { viewModel.setStatus($0) }
                    )

                    if viewModel.isManager {
                        employeeFilter
                    }

                    content
                }
                .padding(12)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(CcColors.page.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.isManager {
                BillBottomBar {
                    BillPrimaryButton(title: "New Bill Register", systemImage: "plus.circle.fill") {
                        isCreating = true
                    }
                }
            }
        }
        .overlay {
            if showEmployee {
                BillPersonPicker(
                    state: viewModel.people,
                    selectedId: viewModel.employee?.id,
                    onRetry: { viewModel.loadPeople() },
                    onPick: { viewModel.setEmployee($0); showEmployee = false },
                    onDismiss: { showEmployee = false }
                )
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $isCreating) {
            BillRegisterCreateScreen(onHome: onHome)
        }
        .onAppear { viewModel.start() }
    }

    private var employeeFilter: some View {
        VStack(alignment: .leading, spacing: 0) {
            BillPickerField(
                label: "Employee",
                value: viewModel.employee?.name ?? "All employees",
                systemImage: "person.fill",
                isPlaceholder: viewModel.employee == nil
            ) { showEmployee = true }
            if viewModel.employee != nil {
                Button("Show all employees") { viewModel.setEmployee(nil) }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CcColors.primary)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.registers.isEmpty {
            BillLoadingBlock()
        } else if let error = viewModel.errorMessage, viewModel.registers.isEmpty {
            BillErrorState(message: error) { viewModel.load(refresh: true) }
        } else if viewModel.loaded && viewModel.registers.isEmpty {
            BillEmptyState(
                title: isCancelledTab ? "No cancelled registers" : "No registers",
                message: emptyMessage,
                systemImage: isCancelledTab ? "nosign" : "tray"
            )
        } else if !viewModel.registers.isEmpty {
            Text("\(viewModel.total) register\(viewModel.total == 1 ? "" : "s")")
                .font(.system(size: 12))
                .foregroundStyle(CcColors.textMuted)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(viewModel.registers) { register in
                NavigationLink {
                    BillRegisterDetailScreen(registerId: register.id, onHome: onHome)
                } label: {
                    BillRegisterCard(register: register, showAssignee: viewModel.isManager)
                }
                .buttonStyle(.plain)
                // A register that leaves the filtered list on refresh slides out instead of popping.
                .transition(.opacity.combined(with: .move(edge: .leading)))
                .onAppear {
                    if register.id == viewModel.registers.last?.id { viewModel.loadMore() }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.registers.map(\.id))

            if viewModel.isLoadingMore {
                BillLoadingBlock()
            }
        }
    }

    private var isCancelledTab: Bool { viewModel.status == BillStatus.cancelled }

    /// Android's empty-state lines, most specific first.
    private var emptyMessage: String {
        let manager = viewModel.isManager
        if let label = viewModel.orderIdLabel {
            return "No register found for order \(label) with the selected filters."
        }
        if !manager && isCancelledTab { return "Registers of yours that the office cancels show up here." }
        if !manager { return "No bills are assigned to you" + (viewModel.status != nil ? " with this status." : ".") }
        if let employee = viewModel.employee { return "\(employee.name) has no registers with this status." }
        if isCancelledTab { return "Registers that are cancelled, or whose bills are all removed, show up here." }
        return "Tap New Bill Register to pick beats and assign their pending bills."
    }
}

/// Android's Material outlined "Order ID" field: the label sits in the box until it is focused or
/// filled, then floats onto the border; a magnifier searches now, a cross clears, and a helper line
/// says what the list is showing.
private struct BillOrderIdField: View {
    @Binding var text: String
    let supporting: String
    let onSearch: () -> Void
    let onClear: () -> Void
    @FocusState private var focused: Bool

    private var floats: Bool { focused || !text.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Button {
                    onSearch()
                    focused = false
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .foregroundStyle(BillTone.onSurfaceVariant)
                .accessibilityLabel("Search order ID")

                ZStack(alignment: .leading) {
                    if !floats {
                        Text("Order ID")
                            .font(.system(size: 16))
                            .foregroundStyle(BillTone.onSurfaceVariant)
                            .allowsHitTesting(false)
                    }
                    TextField(floats ? "e.g. #2026-27/1780" : "", text: $text)
                        .font(.system(size: 16))
                        .foregroundStyle(CcColors.text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .focused($focused)
                        .onSubmit {
                            onSearch()
                            focused = false
                        }
                }

                if !text.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16))
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(BillTone.onSurfaceVariant)
                    .accessibilityLabel("Clear order ID")
                }
            }
            .padding(.horizontal, 4)
            .frame(height: 56)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(focused ? CcColors.primary : BillTone.outline, lineWidth: focused ? 2 : 1)
            )
            .overlay(alignment: .topLeading) {
                if floats {
                    Text("Order ID")
                        .font(.system(size: 12))
                        .foregroundStyle(focused ? CcColors.primary : BillTone.onSurfaceVariant)
                        .padding(.horizontal, 4)
                        .background(CcColors.page)
                        .offset(x: 12, y: -8)
                }
            }
            .animation(.easeOut(duration: 0.15), value: floats)

            Text(supporting)
                .font(.system(size: 12))
                .foregroundStyle(BillTone.onSurfaceVariant)
                .padding(.horizontal, 16)
        }
        .padding(.top, 6)
    }
}

/// Android `BillRegisterCard`. A cancelled register ends with who called it off and why, and its
/// struck-out total, instead of the progress bar. Removed bills drop out of the order count.
struct BillRegisterCard: View {
    let register: BillRegister
    /// Managers see whose register it is; a rider only ever sees their own.
    var showAssignee = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Register #\(register.id)")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(CcColors.text)
                Text(register.createdAt ?? "")
                    .font(.system(size: 11.5))
                    .foregroundStyle(CcColors.textMuted)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                BillStatusPill(status: register.status)
            }
            if showAssignee {
                Text("Assigned to \(register.assignedTo ?? "—")" + (register.assignedBy.map { " · by \($0)" } ?? ""))
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(CcColors.text)
            }
            if !register.beatNames.isEmpty {
                Text(register.beatNames.joined(separator: " · "))
                    .font(.system(size: 12.5))
                    .foregroundStyle(CcColors.textMuted)
            }
            if register.isCancelled {
                cancelledLine
            } else {
                BillClearedBar(cleared: register.clearedOrders, total: register.activeOrders)
                progressLine
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CcColors.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(CcColors.border, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var progressLine: some View {
        HStack(spacing: 0) {
            Text("\(register.clearedOrders) of \(register.activeOrders) orders cleared"
                 + (register.removedOrders > 0 ? " · \(register.removedOrders) removed" : ""))
                .font(.system(size: 12))
                .foregroundStyle(CcColors.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !register.isCleared && register.pendingAmount > 0 {
                Text("Pending ")
                    .font(.system(size: 12))
                    .foregroundStyle(CcColors.textMuted)
                Text(CashFormat.rupees(register.pendingAmount))
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(CcColors.warn)
            } else {
                Text(CashFormat.rupees(register.totalAmount))
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(CcColors.text)
            }
        }
    }

    /// Who called it off and when, the reason on one line, and the total struck out.
    private var cancelledLine: some View {
        HStack(alignment: .top, spacing: 0) {
            Image(systemName: "nosign")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CcColors.err)
                .frame(width: 15, height: 15)
                .padding(.top, 1)
                .padding(.trailing, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(["Cancelled" + (register.cancelledBy.map { " by \($0)" } ?? ""), billStamp(register.cancelledAt)]
                    .compactMap { $0 }
                    .joined(separator: " · "))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CcColors.err)
                if let reason = register.cancelReason {
                    BillQuote(text: reason, lines: 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(CashFormat.rupees(register.totalAmount))
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(CcColors.textFaint)
                .strikethrough()
                .padding(.leading, 8)
        }
    }
}
