//
//  BillRegisterDetailScreen.swift
//  TrudataRider
//
//  Android `BillDetailScreen`. One register with its orders. A manager clears orders (the register
//  closes once every order is cleared) or hands the register to someone else while it is pending;
//  the person it is assigned to only reads it and calls the shops. Bills the office removed are kept
//  as history under their own folded section, and a cancelled register says who called it off and
//  why. Cancelling a register or removing its bills is done from the TruDataa app, not here.
//

import SwiftUI
import Combine

/// What the confirm dialog is about to do.
enum BillAction: Equatable {
    case clearSelected
    case clearAll
    case reassign(PersonOption)
}

final class BillRegisterDetailViewModel: ObservableObject {

    @Published private(set) var register: BillRegister?
    @Published private(set) var isLoading = true
    @Published private(set) var loadError: String?
    /// Register orders (by `orderId`) ticked for clearing.
    @Published private(set) var selected: Set<Int> = []
    @Published private(set) var people = PeopleState()
    @Published var confirm: BillAction?
    @Published private(set) var isWorking = false
    /// A finished action, shown once as a snackbar.
    @Published var message: String?
    /// A failed action, or a failed reload with the register already up.
    @Published var error: String?

    let access = CashAccess.current

    private let registerId: Int
    private let service = CashCollectionServiceManager()
    private var loadRequest: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    init(registerId: Int) {
        self.registerId = registerId
    }

    /// Managers act on a register while it is pending; a cleared or cancelled one is history.
    var canAct: Bool { access.canManageBills && register?.isPending == true }

    /// Everything still counted in the register, pending first so what is left to collect is on top.
    var activeOrders: [RegisterOrder] {
        let active = register?.orders.filter { !$0.isRemoved } ?? []
        return active.filter(\.isPending) + active.filter { !$0.isPending }
    }

    /// Bills taken out of the register by the office; history only.
    var removedOrders: [RegisterOrder] {
        register?.orders.filter(\.isRemoved) ?? []
    }

    var pendingOrders: [RegisterOrder] {
        register?.orders.filter(\.isPending) ?? []
    }

    var selectedTotal: Double {
        (register?.orders ?? []).filter { selected.contains($0.orderId) }.reduce(0) { $0 + $1.currentPending }
    }

    func start() {
        guard register == nil, loadRequest == nil else { return }
        load()
        if access.canManageBills { loadPeople() }
    }

    func load() {
        isLoading = true
        loadError = nil
        loadRequest = service.billRegisterDetail(id: registerId)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                self.loadRequest = nil
                if case .failure(let error) = completion {
                    self.loadFailed((error as? RequestError)?.errorString ?? error.localizedDescription)
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                guard response.status, let register = response.data else {
                    self.loadFailed(response.message.isEmptyString ? "Couldn't load this register." : response.message)
                    return
                }
                self.register = register
                // Keep ticks on bills that are still pending; drop any cleared or removed meanwhile.
                let pendingIds = Set(register.orders.filter(\.isPending).map(\.orderId))
                self.selected = self.selected.intersection(pendingIds)
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

    func toggle(_ order: RegisterOrder) {
        guard order.isPending, canAct else { return }
        if selected.contains(order.orderId) {
            selected.remove(order.orderId)
        } else {
            selected.insert(order.orderId)
        }
    }

    /// Ticks every pending order, or none if they all already are.
    func toggleAll() {
        let pending = Set(pendingOrders.map(\.orderId))
        selected = selected.isSuperset(of: pending) ? [] : pending
    }

    func ask(_ action: BillAction?) {
        confirm = action
    }

    func runConfirmed() {
        guard let action = confirm, !isWorking else { return }
        let picked = selected
        isWorking = true
        confirm = nil

        let call: AnyPublisher<StatusMessageResponse, Error>
        let done: String
        switch action {
        case .clearAll:
            call = service.clearBillRegister(id: registerId, orderIds: nil)
            done = "Register cleared"
        case .clearSelected:
            call = service.clearBillRegister(id: registerId, orderIds: picked)
            done = "\(picked.count) order\(picked.count == 1 ? "" : "s") cleared"
        case .reassign(let person):
            call = service.reassignBillRegister(id: registerId, assignedTo: person.id)
            done = "Reassigned to \(person.name)"
        }

        call
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self, case .failure(let error) = completion else { return }
                self.isWorking = false
                self.error = (error as? RequestError)?.errorString ?? error.localizedDescription
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isWorking = false
                guard response.status else {
                    self.error = response.message.isEmptyString ? "Something went wrong. Try again." : response.message
                    return
                }
                self.selected = []
                self.message = done
                NotificationCenter.default.post(name: .billRegisterChanged, object: nil)
                self.load()
            }
            .store(in: &cancellables)
    }

    private func loadFailed(_ message: String) {
        // With the register already up, a failed reload is a pop-up rather than a blank page.
        if register == nil { loadError = message } else { error = message }
    }
}

struct BillRegisterDetailScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BillRegisterDetailViewModel
    @State private var showReassign = false
    // Removed bills are history, so they start folded.
    @State private var showRemoved = false

    var onHome: () -> Void
    /// Opens the order's detail by order number. Android's rider app passes none, so the "View
    /// order" chips stay hidden here; a host with an order screen can pass one.
    var onOpenOrder: ((String) -> Void)?

    init(registerId: Int, onHome: @escaping () -> Void, onOpenOrder: ((String) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: BillRegisterDetailViewModel(registerId: registerId))
        self.onHome = onHome
        self.onOpenOrder = onOpenOrder
    }

    var body: some View {
        VStack(spacing: 0) {
            SellersAppBar(
                title: viewModel.register.map { "Register #\($0.id)" } ?? "Bill Register",
                onBack: { dismiss() },
                onHome: onHome,
                onRefresh: { viewModel.load() }
            )

            ScrollView {
                LazyVStack(spacing: 10) {
                    content
                }
                .padding(12)
                .animation(.easeInOut(duration: 0.25), value: viewModel.register)
            }
        }
        .background(CcColors.page.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Slides away once the register is cleared or cancelled: there is nothing left to act on.
            if viewModel.canAct {
                actionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.canAct)
        .billSnackbar(message: $viewModel.message)
        .overlay { dialogs }
        .navigationBarHidden(true)
        .onAppear { viewModel.start() }
    }

    @ViewBuilder
    private var content: some View {
        if let register = viewModel.register {
            let active = viewModel.activeOrders
            let removed = viewModel.removedOrders

            BillRegisterHero(register: register)
            if register.isCancelled {
                BillCancelledNote(register: register)
            }
            ordersHeader(active: active)
            if active.isEmpty {
                Text(removed.isEmpty ? "No orders in this register." : "Every bill in this register was removed.")
                    .font(.system(size: 13))
                    .foregroundStyle(CcColors.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
            ForEach(active) { order in
                orderRow(order, selected: viewModel.selected.contains(order.orderId))
            }
            if !removed.isEmpty {
                BillRemovedHeader(
                    count: removed.count,
                    amount: removed.reduce(0) { $0 + $1.currentPending },
                    open: showRemoved,
                    onToggle: { withAnimation(.easeInOut(duration: 0.25)) { showRemoved.toggle() } }
                )
                if showRemoved {
                    ForEach(removed) { order in
                        orderRow(order, selected: false)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        } else if viewModel.isLoading {
            BillLoadingBlock()
        } else {
            BillErrorState(message: viewModel.loadError ?? "Couldn't load this register.") { viewModel.load() }
        }
    }

    private func ordersHeader(active: [RegisterOrder]) -> some View {
        let pendingCount = active.filter(\.isPending).count
        return HStack(spacing: 0) {
            Text("Orders (\(active.count))")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(CcColors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            if viewModel.canAct && pendingCount > 0 {
                Button(viewModel.selected.count == pendingCount ? "Unselect all" : "Select all pending") {
                    viewModel.toggleAll()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CcColors.primary)
                .padding(.horizontal, 12)
                .frame(height: 40)
            }
        }
        .padding(.leading, 4)
        .frame(minHeight: 40)
    }

    private func orderRow(_ order: RegisterOrder, selected: Bool) -> some View {
        BillRegisterOrderRow(
            order: order,
            selectable: viewModel.canAct,
            selected: selected,
            onView: onOpenOrder.flatMap { open in order.orderNo.isEmpty ? nil : { open(order.orderNo) } },
            onToggle: { viewModel.toggle(order) }
        )
    }

    private var actionBar: some View {
        BillBottomBar {
            if !viewModel.selected.isEmpty {
                Text("\(viewModel.selected.count) selected · \(CashFormat.rupees(viewModel.selectedTotal))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CcColors.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } content: {
            BillWeightedRow {
                BillSecondaryButton(
                    title: "Reassign",
                    systemImage: "arrow.left.arrow.right",
                    isEnabled: !viewModel.isWorking
                ) { showReassign = true }
                .billWeight(0.9)
                BillPrimaryButton(
                    title: viewModel.selected.isEmpty ? "Clear All" : "Clear \(viewModel.selected.count)",
                    systemImage: "checkmark.circle",
                    isLoading: viewModel.isWorking
                ) {
                    viewModel.ask(viewModel.selected.isEmpty ? .clearAll : .clearSelected)
                }
                .billWeight(1.3)
            }
        }
    }

    @ViewBuilder
    private var dialogs: some View {
        if showReassign, let register = viewModel.register {
            BillPersonPicker(
                state: viewModel.people,
                selectedId: register.assignedToId,
                onRetry: { viewModel.loadPeople() },
                onPick: { person in
                    showReassign = false
                    if person.id != register.assignedToId { viewModel.ask(.reassign(person)) }
                },
                onDismiss: { showReassign = false }
            )
        } else if let action = viewModel.confirm {
            confirmDialog(action)
        } else if let error = viewModel.error {
            BillErrorDialog(message: error) { viewModel.error = nil }
        }
    }

    private func confirmDialog(_ action: BillAction) -> some View {
        let pending = viewModel.pendingOrders
        let count = viewModel.selected.count
        let title: String
        let message: String
        switch action {
        case .clearAll:
            title = "Clear the whole register?"
            message = "All \(pending.count) pending orders (\(CashFormat.rupees(pending.reduce(0) { $0 + $1.currentPending }))) "
                + "will be marked cleared, and the register closes."
        case .clearSelected:
            title = "Clear \(count) order\(count == 1 ? "" : "s")?"
            message = "They'll be marked cleared. Once every order is cleared the register closes."
        case .reassign(let person):
            title = "Reassign to \(person.name)?"
            message = "\(viewModel.register?.assignedTo ?? "The current employee") will no longer see this register."
        }
        let isReassign: Bool
        if case .reassign = action { isReassign = true } else { isReassign = false }
        return BillConfirmDialog(
            systemImage: isReassign ? "arrow.left.arrow.right" : "checkmark.circle",
            title: title,
            message: message,
            confirmTitle: isReassign ? "Reassign" : "Clear",
            onConfirm: { viewModel.runConfirmed() },
            onDismiss: { viewModel.ask(nil) }
        )
    }
}

/// Android `RegisterHero`. A cancelled register drains from brand green to slate, its amount struck
/// out; removed bills leave the cleared count and get a stat of their own.
private struct BillRegisterHero: View {
    let register: BillRegister

    var body: some View {
        let cancelled = register.isCancelled
        let all = register.orders
        let active = all.filter { !$0.isRemoved }
        let activeCount = all.isEmpty ? register.activeOrders : active.count
        let clearedCount = all.isEmpty ? register.clearedOrders : active.filter(\.isCleared).count
        let removedCount = all.isEmpty ? register.removedOrders : all.count - active.count
        let amount = register.isPending ? register.pendingAmount : register.totalAmount

        BillHero(colors: cancelled ? CcColors.heroMuted : CcColors.heroBrand, glowAlpha: cancelled ? 0.06 : 0.22) {
            HStack {
                BillHeroLabel(text: heroLabel)
                Spacer(minLength: 8)
                BillStatusPill(status: register.status)
            }
            // Rolls to the new figure when bills are removed or cleared.
            Text(CashFormat.rupees(amount))
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.white.opacity(cancelled ? 0.75 : 1))
                .strikethrough(cancelled, color: .white.opacity(0.75))
                .contentTransition(.numericText(value: amount))
                .animation(.easeOut(duration: 0.3), value: amount)
            Text("Assigned to \(register.assignedTo ?? "—")" + (register.assignedBy.map { " · by \($0)" } ?? ""))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            if !register.beatNames.isEmpty {
                Text(register.beatNames.joined(separator: " · "))
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.75))
            }
            BillClearedBar(
                cleared: clearedCount,
                total: activeCount,
                track: .white.opacity(0.18),
                fill: cancelled ? .white.opacity(0.45) : CcColors.glow
            )
            .padding(.top, 8)
            BillWeightedRow(spacing: 8) {
                BillHeroStat(label: "Orders cleared", value: "\(clearedCount) / \(activeCount)")
                BillHeroStat(label: "Total billed", value: CashFormat.rupees(register.totalAmount))
                if removedCount > 0 {
                    BillHeroStat(label: "Removed", value: String(removedCount)).billWeight(0.6)
                }
            }
            .padding(.top, 6)
            if !datesLine.isEmpty {
                Text(datesLine)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 4)
            }
        }
    }

    private var heroLabel: String {
        if register.isCleared { return "Collected" }
        if register.isCancelled { return "Cancelled · was to collect" }
        return "Pending to collect"
    }

    private var datesLine: String {
        var parts: [String] = []
        if let created = register.createdAt { parts.append("Created \(created)") }
        if let cleared = register.clearedAt { parts.append("Cleared \(cleared)") }
        if register.isCancelled, let stamp = billStamp(register.cancelledAt) { parts.append("Cancelled \(stamp)") }
        return parts.joined(separator: " · ")
    }
}

/// Who called the register off, when, why, and what that means for the person collecting.
private struct BillCancelledNote: View {
    let register: BillRegister

    var body: some View {
        let freed = register.orders.filter(\.isCancelled).count
        let who = [register.cancelledBy.map { "By \($0)" }, billStamp(register.cancelledAt)].compactMap { $0 }
        HStack(alignment: .top, spacing: 10) {
            BillIconDisc(systemImage: "nosign", accent: CcColors.err, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text("Register cancelled")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(CcColors.errInk)
                if !who.isEmpty {
                    Text(who.joined(separator: " · "))
                        .font(.system(size: 12))
                        .foregroundStyle(CcColors.textMuted)
                }
                if let reason = register.cancelReason {
                    BillQuote(text: reason, size: 13, color: CcColors.text)
                }
                Text("Nothing left to collect on this register."
                     + (freed > 0 ? " Its \(billCount(freed)) went back to the office." : ""))
                    .font(.system(size: 11.5))
                    .foregroundStyle(CcColors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(CcColors.errBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(CcColors.err.opacity(0.18), lineWidth: 1)
        )
    }
}

/// Opens or folds the bills the office took out of this register.
private struct BillRemovedHeader: View {
    let count: Int
    let amount: Double
    let open: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 17))
                    .foregroundStyle(CcColors.err)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Removed bills (\(count))")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(CcColors.text)
                    Text("\(CashFormat.rupees(amount)) · no need to collect")
                        .font(.system(size: 11.5))
                        .foregroundStyle(CcColors.textMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CcColors.textMuted)
                    .rotationEffect(.degrees(open ? 180 : 0))
                    .animation(.easeInOut(duration: 0.25), value: open)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .accessibilityLabel(open ? "Hide removed bills" : "Show removed bills")
    }
}

/// Android `RegisterOrderRow`: a checkbox while it can be picked, otherwise a mark (cleared tick or
/// removed circle) in its place; without a manager's checkboxes there is no column at all. Removed
/// and cancelled bills read muted; a removed one says who, when and why. The phone button calls the
/// shop.
private struct BillRegisterOrderRow: View {
    let order: RegisterOrder
    let selectable: Bool
    let selected: Bool
    let onView: (() -> Void)?
    let onToggle: () -> Void

    private var canTick: Bool { selectable && order.isPending }
    private var gone: Bool { order.isRemoved || order.isCancelled }

    var body: some View {
        HStack(spacing: 0) {
            if selectable {
                mark
            }
            details
                .frame(maxWidth: .infinity, alignment: .leading)
            amounts
                .padding(.leading, 6)
            BillCallButton(mobile: order.sellerMobile)
        }
        .padding(.leading, selectable ? 2 : 12)
        .padding(.trailing, 4)
        .padding(.vertical, 8)
        .background(fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selected ? CcColors.primary.opacity(0.6) : CcColors.border, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture { if canTick { onToggle() } }
        .animation(.easeInOut(duration: 0.22), value: selected)
    }

    private var fill: Color {
        if selected { return CcColors.container }
        return gone ? CcColors.track : .white
    }

    /// A bill that can't be picked gets a mark where the checkbox would be.
    @ViewBuilder
    private var mark: some View {
        if canTick {
            BillCheckbox(isChecked: selected)
        } else {
            ZStack {
                if order.isCleared {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(CcColors.ok)
                        .accessibilityLabel("Cleared")
                } else if order.isRemoved {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(CcColors.err.opacity(0.7))
                        .accessibilityLabel("Removed")
                }
            }
            .frame(width: 48, height: 48)
        }
    }

    private var subtitle: String {
        let seller = order.sellerShopName == nil ? nil : order.sellerName
        let number = order.orderNo.isEmpty ? nil : order.orderNo
        let delivered = order.deliveryDate.map { "Delivered \($0)" }
        return [seller, number, delivered].compactMap { $0 }.joined(separator: " · ")
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(order.sellerShopName ?? order.sellerName ?? "—")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(gone ? CcColors.textMuted : CcColors.text)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(CcColors.textMuted)
            }
            HStack(spacing: 6) {
                // An order freed by the register's cancel is no one's to collect any more.
                if order.isCancelled {
                    CcPill(text: "Cancelled", tone: .muted)
                } else {
                    BillStatusPill(status: order.paymentStatus)
                }
                if let onView {
                    BillViewOrderChip(action: onView)
                }
            }
            // On its own line so a long beat name wraps instead of being cut.
            if let beat = order.beatName {
                Text(beat)
                    .font(.system(size: 11.5))
                    .foregroundStyle(CcColors.info)
            }
            if order.isRemoved {
                Text(removedLine)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(CcColors.err)
                if let reason = order.removeReason {
                    BillQuote(text: reason)
                }
            }
        }
    }

    private var amounts: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(CashFormat.rupees(order.currentPending))
                .font(.system(size: 14.5, weight: .heavy))
                .foregroundStyle(order.isPending ? CcColors.text : CcColors.textMuted)
                .strikethrough(order.isRemoved)
            // The order's pending payment has moved since it went in the register.
            if order.currentPending != order.pendingAmount {
                Text("was \(CashFormat.rupees(order.pendingAmount))")
                    .font(.system(size: 11))
                    .foregroundStyle(CcColors.textFaint)
            }
        }
    }

    private var removedLine: String {
        let who = "Removed" + (order.removedBy.map { " by \($0)" } ?? "")
        return [who, billStamp(order.removedAt)].compactMap { $0 }.joined(separator: " · ")
    }
}
