//
//  BillRegisterDetailScreen.swift
//  TrudataRider
//
//  One register with its orders. Clearing an order marks its payment collected; the register
//  clears itself once every order in it is cleared. Bills the office removed are kept as history
//  under their own folded section, and a cancelled register says who called it off and why.
//

import SwiftUI
import Combine

final class BillRegisterDetailViewModel: ObservableObject {

    @Published var register: BillRegister?
    @Published var isLoading = false
    @Published var loadError: String?
    @Published var actionError: String?
    @Published var successMessage: String?
    @Published var selectedOrders: Set<Int> = []
    @Published var isClearing = false

    let access = CashAccess.current

    private let registerId: Int
    private let service = CashCollectionServiceManager()
    private var cancellables = Set<AnyCancellable>()

    init(registerId: Int) {
        self.registerId = registerId
    }

    /// Still to collect: the only orders that can be cleared.
    var pendingOrders: [RegisterOrder] {
        register?.orders.filter(\.isPending) ?? []
    }

    /// Everything still counted in the register, pending first so what is left to collect is on top.
    var activeOrders: [RegisterOrder] {
        let active = register?.orders.filter { !$0.isRemoved } ?? []
        return active.filter(\.isPending) + active.filter { !$0.isPending }
    }

    /// Bills taken out of the register by the office; history only.
    var removedOrders: [RegisterOrder] {
        register?.orders.filter(\.isRemoved) ?? []
    }

    /// As on Android, managers act on a register while it is pending; a cleared or cancelled one is
    /// history. The rider it is assigned to only reads it. Cancelling a register or removing its
    /// bills is done from the TruDataa app, not here.
    var canClear: Bool {
        guard let register else { return false }
        return access.canManageBills && register.isPending && !pendingOrders.isEmpty
    }

    func load() {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil

        service.billRegisterDetail(id: registerId)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.loadError = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if let register = response.data {
                    self.register = register
                    // Keep ticks on bills that are still pending; drop any the office removed meanwhile.
                    let pendingIds = Set(register.orders.filter(\.isPending).map(\.orderId))
                    self.selectedOrders = self.selectedOrders.intersection(pendingIds)
                } else {
                    self.loadError = response.message.isEmptyString
                        ? "This register could not be loaded." : response.message
                }
            }
            .store(in: &cancellables)
    }

    func toggle(_ order: RegisterOrder) {
        guard order.isPending, canClear else { return }
        if selectedOrders.contains(order.orderId) {
            selectedOrders.remove(order.orderId)
        } else {
            selectedOrders.insert(order.orderId)
        }
    }

    /// Clears the picked orders, or every pending one when nothing is picked.
    func clear() {
        guard !isClearing else { return }
        isClearing = true
        actionError = nil

        service.clearBillRegister(id: registerId, orderIds: selectedOrders.isEmpty ? nil : selectedOrders)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isClearing = false
                if case .failure(let error) = completion {
                    self.actionError = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isClearing = false
                if response.status {
                    self.successMessage = response.message.isEmptyString
                        ? "Payment marked collected." : response.message
                    self.load()
                } else {
                    self.actionError = response.message.isEmptyString
                        ? "The orders could not be cleared." : response.message
                }
            }
            .store(in: &cancellables)
    }
}

struct BillRegisterDetailScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BillRegisterDetailViewModel
    // Removed bills are history, so they start folded.
    @State private var showRemoved = false

    var onHome: () -> Void

    init(registerId: Int, onHome: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: BillRegisterDetailViewModel(registerId: registerId))
        self.onHome = onHome
    }

    var body: some View {
        ZStack {
            CcColors.page.ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Register",
                    onBack: { dismiss() },
                    onHome: onHome,
                    onRefresh: { viewModel.load() }
                )

                ScrollView {
                    VStack(spacing: 10) {
                        if viewModel.isLoading && viewModel.register == nil {
                            CcLoadingBlock()
                        } else if let loadError = viewModel.loadError, viewModel.register == nil {
                            CcErrorState(message: loadError) { viewModel.load() }
                        } else if let register = viewModel.register {
                            BillRegisterHero(register: register)
                            if register.isCancelled {
                                BillCancelledNote(register: register)
                            }
                            ordersSection
                            removedSection
                        }

                        if viewModel.canClear {
                            Color.clear.frame(height: 80)
                        }
                    }
                    .padding(12)
                }
            }

            if viewModel.canClear {
                // Slides away once the register is cleared or cancelled: nothing is left to act on.
                VStack {
                    Spacer()
                    CcBottomActionBar {
                        CcPrimaryButton(
                            title: viewModel.selectedOrders.isEmpty
                                ? "Clear all pending"
                                : "Clear \(viewModel.selectedOrders.count) selected",
                            systemImage: "checkmark.circle",
                            isLoading: viewModel.isClearing
                        ) {
                            viewModel.clear()
                        }
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.canClear)
        .navigationBarHidden(true)
        .onAppear {
            if viewModel.register == nil {
                viewModel.load()
            }
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

    private var ordersSection: some View {
        let active = viewModel.activeOrders
        return CcSection(title: "Orders (\(active.count))", systemImage: "doc.text") {
            if active.isEmpty {
                Text(viewModel.removedOrders.isEmpty
                     ? "No orders in this register."
                     : "Every bill in this register was removed.")
                    .font(.system(size: 13))
                    .foregroundStyle(CcColors.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 8) {
                    ForEach(active) { order in
                        RegisterOrderRow(
                            order: order,
                            isSelected: viewModel.selectedOrders.contains(order.orderId),
                            isSelectable: viewModel.canClear,
                            onTap: { viewModel.toggle(order) }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var removedSection: some View {
        let removed = viewModel.removedOrders
        if !removed.isEmpty {
            VStack(spacing: 8) {
                BillRemovedHeader(
                    count: removed.count,
                    amount: removed.reduce(0) { $0 + $1.currentPending },
                    open: showRemoved,
                    onToggle: { withAnimation(.easeInOut(duration: 0.25)) { showRemoved.toggle() } }
                )
                if showRemoved {
                    ForEach(removed) { order in
                        RegisterOrderRow(
                            order: order,
                            isSelected: false,
                            isSelectable: viewModel.canClear,
                            onTap: {}
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
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

        CcHero(colors: cancelled ? CcColors.heroMuted : CcColors.heroBrand) {
            HStack {
                CcHeroLabel(text: heroLabel)
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
            .padding(.top, 4)
            HStack(spacing: 12) {
                CcHeroStat(label: "Orders cleared", value: "\(clearedCount) / \(activeCount)")
                CcHeroStat(label: "Total billed", value: CashFormat.rupees(register.totalAmount))
                if removedCount > 0 {
                    CcHeroStat(label: "Removed", value: String(removedCount))
                        .frame(maxWidth: 80)
                }
            }
            if !datesLine.isEmpty {
                Text(datesLine)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.7))
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
        if let created = register.createdAt, !created.isEmptyString { parts.append("Created \(created)") }
        if let cleared = register.clearedAt, !cleared.isEmptyString { parts.append("Cleared \(cleared)") }
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
            CcIconDisc(systemImage: "nosign", accent: CcColors.err, size: 34)
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
            Spacer(minLength: 0)
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
                VStack(alignment: .leading, spacing: 1) {
                    Text("Removed bills (\(count))")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(CcColors.text)
                    Text("\(CashFormat.rupees(amount)) · no need to collect")
                        .font(.system(size: 11.5))
                        .foregroundStyle(CcColors.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundStyle(CcColors.textMuted)
                    .rotationEffect(.degrees(open ? 180 : 0))
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

/// Android `RegisterOrderRow`: a tick box while it can be picked, otherwise a mark (cleared tick or
/// removed circle). Removed and cancelled bills read muted; a removed one says who, when and why.
private struct RegisterOrderRow: View {
    let order: RegisterOrder
    let isSelected: Bool
    let isSelectable: Bool
    var onTap: () -> Void

    private var canTick: Bool { isSelectable && order.isPending }
    private var gone: Bool { order.isRemoved || order.isCancelled }

    var body: some View {
        Button(action: { if canTick { onTap() } }) {
            HStack(spacing: 10) {
                if isSelectable {
                    mark.frame(width: 22)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(order.shopLabel)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(gone ? CcColors.textMuted : CcColors.text)
                        .lineLimit(1)
                    Text("Order \(order.orderNo)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(CcColors.textMuted)
                    // An order freed by the register's cancel is no one's to collect any more.
                    if order.isCancelled {
                        CcPill(text: "Cancelled", tone: .muted)
                    } else {
                        BillStatusPill(status: order.paymentStatus)
                    }
                    if let beat = order.beatName, !beat.isEmptyString {
                        Text(beat)
                            .font(.system(size: 11))
                            .foregroundStyle(CcColors.textFaint)
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

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(CashFormat.rupees(order.currentPending))
                        .font(.system(size: 14, weight: .bold))
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
            .padding(10)
            .background(fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? CcColors.primary.opacity(0.6) : Color.clear, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.22), value: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(!canTick)
    }

    private var fill: Color {
        if isSelected { return CcColors.container }
        return gone ? CcColors.track : CcColors.page
    }

    /// A bill that can't be picked gets a mark where the tick box would be.
    @ViewBuilder
    private var mark: some View {
        if canTick {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundStyle(isSelected ? CcColors.primary : CcColors.textFaint)
        } else if order.isCleared {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(CcColors.ok)
                .accessibilityLabel("Cleared")
        } else if order.isRemoved {
            Image(systemName: "minus.circle")
                .font(.system(size: 18))
                .foregroundStyle(CcColors.err.opacity(0.7))
                .accessibilityLabel("Removed")
        }
    }

    private var removedLine: String {
        let who = "Removed" + (order.removedBy.map { " by \($0)" } ?? "")
        return [who, billStamp(order.removedAt)].compactMap { $0 }.joined(separator: " · ")
    }
}
