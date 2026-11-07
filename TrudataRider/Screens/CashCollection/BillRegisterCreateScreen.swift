//
//  BillRegisterCreateScreen.swift
//  TrudataRider
//
//  Pick beats, pick the delivered orders whose payment is still pending, and hand the register to
//  someone. Orders already in a register are shown but can't be picked — the server doesn't stop a
//  second register from taking them. Nothing is sent until a summary is confirmed, and changing
//  beats or leaving asks first whenever picks would be thrown away.
//

import SwiftUI
import Combine

final class BillRegisterCreateViewModel: ObservableObject {

    @Published var beats: [Beat] = []
    @Published var selectedBeats: Set<Int> = []
    @Published var orders: [BeatOrder] = []
    @Published var selectedOrders: Set<Int> = []
    @Published var assignedTo = ""

    @Published var isLoadingBeats = false
    @Published var isLoadingOrders = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    /// The create summary is up; it stays up while saving, so a failure can be read and retried.
    @Published var confirming = false
    @Published var confirmError: String?
    /// Beats waiting on a yes, because switching to them would untick bills already picked.
    @Published var pendingBeats: Set<Int>?
    /// Set once created; the screen moves on.
    @Published var createdId: Int?

    private let service = CashCollectionServiceManager()
    private var cancellables = Set<AnyCancellable>()

    /// Orders already in a register must not be put in another.
    var selectableOrders: [BeatOrder] {
        orders.filter { !$0.isAssigned }
    }

    var selectedTotal: Double {
        var sum: Double = 0
        for order in orders where selectedOrders.contains(order.orderId) {
            sum += order.pendingAmount
        }
        return sum
    }

    var picks: BillCreatePicks {
        BillCreatePicks(selectedBeats: selectedBeats, orders: orders, selectedOrders: selectedOrders, createdId: createdId)
    }

    /// Leaving would throw picks away, so it asks first — but not mid-save.
    var guardsLeaving: Bool { picks.hasPicks && !isSaving }

    /// The staff id typed in, once it is a real one.
    var assignee: Int? { Int(assignedTo).flatMap { $0 > 0 ? $0 : nil } }

    /// `beat-list` pages by 50, so this walks the pages until the last one.
    func loadBeats(page: Int = 1, accumulated: [Beat] = []) {
        if page == 1 {
            isLoadingBeats = true
            errorMessage = nil
        }

        service.beats(page: page)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                if case .failure(let error) = completion {
                    self.isLoadingBeats = false
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                let all = accumulated + response.beats
                // 20 pages is 1,000 beats — far past anything real, and a stop if the server loops.
                if response.currentPage < response.lastPage, !response.beats.isEmpty, page < 20 {
                    self.loadBeats(page: page + 1, accumulated: all)
                } else {
                    self.isLoadingBeats = false
                    self.beats = all
                        .filter(\.isActive)
                        .sorted { $0.name.lowercased() < $1.name.lowercased() }
                }
            }
            .store(in: &cancellables)
    }

    /// Switching beats unticks the picks from beats left out, so that waits for a yes.
    func toggleBeat(_ beat: Beat) {
        var ids = selectedBeats
        if ids.contains(beat.id) {
            ids.remove(beat.id)
        } else {
            ids.insert(beat.id)
        }
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

    func loadOrders() {
        guard !selectedBeats.isEmpty else {
            orders = []
            selectedOrders = []
            return
        }

        isLoadingOrders = true
        errorMessage = nil

        service.beatOrders(beatIds: selectedBeats)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoadingOrders = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoadingOrders = false
                self.orders = response.data?.orders ?? []
                // Keep only picks that still exist and are still free.
                let selectable = Set(self.selectableOrders.map(\.orderId))
                self.selectedOrders = self.selectedOrders.intersection(selectable)
            }
            .store(in: &cancellables)
    }

    func toggleOrder(_ order: BeatOrder) {
        guard !order.isAssigned else { return }
        if selectedOrders.contains(order.orderId) {
            selectedOrders.remove(order.orderId)
        } else {
            selectedOrders.insert(order.orderId)
        }
    }

    func selectAll() {
        selectedOrders = Set(selectableOrders.map(\.orderId))
    }

    /// Checks the form, then shows what is about to be created; nothing is sent until that's confirmed.
    func askCreate() {
        guard !isSaving else { return }
        guard assignee != nil else {
            errorMessage = "Enter the staff id to assign this register to."
            return
        }
        guard !selectedOrders.isEmpty else {
            errorMessage = "Pick at least one order for the register."
            return
        }
        confirmError = nil
        confirming = true
    }

    /// Closing is ignored while saving; the server's answer decides what happens next.
    func dismissCreate() {
        guard !isSaving else { return }
        confirming = false
        confirmError = nil
    }

    func create(onSuccess: @escaping () -> Void) {
        guard !isSaving, confirming, let assignee, !selectedOrders.isEmpty else { return }

        isSaving = true
        confirmError = nil

        service.createBillRegister(
            beatIds: Set(picks.picked.map(\.beatId)),
            orderIds: selectedOrders,
            assignedTo: assignee
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isSaving = false
            if case .failure(let error) = completion {
                self.confirmError = (error as? RequestError)?.errorString ?? error.localizedDescription
                // A server that answered may know the list is stale; no connection says nothing.
                if let requestError = error as? RequestError, !Self.isOffline(requestError) {
                    self.loadOrders()
                }
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isSaving = false
            if response.billRegisterId > 0 {
                self.confirming = false
                self.createdId = response.billRegisterId
                onSuccess()
            } else {
                self.confirmError = response.message.isEmptyString
                    ? "The register could not be created." : response.message
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
    /// Set while "Discard this register?" is up.
    @State private var isLeaving = false

    var onCreated: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                CcColors.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 10) {
                        beatsSection
                        if !viewModel.selectedBeats.isEmpty {
                            ordersSection
                        }
                        assignSection
                        Color.clear.frame(height: 70)
                    }
                    .padding(12)
                }

                VStack {
                    Spacer()
                    CcBottomActionBar {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(viewModel.selectedOrders.count) picked")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(CcColors.textMuted)
                            Text(CashFormat.rupees(viewModel.selectedTotal))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(CcColors.text)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        CcPrimaryButton(
                            title: "Create",
                            systemImage: "checkmark",
                            isEnabled: !viewModel.selectedOrders.isEmpty,
                            isLoading: viewModel.isSaving
                        ) {
                            viewModel.askCreate()
                        }
                        .frame(width: 140)
                    }
                }
            }
            .navigationTitle("New register")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { leave() }
                }
            }
            .onAppear {
                if viewModel.beats.isEmpty {
                    viewModel.loadBeats()
                }
            }
            .alert("Can't continue", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        // A swipe down would drop the picks without asking; Cancel asks instead.
        .interactiveDismissDisabled(viewModel.guardsLeaving || viewModel.isSaving)
        .overlay { dialogs }
        .animation(.easeInOut(duration: 0.2), value: viewModel.confirming)
        .animation(.easeInOut(duration: 0.2), value: viewModel.pendingBeats)
        .animation(.easeInOut(duration: 0.2), value: isLeaving)
    }

    private func leave() {
        if viewModel.guardsLeaving { isLeaving = true } else { dismiss() }
    }

    @ViewBuilder
    private var dialogs: some View {
        if viewModel.confirming {
            BillCreateConfirmDialog(viewModel: viewModel) {
                viewModel.create {
                    onCreated()
                    dismiss()
                }
            }
            .transition(.opacity)
        } else if let ids = viewModel.pendingBeats {
            let dropped = viewModel.picks.droppedBy(ids)
            let gone = viewModel.beats.filter { viewModel.selectedBeats.contains($0.id) && !ids.contains($0.id) }.map(\.name)
            CcConfirmDialog(
                systemImage: "map",
                title: "Change beats?",
                message: "\(billCount(dropped.count)) you picked (\(CashFormat.rupees(dropped.reduce(0) { $0 + $1.pendingAmount }))) "
                    + (gone.isEmpty ? "" : "from \(gone.joined(separator: ", ")) ") + "will be unticked.",
                confirmTitle: "Change beats",
                dismissTitle: "Keep beats",
                onConfirm: { viewModel.confirmBeats() },
                onDismiss: { viewModel.keepBeats() }
            )
            .transition(.opacity)
        } else if isLeaving {
            CcConfirmDialog(
                systemImage: "trash",
                title: "Discard this register?",
                message: "You've picked \(billCount(viewModel.selectedOrders.count)) (\(CashFormat.rupees(viewModel.selectedTotal)))"
                    + (viewModel.assignee.map { " for staff #\($0)" } ?? "") + ". Leaving now throws the picks away.",
                confirmTitle: "Discard",
                confirmColor: CcColors.err,
                dismissTitle: "Keep editing",
                onConfirm: { isLeaving = false; dismiss() },
                onDismiss: { isLeaving = false }
            )
            .transition(.opacity)
        }
    }

    private var beatsSection: some View {
        CcSection(title: "Beats", systemImage: "map") {
            if viewModel.isLoadingBeats {
                CcLoadingBlock()
            } else if viewModel.beats.isEmpty {
                Text("No active beats were found.")
                    .font(.system(size: 13))
                    .foregroundStyle(CcColors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                let columns = [GridItem(.adaptive(minimum: 120), spacing: 8)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(viewModel.beats) { beat in
                        let isSelected = viewModel.selectedBeats.contains(beat.id)
                        Button {
                            viewModel.toggleBeat(beat)
                        } label: {
                            Text(beat.name)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : CcColors.text)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    isSelected ? CcColors.primary : .white,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(isSelected ? Color.clear : CcColors.border, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var ordersSection: some View {
        CcSection(
            title: "Pending orders",
            systemImage: "shippingbox",
            trailing: AnyView(
                Button("Select all") { viewModel.selectAll() }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CcColors.primary)
            )
        ) {
            if viewModel.isLoadingOrders {
                CcLoadingBlock()
            } else if viewModel.orders.isEmpty {
                Text("No delivered orders with pending payment in these beats.")
                    .font(.system(size: 13))
                    .foregroundStyle(CcColors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.orders) { order in
                        BeatOrderRow(
                            order: order,
                            isSelected: viewModel.selectedOrders.contains(order.orderId),
                            onTap: { viewModel.toggleOrder(order) }
                        )
                    }
                }
            }
        }
    }

    private var assignSection: some View {
        CcSection(title: "Assign to", systemImage: "person.badge.plus") {
            FormField(title: "Staff id", text: $viewModel.assignedTo, keyboard: .numberPad)
        }
    }
}

/// The last look before a register is made: who collects, from which beats, how many bills and how
/// much. It stays up while saving, and a server refusal shows here with the picks intact.
private struct BillCreateConfirmDialog: View {
    @ObservedObject var viewModel: BillRegisterCreateViewModel
    var onConfirm: () -> Void

    var body: some View {
        let picked = viewModel.picks.picked
        let total = picked.reduce(0) { $0 + $1.pendingAmount }
        let who = viewModel.assignee.map { "Staff #\($0)" }

        CcDialog(busy: viewModel.isSaving, error: viewModel.confirmError, onDismiss: { viewModel.dismissCreate() }) {
            HStack(spacing: 12) {
                CcIconDisc(systemImage: "person.text.rectangle", accent: CcColors.primary, size: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Create this register?")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(CcColors.text)
                    Text("Check it before it's assigned")
                        .font(.system(size: 12))
                        .foregroundStyle(CcColors.textMuted)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                summaryLine("person.fill", "Assign to", who ?? "—")
                summaryLine("map.fill", beatNames(picked).count == 1 ? "Beat" : "Beats",
                            beatNames(picked).isEmpty ? "—" : beatNames(picked).joined(separator: ", "))
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
            .background(CcColors.container, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            BillLinesPreview(lines: picked.map { order in
                let shop = order.sellerShopName?.trimmingCharacters(in: .whitespaces) ?? ""
                let seller = order.sellerName?.trimmingCharacters(in: .whitespaces) ?? ""
                return (!shop.isEmpty ? shop : !seller.isEmpty ? seller : order.orderNo, order.pendingAmount)
            })
            Text("\(who ?? "They") will find it in their Bill Register and collect these bills. It can still be "
                 + "reassigned, have bills removed or be cancelled later.")
                .font(.system(size: 12.5))
                .foregroundStyle(CcColors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        } buttons: {
            CcSecondaryButton(title: "Back", tint: CcColors.textMuted, isEnabled: !viewModel.isSaving) {
                viewModel.dismissCreate()
            }
            CcPrimaryButton(
                title: "Create & assign",
                systemImage: "checkmark",
                isEnabled: !picked.isEmpty && who != nil,
                isLoading: viewModel.isSaving,
                action: onConfirm
            )
        }
    }

    /// The picked bills' beats by name, in the beat list's order; the bills' own names if the list
    /// hasn't got them.
    private func beatNames(_ picked: [BeatOrder]) -> [String] {
        let ids = Set(picked.map(\.beatId))
        let names = viewModel.beats.filter { ids.contains($0.id) }.map(\.name)
        if !names.isEmpty { return names }
        var seen = Set<String>()
        return picked.compactMap(\.beatName).filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    private func summaryLine(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(CcColors.primary)
                .frame(width: 16)
                .padding(.top, 1)
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

private struct BeatOrderRow: View {
    let order: BeatOrder
    let isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: order.isAssigned
                      ? "lock.fill"
                      : (isSelected ? "checkmark.circle.fill" : "circle"))
                    .font(.system(size: 17))
                    .foregroundStyle(order.isAssigned
                                     ? CcColors.textFaint
                                     : (isSelected ? CcColors.primary : CcColors.textFaint))

                VStack(alignment: .leading, spacing: 3) {
                    Text(order.shopLabel)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(order.isAssigned ? CcColors.textMuted : CcColors.text)
                        .lineLimit(1)
                    Text("Order \(order.orderNo) · \(order.beatName ?? "—")")
                        .font(.system(size: 11.5))
                        .foregroundStyle(CcColors.textMuted)
                    if order.isAssigned {
                        Text("Already in register #\(order.billRegisterId.map(String.init) ?? "—")")
                            .font(.system(size: 11))
                            .foregroundStyle(CcColors.warn)
                    }
                }

                Spacer(minLength: 8)

                Text(CashFormat.rupees(order.pendingAmount))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(order.isAssigned ? CcColors.textMuted : CcColors.text)
            }
            .padding(10)
            .background(
                isSelected ? CcColors.container : CcColors.page,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(order.isAssigned)
    }
}
