//
//  AdvanceDetailScreen.swift
//  TrudataRider
//
//  Android `AdvanceDetailScreen` / `AdvanceDetailViewModel`: one advance with every payment
//  returned against it, plus the two actions a manager has — receive money back, and change the
//  advance's status.
//

import Combine
import SwiftUI

final class AdvanceDetailViewModel: ObservableObject {

    let access = CashAccess.current

    @Published private(set) var advance: Advance?
    @Published private(set) var isLoading = true
    @Published private(set) var loadError: String?
    @Published var showStatus = false
    @Published private(set) var isUpdatingStatus = false
    @Published var message: String?
    @Published var error: String?

    private let advanceId: Int
    private let service = CashCollectionServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var loadJob: AnyCancellable?
    private var statusJob: AnyCancellable?

    init(advanceId: Int) {
        self.advanceId = advanceId
        load()
        // A payment received on the receive screen lands back here.
        CashChange.publisher
            .sink { [weak self] change in
                guard change == .advance else { return }
                self?.load()
            }
            .store(in: &cancellables)
    }

    var isManager: Bool { access.canManageAdvance }

    func load() {
        isLoading = true
        loadError = nil
        loadJob = service.advanceDetail(id: advanceId)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self, case .failure(let failure) = completion else { return }
                self.failed(CashError.message(failure))
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if let advance = response.data {
                    self.isLoading = false
                    self.advance = advance
                } else {
                    self.failed(CashError.server(response.message) ?? CashError.empty)
                }
            }
    }

    /// Keep what is on screen if a refresh fails; only an empty screen shows the error.
    private func failed(_ message: String) {
        isLoading = false
        if advance == nil { loadError = message } else { error = message }
    }

    func setStatus(_ status: String) {
        guard !isUpdatingStatus else { return }
        isUpdatingStatus = true
        statusJob = service.updateAdvanceStatus(id: advanceId, status: status)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self, case .failure(let failure) = completion else { return }
                self.isUpdatingStatus = false
                self.error = CashError.message(failure)
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isUpdatingStatus = false
                guard var updated = response.data else {
                    self.error = CashError.server(response.message) ?? CashError.empty
                    return
                }
                // update-status doesn't send the returns back; keep the ones already shown.
                updated.returns = self.advance?.returns ?? []
                self.advance = updated
                self.showStatus = false
                self.message = "Status set to \(AdvanceStatus.label(updated.status.isEmpty ? status : updated.status))"
                CashChange.notify(.advance)
            }
    }
}

struct AdvanceDetailScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AdvanceDetailViewModel
    @State private var receiving = false

    var onHome: () -> Void

    init(advanceId: Int, onHome: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: AdvanceDetailViewModel(advanceId: advanceId))
        self.onHome = onHome
    }

    var body: some View {
        VStack(spacing: 0) {
            SellersAppBar(
                title: "Advance Details",
                onBack: { dismiss() },
                onHome: onHome,
                onRefresh: { viewModel.load() }
            )

            ScrollView {
                VStack(spacing: 10) {
                    content
                }
                .padding(12)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if viewModel.isManager, let advance = viewModel.advance {
                    CashActionTray {
                        CashSecondaryButton(title: "Status", systemImage: "clock.arrow.circlepath") {
                            viewModel.showStatus = true
                        }
                        .containerRelativeFrame(.horizontal) { width, _ in (width - 42) * 0.8 / 2.2 }
                        CashPrimaryButton(
                            title: "Receive Payment",
                            systemImage: "arrow.down.left",
                            isEnabled: AdvanceStatus.isOpen(advance.status) && advance.outstanding > 0
                        ) { receiving = true }
                    }
                }
            }
        }
        .background(CcColors.page.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $receiving) {
            if let advance = viewModel.advance {
                ReceivePaymentScreen(advanceId: advance.id, onHome: onHome)
            }
        }
        .sheet(isPresented: $viewModel.showStatus) {
            if let advance = viewModel.advance {
                AdvanceStatusSheet(
                    current: advance.status,
                    title: "\(CashFormat.rupees(advance.amount)) to \(advance.person?.name ?? "staff") · due \(CashFormat.rupees(advance.outstanding))",
                    isSaving: viewModel.isUpdatingStatus,
                    onSave: { viewModel.setStatus($0) }
                )
                .cashErrorDialog($viewModel.error)
            }
        }
        .cashToast($viewModel.message)
        .cashErrorDialog($viewModel.error)
    }

    @ViewBuilder
    private var content: some View {
        if let advance = viewModel.advance {
            DetailHero(advance: advance)
            CashSection(title: "Details", systemImage: "doc.text") {
                CashDetailLine(label: "Given on", value: CashDates.pretty(advance.date))
                CashDetailLine(label: "Purpose", value: advance.purpose?.nilIfEmpty ?? "—")
                CashDetailLine(label: "Given by", value: advance.givenBy?.name ?? "—")
                CashDetailLine(label: "Entered", value: advance.createdAt ?? "—")
                if let attachment = advance.attachment?.nilIfEmpty {
                    CashAttachmentLink(url: attachment)
                }
            }
            CashSection(
                title: "Payments returned",
                systemImage: "clock.arrow.circlepath",
                subtitle: advance.returns.isEmpty
                    ? nil
                    : "\(advance.returns.count) payment\(advance.returns.count == 1 ? "" : "s") · \(CashFormat.rupees(advance.returns.reduce(0) { $0 + $1.amount }))",
                accent: CcColors.ok
            ) {
                if advance.returns.isEmpty {
                    Text("Nothing returned yet.")
                        .font(.system(size: 13))
                        .foregroundStyle(CcColors.textMuted)
                }
                let sorted = advance.returns.sorted { $0.date > $1.date }
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 { CcColors.divider.frame(height: 1) }
                    ReturnLine(entry: entry)
                }
            }
        } else if viewModel.isLoading {
            CcLoadingBlock()
        } else {
            CashErrorState(message: viewModel.loadError ?? "Couldn't load this advance.") { viewModel.load() }
        }
    }
}

private struct DetailHero: View {
    let advance: Advance

    var body: some View {
        CashHero {
            HStack {
                CashHeroLabel(text: "Advance #\(advance.id)")
                Spacer()
                CashAdvanceStatusPill(status: advance.status)
            }
            Text(CashFormat.rupees(advance.amount))
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.white)
            let who = [advance.person?.name, advance.person?.role?.nilIfEmpty].compactMap { $0 }.joined(separator: " · ")
            Text(who.isEmpty ? "—" : who)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            // How much has come back, as a bar.
            let fraction = advance.amount > 0 ? min(max(advance.returned / advance.amount, 0), 1) : 0
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Color.white.opacity(0.18)
                    CcColors.glow.frame(width: proxy.size.width * fraction).clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .padding(.top, 8)
            HStack(spacing: 8) {
                CashHeroStat(label: "Returned", value: CashFormat.rupees(advance.returned))
                CashHeroStat(label: "Outstanding", value: CashFormat.rupees(advance.outstanding))
            }
            .padding(.top, 6)
        }
    }
}

private struct ReturnLine: View {
    let entry: AdvanceReturn

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text("+ " + CashFormat.rupees(entry.amount))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(CcColors.ok)
                Text(CashDates.pretty(entry.date))
                    .font(.system(size: 12.5))
                    .foregroundStyle(CcColors.textMuted)
                Spacer()
                if let name = entry.receivedBy?.name {
                    Text("By \(name)")
                        .font(.system(size: 12))
                        .foregroundStyle(CcColors.textMuted)
                }
            }
            if let remark = entry.remark?.nilIfEmpty {
                Text(remark)
                    .font(.system(size: 13))
                    .foregroundStyle(CcColors.text)
            }
            if let attachment = entry.attachment?.nilIfEmpty {
                CashAttachmentLink(url: attachment)
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
