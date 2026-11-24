//
//  BillRegisterCreateScreen.swift
//  TrudataRider
//
//  Android `BillCreateScreen`. Pick beats, pick the delivered orders whose payment is still
//  pending, and hand the register to someone from the staff list. Orders already in a register are
//  shown but can't be picked — the server doesn't stop a second register from taking them. Nothing
//  is sent until a summary is confirmed, and changing beats or leaving asks first whenever picks
//  would be thrown away. Once created, the new register's detail takes this screen's place.
//
//  Only a manager reaches this (the list's "New Bill Register"), so a rider never sees it.
//

import SwiftUI
import Combine

final class BillRegisterCreateViewModel: ObservableObject {

    @Published private(set) var beats: [Beat] = []
    @Published private(set) var beatsLoading = true
    @Published private(set) var beatsError: String?
    @Published private(set) var selectedBeats: Set<Int> = []
    @Published private(set) var orders: [BeatOrder] = []
    @Published private(set) var ordersLoading = false
    @Published private(set) var ordersError: String?
    @Published private(set) var selectedOrders: Set<Int> = []
    @Published var query = ""
    @Published private(set) var people = PeopleState()
    @Published private(set) var employee: PersonOption?
    @Published private(set) var isSaving = false
    /// A form problem, shown as "Can't continue".
    @Published var error: String?
    /// The create summary is up; it stays up while saving, so a failure can be read and retried.
    @Published private(set) var confirming = false
    @Published private(set) var confirmError: String?
    /// Beats waiting on a yes, because switching to them would untick bills already picked.
    @Published private(set) var pendingBeats: Set<Int>?
    /// Set once created; the screen moves on to it.
    @Published private(set) var createdId: Int?

    private let service = CashCollectionServiceManager()
    private var beatsRequest: AnyCancellable?
    private var ordersRequest: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadBeats()
        loadPeople()
    }

    var picks: BillCreatePicks {
        BillCreatePicks(selectedBeats: selectedBeats, orders: orders, selectedOrders: selectedOrders, createdId: createdId)
    }

    /// Orders not yet in any register.
    var open: [BeatOrder] { orders.filter { !$0.isAssigned } }

    /// The orders that match the search: shop, seller, order number or beat.
    var shown: [BeatOrder] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return orders }
        return orders.filter { order in
            [order.sellerShopName, order.sellerName, order.orderNo, order.beatName]
                .compactMap { $0?.lowercased() }
                .contains { $0.contains(q) }
        }
    }

    var selectedTotal: Double { picks.picked.reduce(0) { $0 + $1.pendingAmount } }

    /// Leaving would throw picks away, so it asks first — but not mid-save.
    var guardsLeaving: Bool { picks.hasPicks && !isSaving }

    /// Every active beat, A–Z. `beat-list` pages by 50, so this walks the pages until the last one.
    func loadBeats() {
        beatsLoading = true
        beatsError = nil
        beatsRequest = nil
        loadBeatsPage(1, accumulated: [])
    }

    private func loadBeatsPage(_ page: Int, accumulated: [Beat]) {
        beatsRequest = service.beats(page: page)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self, case .failure(let error) = completion else { return }
                self.beatsLoading = false
                self.beatsError = (error as? RequestError)?.errorString ?? error.localizedDescription
            } receiveValue: { [weak self] response in
                guard let self else { return }
                let all = accumulated + response.beats
                // 20 pages is 1,000 beats — far past anything real, and a stop if the server loops.
                if response.currentPage < response.lastPage, !response.beats.isEmpty, page < 20 {
                    self.loadBeatsPage(page + 1, accumulated: all)
                } else {
                    self.beatsLoading = false
                    self.beats = all
                        .filter(\.isActive)
                        .sorted { $0.name.lowercased() < $1.name.lowercased() }
                }
            }
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

    /// Switching beats unticks the picks from beats left out, so that waits for a yes.
    func setBeats(_ ids: Set<Int>) {
        guard ids != selectedBeats else { return }
        if picks.droppedBy(ids).isEmpty {
            applyBeats(ids)
        } else {
            pendingBeats = ids
        }
    }

    func confirmBeats() {
        guard let ids = pendingBeats else { return }
        pendingBeats = nil
        applyBeats(ids)
    }

    func keepBeats() {
        pendingBeats = nil
    }

    private func applyBeats(_ ids: Set<Int>) {
        selectedOrders.subtract(picks.droppedBy(ids).map(\.orderId))
        selectedBeats = ids
        loadOrders()
    }

    /// New beats mean a new order list; picks that are still in it, and still free, stay picked.
    func loadOrders() {
        ordersRequest?.cancel()
        guard !selectedBeats.isEmpty else {
            orders = []
            selectedOrders = []
            ordersLoading = false
            ordersError = nil
            return
        }
        ordersLoading = true
        ordersError = nil

        ordersRequest = service.beatOrders(beatIds: selectedBeats)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self, case .failure(let error) = completion else { return }
                self.ordersLoading = false
                self.ordersError = (error as? RequestError)?.errorString ?? error.localizedDescription
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.ordersLoading = false
                guard response.status else {
                    self.ordersError = response.message.isEmptyString ? "Something went wrong. Try again." : response.message
                    return
                }
                self.orders = response.data?.orders ?? []
                let openIds = Set(self.open.map(\.orderId))
                self.selectedOrders = self.selectedOrders.intersection(openIds)
            }
    }

    func toggleOrder(_ order: BeatOrder) {
        guard !order.isAssigned else { return }
        if selectedOrders.contains(order.orderId) {
            selectedOrders.remove(order.orderId)
        } else {
            selectedOrders.insert(order.orderId)
        }
    }

    /// Selects every open order that matches the search, or clears them if all already are.
    func toggleAllShown() {
        let ids = Set(shown.filter { !$0.isAssigned }.map(\.orderId))
        if selectedOrders.isSuperset(of: ids) {
            selectedOrders.subtract(ids)
        } else {
            selectedOrders.formUnion(ids)
        }
    }

    func setEmployee(_ person: PersonOption) {
        employee = person
    }

    /// Checks the form, then shows what is about to be created; nothing is sent until that's confirmed.
    func askCreate() {
        guard !isSaving else { return }
        if selectedOrders.isEmpty {
            error = "Pick at least one order."
        } else if employee == nil {
            error = "Choose who will collect these bills."
        } else {
            confirmError = nil
            confirming = true
        }
    }

    /// Closing is ignored while saving; the server's answer decides what happens next.
    func dismissCreate() {
        guard !isSaving else { return }
        confirming = false
        confirmError = nil
    }

    func create() {
        guard !isSaving, confirming, let employee, !selectedOrders.isEmpty else { return }
        isSaving = true
        confirmError = nil

        service.createBillRegister(
            beatIds: Set(picks.picked.map(\.beatId)),
            orderIds: selectedOrders,
            assignedTo: employee.id
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self, case .failure(let error) = completion else { return }
            self.isSaving = false
            self.confirmError = (error as? RequestError)?.errorString ?? error.localizedDescription
            // A server that answered may know the list is stale; no connection says nothing.
            if let requestError = error as? RequestError, !Self.isOffline(requestError) {
                self.loadOrders()
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isSaving = false
            if response.billRegisterId > 0 {
                NotificationCenter.default.post(name: .billRegisterChanged, object: nil)
                self.confirming = false
                self.createdId = response.billRegisterId
            } else {
                self.confirmError = response.message.isEmptyString
                    ? "Something went wrong. Try again." : response.message
                // The server refused, so the list may be stale (say, a bill went in another register
                // meanwhile): reload it, and the summary drops whatever is taken.
                self.loadOrders()
            }
        }
        .store(in: &cancellables)
    }

    private static func isOffline(_ error: RequestError) -> Bool {
        if case .noInternet = error { return true }
        if case .invalidURL = error { return true }
        return false
    }
}

struct BillRegisterCreateScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BillRegisterCreateViewModel()
    @State private var showBeats = false
    @State private var showEmployee = false
    /// Where back or home was headed when picks would be lost; asked about before going.
    @State private var leaving: (() -> Void)?

    var onHome: () -> Void
    /// Android's rider app has no order screen to open, so this stays nil there and the "View
    /// order" chips are hidden.
    var onOpenOrder: ((String) -> Void)?

    var body: some View {
        if let id = viewModel.createdId {
            // Android replaces this screen with the new register's detail; back then goes to the list.
            BillRegisterDetailScreen(registerId: id, onHome: onHome, onOpenOrder: onOpenOrder)
        } else {
            form
        }
    }

    private var form: some View {
        VStack(spacing: 0) {
            SellersAppBar(
                title: "New Bill Register",
                onBack: { leave(dismiss.callAsFunction) },
                onHome: { leave(onHome) },
                onRefresh: nil
            )

            ScrollView {
                LazyVStack(spacing: 10) {
                    pickers
                    orders
                }
                .padding(12)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(CcColors.page.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .overlay { dialogs }
        .navigationBarHidden(true)
        .sheet(isPresented: $showBeats) {
            BillBeatPickerSheet(
                beats: viewModel.beats,
                selected: viewModel.selectedBeats,
                isLoading: viewModel.beatsLoading,
                onRetry: { viewModel.loadBeats() },
                onApply: { viewModel.setBeats($0) }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func leave(_ go: @escaping () -> Void) {
        if viewModel.guardsLeaving { leaving = go } else { go() }
    }

    private var pickers: some View {
        BillSection(title: "Beats and collector", systemImage: "map") {
            BillPickerField(
                label: "Beats *",
                value: beatsValue,
                systemImage: "map",
                error: viewModel.beatsError,
                isPlaceholder: selectedBeatNames.isEmpty
            ) { showBeats = true }
            BillPickerField(
                label: "Assign to *",
                value: viewModel.employee?.nameWithRole ?? "Choose an employee",
                systemImage: "person.fill",
                isPlaceholder: viewModel.employee == nil
            ) { showEmployee = true }
        }
    }

    private var selectedBeatNames: [String] {
        viewModel.beats.filter { viewModel.selectedBeats.contains($0.id) }.map(\.name)
    }

    private var beatsValue: String {
        let names = selectedBeatNames
        switch names.count {
        case 0: return "Choose beats"
        case 1: return names[0]
        default: return "\(names.count) beats · \(names.joined(separator: ", "))"
        }
    }

    @ViewBuilder
    private var orders: some View {
        if viewModel.selectedBeats.isEmpty {
            BillEmptyState(
                title: "Pick beats first",
                message: "Delivered orders with payment still pending in those beats will show here.",
                systemImage: "map"
            )
        } else if viewModel.ordersLoading {
            BillLoadingBlock()
        } else if let error = viewModel.ordersError {
            BillErrorState(message: error) { viewModel.loadOrders() }
        } else if viewModel.orders.isEmpty {
            BillEmptyState(
                title: "No pending bills",
                message: "Every delivered order in these beats is paid.",
                systemImage: "doc.text"
            )
        } else {
            ordersHeader
            ForEach(viewModel.shown) { order in
                BillBeatOrderRow(
                    order: order,
                    selected: viewModel.selectedOrders.contains(order.orderId),
                    showBeat: viewModel.selectedBeats.count > 1,
                    onView: onOpenOrder.flatMap { open in order.orderNo.isEmpty ? nil : { open(order.orderNo) } },
                    onToggle: { viewModel.toggleOrder(order) }
                )
            }
            if viewModel.shown.isEmpty {
                Text("No order matches \u{201C}\(viewModel.query)\u{201D}.")
                    .font(.system(size: 14))
                    .foregroundStyle(CcColors.textMuted)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var ordersHeader: some View {
        let open = viewModel.open
        let assigned = viewModel.orders.count - open.count
        let openShown = viewModel.shown.filter { !$0.isAssigned }
        let all = !openShown.isEmpty && viewModel.selectedOrders.isSuperset(of: openShown.map(\.orderId))
        let searching = !viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(open.count) pending bill\(open.count == 1 ? "" : "s") · \(CashFormat.rupees(open.reduce(0) { $0 + $1.pendingAmount }))"
                 + (assigned > 0 ? " · \(assigned) already in a register" : ""))
                .font(.system(size: 12.5))
                .foregroundStyle(CcColors.textMuted)
                .padding(.horizontal, 4)
            BillSearchField(placeholder: "Search shop, seller or order no.", text: $viewModel.query)
            if !openShown.isEmpty {
                Button { viewModel.toggleAllShown() } label: {
                    HStack(spacing: 0) {
                        BillCheckbox(isChecked: all)
                        Text(all ? "Unselect all" : "Select all \(openShown.count)" + (searching ? " shown" : ""))
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(CcColors.text)
                        Spacer(minLength: 0)
                    }
                    .padding(.trailing, 8)
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bottomBar: some View {
        let count = viewModel.selectedOrders.count
        return BillBottomBar {
            BillBarSummary(
                label: "\(count) order\(count == 1 ? "" : "s") selected" + (viewModel.employee.map { " · for \($0.name)" } ?? ""),
                value: CashFormat.rupees(viewModel.selectedTotal)
            )
        } content: {
            BillPrimaryButton(
                title: "Create & Assign",
                systemImage: "checkmark",
                isEnabled: count > 0,
                isLoading: viewModel.isSaving
            ) { viewModel.askCreate() }
        }
    }

    @ViewBuilder
    private var dialogs: some View {
        if showEmployee {
            BillPersonPicker(
                state: viewModel.people,
                selectedId: viewModel.employee?.id,
                onRetry: { viewModel.loadPeople() },
                onPick: { viewModel.setEmployee($0); showEmployee = false },
                onDismiss: { showEmployee = false }
            )
        } else if viewModel.confirming {
            BillCreateConfirmDialog(viewModel: viewModel)
        } else if let ids = viewModel.pendingBeats {
            changeBeatsDialog(ids)
        } else if let go = leaving {
            BillConfirmDialog(
                systemImage: "trash",
                title: "Discard this register?",
                message: "You've picked \(billCount(viewModel.selectedOrders.count)) (\(CashFormat.rupees(viewModel.selectedTotal)))"
                    + (viewModel.employee.map { " for \($0.name)" } ?? "") + ". Leaving now throws the picks away.",
                confirmTitle: "Discard",
                confirmColor: CcColors.err,
                dismissTitle: "Keep editing",
                onConfirm: { leaving = nil; go() },
                onDismiss: { leaving = nil }
            )
        } else if let error = viewModel.error {
            BillErrorDialog(message: error) { viewModel.error = nil }
        }
    }

    private func changeBeatsDialog(_ ids: Set<Int>) -> some View {
        let dropped = viewModel.picks.droppedBy(ids)
        let gone = viewModel.beats.filter { viewModel.selectedBeats.contains($0.id) && !ids.contains($0.id) }.map(\.name)
        return BillConfirmDialog(
            systemImage: "map",
            title: "Change beats?",
            message: "\(billCount(dropped.count)) you picked (\(CashFormat.rupees(dropped.reduce(0) { $0 + $1.pendingAmount }))) "
                + (gone.isEmpty ? "" : "from \(gone.joined(separator: ", ")) ") + "will be unticked.",
            confirmTitle: "Change beats",
            dismissTitle: "Keep beats",
            onConfirm: { viewModel.confirmBeats() },
            onDismiss: { viewModel.keepBeats() }
        )
    }
}

/// The last look before a register is made: who collects, from which beats, how many bills and how
/// much. It stays up while saving, and a server refusal shows here with the picks intact.
private struct BillCreateConfirmDialog: View {
    @ObservedObject var viewModel: BillRegisterCreateViewModel

    var body: some View {
        let picked = viewModel.picks.picked
        let total = picked.reduce(0) { $0 + $1.pendingAmount }
        let who = viewModel.employee
        let names = beatNames(picked)

        CcDialog(busy: viewModel.isSaving, error: viewModel.confirmError, onDismiss: { viewModel.dismissCreate() }) {
            HStack(spacing: 12) {
                BillIconDisc(systemImage: "person.text.rectangle", size: 44)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Create this register?")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(CcColors.text)
                    Text("Check it before it's assigned")
                        .font(.system(size: 12))
                        .foregroundStyle(CcColors.textMuted)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                summaryLine("person.fill", "Assign to", who?.nameWithRole ?? "—")
                summaryLine("map.fill", names.count == 1 ? "Beat" : "Beats", names.isEmpty ? "—" : names.joined(separator: ", "))
                summaryLine("doc.text.fill", "Bills", billCount(picked.count))
                HStack {
                    Text("To collect")
                        .font(.system(size: 13))
                        .foregroundStyle(CcColors.textMuted)
                    Spacer()
                    // Rolls when a refused create reloads the list and drops a bill someone else took.
                    Text(CashFormat.rupees(total))
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(CcColors.primary)
                        .contentTransition(.numericText(value: total))
                        .animation(.easeOut, value: total)
                }
                .padding(.top, 2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CcColors.container, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            BillLinesPreview(lines: picked.map { ($0.sellerShopName ?? $0.sellerName ?? $0.orderNo, $0.pendingAmount) })
            Text("\(who?.name ?? "They") will find it in their Bill Register and collect these bills. It can still be "
                 + "reassigned, have bills removed or be cancelled later.")
                .font(.system(size: 12.5))
                .foregroundStyle(CcColors.textMuted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        } buttons: {
            BillWeightedRow {
                BillSecondaryButton(title: "Back", color: CcColors.textMuted, isEnabled: !viewModel.isSaving) {
                    viewModel.dismissCreate()
                }
                BillPrimaryButton(
                    title: "Create & assign",
                    systemImage: "checkmark",
                    isEnabled: !picked.isEmpty && who != nil,
                    isLoading: viewModel.isSaving
                ) { viewModel.create() }
                .billWeight(1.4)
            }
        }
    }

    /// The picked bills' beats by name, in the beat list's order; the bills' own names if the list
    /// hasn't got them.
    private func beatNames(_ picked: [BeatOrder]) -> [String] {
        let ids = Set(picked.map(\.beatId))
        let names = viewModel.beats.filter { ids.contains($0.id) }.map(\.name)
        if !names.isEmpty { return names }
        var seen = Set<String>()
        return picked.compactMap(\.beatName).filter { seen.insert($0).inserted }
    }

    private func summaryLine(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(CcColors.primary)
                .frame(width: 16)
                .padding(.top, 1)
                .padding(.trailing, 8)
            Text(label)
                .font(.system(size: 12.5))
                .foregroundStyle(CcColors.textMuted)
                .frame(width: 78, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CcColors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Android `BeatOrderRow`: a bill to pick for a new register. One already in another register is
/// greyed out, can't be ticked, and says which register and whose.
private struct BillBeatOrderRow: View {
    let order: BeatOrder
    let selected: Bool
    let showBeat: Bool
    let onView: (() -> Void)?
    let onToggle: () -> Void

    private var locked: Bool { order.isAssigned }

    private var subtitle: String {
        [order.orderNo.isEmpty ? nil : order.orderNo, order.deliveryDate.map { "Delivered \($0)" }, order.staffName]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 0) {
            BillCheckbox(isChecked: selected, isEnabled: !locked)
            VStack(alignment: .leading, spacing: 2) {
                Text(order.sellerShopName ?? order.sellerName ?? "—")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(locked ? CcColors.textMuted : CcColors.text)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(CcColors.textMuted)
                }
                if showBeat, let beat = order.beatName {
                    Text(beat)
                        .font(.system(size: 11.5))
                        .foregroundStyle(CcColors.info)
                }
                if locked {
                    CcPill(
                        text: "In register #\(order.billRegisterId.map(String.init) ?? "?") · \(order.billRegisterAssignedToName ?? "assigned")",
                        tone: .violet
                    )
                }
                if let onView {
                    BillViewOrderChip(action: onView)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(CashFormat.rupees(order.pendingAmount))
                .font(.system(size: 14.5, weight: .heavy))
                .foregroundStyle(locked ? CcColors.textFaint : CcColors.text)
                .padding(.leading, 8)
        }
        .padding(.leading, 2)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .background(
            locked ? CcColors.track : selected ? CcColors.container : .white,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selected ? CcColors.primary.opacity(0.6) : CcColors.border, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture { if !locked { onToggle() } }
        .animation(.easeInOut(duration: 0.2), value: selected)
    }
}

/// Android `BeatPickerSheet`: tick beats (searchable), then apply them all at once. Nothing changes
/// on the page until the button is tapped.
private struct BillBeatPickerSheet: View {
    let beats: [Beat]
    let selected: Set<Int>
    let isLoading: Bool
    let onRetry: () -> Void
    let onApply: (Set<Int>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picked: Set<Int> = []
    @State private var query = ""

    private var shown: [Beat] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return beats.filter { q.isEmpty || $0.name.lowercased().contains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Choose beats")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(CcColors.text)
                    Text(picked.isEmpty ? "None selected" : "\(picked.count) selected")
                        .font(.system(size: 12.5))
                        .foregroundStyle(CcColors.textMuted)
                }
                Spacer()
                if !picked.isEmpty {
                    Button("Clear") { picked = [] }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(CcColors.primary)
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                }
            }
            BillSearchField(placeholder: "Search beats", text: $query, showsClear: false)
            list
            BillPrimaryButton(
                title: picked.isEmpty ? "Done" : "Show orders from \(picked.count) beat\(picked.count == 1 ? "" : "s")",
                systemImage: "checkmark"
            ) {
                onApply(picked)
                dismiss()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .background(Color.white.ignoresSafeArea())
        .onAppear { picked = selected }
    }

    @ViewBuilder
    private var list: some View {
        if isLoading {
            BillLoadingBlock()
            Spacer(minLength: 0)
        } else if beats.isEmpty {
            BillErrorState(message: "Couldn't load the beats.", onRetry: onRetry)
            Spacer(minLength: 0)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(shown) { beat in
                        row(beat)
                    }
                    if shown.isEmpty {
                        Text("No beat matches \u{201C}\(query)\u{201D}.")
                            .font(.system(size: 14))
                            .foregroundStyle(CcColors.textMuted)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func row(_ beat: Beat) -> some View {
        let on = picked.contains(beat.id)
        return Button {
            if on { picked.remove(beat.id) } else { picked.insert(beat.id) }
        } label: {
            HStack(spacing: 0) {
                BillCheckbox(isChecked: on)
                Text(beat.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CcColors.text)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(on ? CcColors.container : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
