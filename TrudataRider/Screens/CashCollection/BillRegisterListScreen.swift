//
//  BillRegisterListScreen.swift
//  TrudataRider
//
//  Registers of delivered orders whose payment is still pending. A manager sees every register and
//  can build new ones from beat orders; everyone else sees the registers assigned to them.
//

import SwiftUI
import Combine

final class BillRegisterListViewModel: ObservableObject {

    @Published var registers: [BillRegister] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var statusFilter: String?
    @Published var orderSearch = ""

    let access = CashAccess.current

    private var page = 1
    private var hasMore = false
    private let service = CashCollectionServiceManager()
    private var cancellables = Set<AnyCancellable>()

    var title: String {
        access.canManageBills ? "Bill Register" : "My Bill Register"
    }

    func load(refresh: Bool = false) {
        guard !isLoading else { return }
        if refresh { page = 1 }
        isLoading = true
        errorMessage = nil

        service.billRegisters(
            status: statusFilter,
            assignedTo: nil,
            page: 1,
            orderId: orderSearch.isEmpty ? nil : orderSearch
        )
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
            self.registers = response.items
            self.page = response.meta.currentPage
            self.hasMore = response.hasMore
        }
        .store(in: &cancellables)
    }

    func loadMore() {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true

        service.billRegisters(
            status: statusFilter,
            assignedTo: nil,
            page: page + 1,
            orderId: orderSearch.isEmpty ? nil : orderSearch
        )
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
            let known = Set(self.registers.map(\.id))
            self.registers += response.items.filter { !known.contains($0.id) }
            self.page = response.meta.currentPage
            self.hasMore = response.hasMore
        }
        .store(in: &cancellables)
    }

    func statusChanged(_ status: String?) {
        statusFilter = status
        load(refresh: true)
    }
}

struct BillRegisterListScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BillRegisterListViewModel()
    @State private var isCreating = false

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
                        CcFilterChipRow(
                            options: [
                                (nil, "All"),
                                (BillStatus.pending, "Pending"),
                                (BillStatus.cleared, "Cleared"),
                                (BillStatus.cancelled, "Cancelled")
                            ],
                            selection: Binding(
                                get: { viewModel.statusFilter },
                                set: { viewModel.statusChanged($0) }
                            )
                        )

                        CcContentState(
                            isLoading: viewModel.isLoading && viewModel.registers.isEmpty,
                            errorMessage: viewModel.registers.isEmpty ? viewModel.errorMessage : nil,
                            isEmpty: viewModel.registers.isEmpty,
                            emptyTitle: isCancelledTab ? "No cancelled registers" : "No registers",
                            emptyBody: emptyBody,
                            emptyImage: isCancelledTab ? "nosign" : "doc.text",
                            onRetry: { viewModel.load(refresh: true) }
                        ) {
                            VStack(spacing: 8) {
                                ForEach(viewModel.registers) { register in
                                    NavigationLink {
                                        BillRegisterDetailScreen(registerId: register.id, onHome: onHome)
                                    } label: {
                                        BillRegisterRow(register: register, showAssignee: viewModel.access.canManageBills)
                                    }
                                    .buttonStyle(.plain)
                                    // A register that leaves the filtered list on refresh slides out instead of popping.
                                    .transition(.opacity.combined(with: .move(edge: .leading)))
                                    .onAppear {
                                        if register.id == viewModel.registers.last?.id {
                                            viewModel.loadMore()
                                        }
                                    }
                                }

                                .animation(.easeInOut(duration: 0.25), value: viewModel.registers.map(\.id))

                                if viewModel.isLoadingMore {
                                    ProgressView()
                                        .tint(CcColors.primary)
                                        .padding(.vertical, 12)
                                }
                            }
                        }

                        if viewModel.access.canManageBills {
                            Color.clear.frame(height: 80)
                        }
                    }
                    .padding(12)
                }
            }

            if viewModel.access.canManageBills {
                VStack {
                    Spacer()
                    CcBottomActionBar {
                        CcPrimaryButton(title: "New register", systemImage: "plus") {
                            isCreating = true
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if viewModel.registers.isEmpty {
                viewModel.load()
            }
        }
        .sheet(isPresented: $isCreating) {
            BillRegisterCreateScreen { viewModel.load(refresh: true) }
        }
    }

    private var isCancelledTab: Bool { viewModel.statusFilter == BillStatus.cancelled }

    /// Android's empty-state copy for the Cancelled tab; the other tabs keep this screen's own.
    private var emptyBody: String {
        let manager = viewModel.access.canManageBills
        switch (manager, isCancelledTab) {
        case (false, true): return "Registers of yours that the office cancels show up here."
        case (true, true): return "Registers that are cancelled, or whose bills are all removed, show up here."
        case (true, false): return "Build a register from a beat's pending orders to get started."
        case (false, false): return "Registers assigned to you will show up here."
        }
    }
}

/// Android `BillRegisterCard`. A cancelled register ends with who called it off and why, and its
/// struck-out total, instead of the progress bar. Removed bills drop out of the order count.
struct BillRegisterRow: View {
    let register: BillRegister
    /// Managers see whose register it is; a rider only ever sees their own.
    var showAssignee: Bool = false

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
                Spacer(minLength: 0)
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
                HStack(spacing: 0) {
                    Text("\(register.clearedOrders) of \(register.activeOrders) orders cleared"
                         + (register.removedOrders > 0 ? " · \(register.removedOrders) removed" : ""))
                        .font(.system(size: 12))
                        .foregroundStyle(CcColors.textMuted)
                    Spacer(minLength: 6)
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
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CcColors.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(CcColors.border, lineWidth: 1)
        )
    }

    /// Who called it off and when, the reason on one line, and the total struck out.
    private var cancelledLine: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "nosign")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CcColors.err)
                .padding(.top, 1)
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
            Spacer(minLength: 8)
            Text(CashFormat.rupees(register.totalAmount))
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(CcColors.textFaint)
                .strikethrough()
        }
    }
}

// MARK: - Bill register pieces (Android `BillUi.kt`)

/// A register's or an order's status; a change pops the new pill in.
struct BillStatusPill: View {
    let status: String

    var body: some View {
        let key = status.lowercased()
        Group {
            switch key {
            case BillStatus.cleared: CcPill(text: "Cleared", tone: .ok)
            case BillStatus.pending: CcPill(text: "Pending", tone: .warn)
            case BillStatus.cancelled: CcPill(text: "Cancelled", tone: .err)
            case BillStatus.removed: CcPill(text: "Removed", tone: .err)
            default: CcPill(text: status.isEmpty ? "—" : status.capitalized, tone: .muted)
            }
        }
        .id(key)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
        .animation(.easeOut(duration: 0.22), value: key)
    }
}

/// cleared / total as a thin bar that eases to a new value.
struct BillClearedBar: View {
    let cleared: Int
    let total: Int
    var track: Color = CcColors.track
    var fill: Color = CcColors.ok

    private var fraction: CGFloat {
        total > 0 ? min(max(CGFloat(cleared) / CGFloat(total), 0), 1) : 0
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(fill).frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 6)
        .animation(.easeInOut(duration: 0.6), value: fraction)
    }
}

/// A cancel or remove reason, quoted and in italics. Blank reasons are left out by the caller.
struct BillQuote: View {
    let text: String
    var lines: Int?
    var size: CGFloat = 12
    var color: Color = CcColors.textMuted

    var body: some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            Text("\u{201C}\(trimmed)\u{201D}")
                .font(.system(size: size))
                .italic()
                .foregroundStyle(color)
                .lineLimit(lines)
                .truncationMode(.tail)
        }
    }
}

/// A dialog's bills, as shop and amount: the first few, then how many more.
struct BillLinesPreview: View {
    let lines: [(String, Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.prefix(3).enumerated()), id: \.offset) { _, line in
                HStack {
                    Text(line.0)
                        .font(.system(size: 12.5))
                        .foregroundStyle(CcColors.text)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(CashFormat.rupees(line.1))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(CcColors.text)
                }
            }
            if lines.count > 3 {
                Text("+\(lines.count - 3) more")
                    .font(.system(size: 11.5))
                    .foregroundStyle(CcColors.textMuted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CcColors.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct MetricCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(CcColors.textMuted)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(CcColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
