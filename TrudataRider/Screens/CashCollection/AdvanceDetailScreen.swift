//
//  AdvanceDetailScreen.swift
//  TrudataRider
//
//  One advance with every payment returned against it, plus the two actions a manager has: receive
//  money back, and move the advance's status.
//

import SwiftUI
import Combine

final class AdvanceDetailViewModel: ObservableObject {

    @Published var advance: Advance?
    @Published var isLoading = false
    @Published var loadError: String?
    @Published var actionError: String?
    @Published var successMessage: String?
    @Published var isUpdatingStatus = false

    let access = CashAccess.current

    private let advanceId: Int
    private let service = CashCollectionServiceManager()
    private var cancellables = Set<AnyCancellable>()

    init(advanceId: Int) {
        self.advanceId = advanceId
    }

    /// Money can still come back while the advance is pending, partial or on hold.
    var canReceive: Bool {
        access.canManageAdvance && (advance.map { AdvanceStatus.isOpen($0.status) } ?? false)
    }

    func load() {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil

        service.advanceDetail(id: advanceId)
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
                if let advance = response.data {
                    self.advance = advance
                } else {
                    self.loadError = response.message.isEmptyString
                        ? "This advance could not be loaded." : response.message
                }
            }
            .store(in: &cancellables)
    }

    func updateStatus(to status: String) {
        guard !isUpdatingStatus else { return }
        isUpdatingStatus = true

        service.updateAdvanceStatus(id: advanceId, status: status)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isUpdatingStatus = false
                if case .failure(let error) = completion {
                    self.actionError = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isUpdatingStatus = false
                if let advance = response.data {
                    self.advance = advance
                    self.successMessage = "Status changed to \(AdvanceStatus.label(advance.status))."
                } else {
                    self.actionError = response.message.isEmptyString
                        ? "The status could not be changed." : response.message
                }
            }
            .store(in: &cancellables)
    }
}

struct AdvanceDetailScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AdvanceDetailViewModel
    @State private var isReceiving = false
    @State private var isPickingStatus = false

    private let advanceId: Int
    var onHome: () -> Void

    init(advanceId: Int, onHome: @escaping () -> Void) {
        self.advanceId = advanceId
        _viewModel = StateObject(wrappedValue: AdvanceDetailViewModel(advanceId: advanceId))
        self.onHome = onHome
    }

    var body: some View {
        ZStack {
            CcColors.page.ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Advance",
                    onBack: { dismiss() },
                    onHome: onHome,
                    onRefresh: { viewModel.load() }
                )

                ScrollView {
                    VStack(spacing: 10) {
                        if viewModel.isLoading && viewModel.advance == nil {
                            CcLoadingBlock()
                        } else if let loadError = viewModel.loadError, viewModel.advance == nil {
                            CcErrorState(message: loadError) { viewModel.load() }
                        } else if let advance = viewModel.advance {
                            hero(advance)
                            details(advance)
                            returnsSection(advance)
                        }

                        if viewModel.canReceive {
                            Color.clear.frame(height: 80)
                        }
                    }
                    .padding(12)
                }
            }

            if viewModel.canReceive {
                VStack {
                    Spacer()
                    CcBottomActionBar {
                        CcSecondaryButton(title: "Change status", systemImage: "arrow.triangle.2.circlepath") {
                            isPickingStatus = true
                        }
                        CcPrimaryButton(title: "Receive payment", systemImage: "arrow.uturn.left") {
                            isReceiving = true
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if viewModel.advance == nil {
                viewModel.load()
            }
        }
        .sheet(isPresented: $isReceiving) {
            ReceiveAdvanceForm(advanceId: advanceId) { viewModel.load() }
        }
        .confirmationDialog("Change status", isPresented: $isPickingStatus, titleVisibility: .visible) {
            ForEach(AdvanceStatus.all, id: \.self) { status in
                Button(AdvanceStatus.label(status)) { viewModel.updateStatus(to: status) }
            }
            Button("Cancel", role: .cancel) {}
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

    private func hero(_ advance: Advance) -> some View {
        CcHero {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    CcHeroLabel(text: "Advance #\(advance.id)")
                    Text(CashFormat.rupees(advance.amount))
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 8)
                CcPill(text: AdvanceStatus.label(advance.status), tone: .muted)
            }

            HStack(spacing: 12) {
                CcHeroStat(label: "Returned", value: CashFormat.rupees(advance.returned))
                CcHeroStat(label: "Outstanding", value: CashFormat.rupees(advance.outstanding))
            }
        }
    }

    private func details(_ advance: Advance) -> some View {
        CcSection(title: "Details", systemImage: "info.circle", accent: CcColors.info) {
            VStack(spacing: 8) {
                CcDetailRow(label: "Given to", value: advance.person?.name ?? "—")
                if let role = advance.person?.role, !role.isEmptyString {
                    CcDetailRow(label: "Role", value: role)
                }
                CcDetailRow(label: "Given by", value: advance.givenBy?.name ?? "—")
                CcDetailRow(label: "Date", value: CashFormat.pretty(advance.date))
                if let purpose = advance.purpose, !purpose.isEmptyString {
                    CcDetailRow(label: "Purpose", value: purpose)
                }
            }
        }
    }

    @ViewBuilder
    private func returnsSection(_ advance: Advance) -> some View {
        CcSection(title: "Payments returned", systemImage: "arrow.uturn.left") {
            if advance.returns.isEmpty {
                Text("Nothing has come back against this advance yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(CcColors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    ForEach(advance.returns) { entry in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(CashFormat.rupees(entry.amount))
                                    .font(.system(size: 14.5, weight: .bold))
                                    .foregroundStyle(CcColors.text)
                                Spacer()
                                Text(CashFormat.pretty(entry.date))
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(CcColors.textFaint)
                            }
                            if let name = entry.receivedBy?.name, !name.isEmpty {
                                Text("Received by \(name)")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(CcColors.textMuted)
                            }
                            if let remark = entry.remark, !remark.isEmptyString {
                                Text("“\(remark)”")
                                    .font(.system(size: 12))
                                    .foregroundStyle(CcColors.textMuted)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(CcColors.page, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }
}
