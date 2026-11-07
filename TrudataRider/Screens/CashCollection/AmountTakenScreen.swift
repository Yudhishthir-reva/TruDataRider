//
//  AmountTakenScreen.swift
//  TrudataRider
//
//  Cash handed out for expenses: the list of what has been taken, and the form that records a new
//  one. Reviewer roles only — a rider never sees this (`CashAccess.canManageAmountTaken`).
//

import SwiftUI
import Combine

final class AmountTakenViewModel: ObservableObject {

    @Published var entries: [AmountTaken] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var range: CashDateRange = .allTime

    // Add form
    @Published var isAdding = false
    @Published var amountText = ""
    @Published var reason = ""
    @Published var remark = ""
    @Published var date = Date()
    @Published var personId = ""
    @Published var isSaving = false
    @Published var formError: String?
    @Published var successMessage: String?

    private var page = 1
    private var hasMore = false
    private let service = CashCollectionServiceManager()
    private var cancellables = Set<AnyCancellable>()

    var amount: Int {
        Int(amountText) ?? 0
    }

    var total: Double {
        entries.reduce(0) { $0 + $1.amount }
    }

    func load(refresh: Bool = false) {
        guard !isLoading else { return }
        if refresh { page = 1 }
        isLoading = true
        errorMessage = nil

        service.amountTakenList(range: range, staffIds: [], page: 1)
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
                self.entries = response.items
                self.page = response.meta.currentPage
                self.hasMore = response.hasMore
            }
            .store(in: &cancellables)
    }

    func loadMore() {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true

        service.amountTakenList(range: range, staffIds: [], page: page + 1)
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
                let known = Set(self.entries.map(\.id))
                self.entries += response.items.filter { !known.contains($0.id) }
                self.page = response.meta.currentPage
                self.hasMore = response.hasMore
            }
            .store(in: &cancellables)
    }

    func amountChanged(_ text: String) {
        amountText = CashCollectionViewModel.digitsOnly(text)
        formError = nil
    }

    func save() {
        guard !isSaving else { return }
        guard let person = Int(personId), person > 0 else {
            formError = "Enter the staff id the cash was handed to."
            return
        }
        guard amount > 0 else {
            formError = "Enter the amount taken."
            return
        }

        isSaving = true
        formError = nil

        service.addAmountTaken(
            personId: person,
            amount: amount,
            reason: reason,
            remark: remark,
            date: CashFormat.apiString(from: date),
            collectionId: nil
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isSaving = false
            if case .failure(let error) = completion {
                self.formError = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isSaving = false
            if response.data != nil {
                self.resetForm()
                self.isAdding = false
                self.successMessage = "Amount taken recorded."
                self.load(refresh: true)
            } else {
                self.formError = response.message.isEmptyString
                    ? "The entry could not be saved." : response.message
            }
        }
        .store(in: &cancellables)
    }

    func updateStatus(_ entry: AmountTaken, approve: Bool) {
        service.updateAmountTakenStatus(id: entry.id, approve: approve)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if let updated = response.data,
                   let index = self.entries.firstIndex(where: { $0.id == updated.id }) {
                    self.entries[index] = updated
                } else {
                    self.load(refresh: true)
                }
            }
            .store(in: &cancellables)
    }

    private func resetForm() {
        amountText = ""
        reason = ""
        remark = ""
        personId = ""
        date = Date()
    }
}

struct AmountTakenScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AmountTakenViewModel()

    var onHome: () -> Void

    var body: some View {
        ZStack {
            CcColors.page.ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Amount Taken",
                    onBack: { dismiss() },
                    onHome: onHome,
                    onRefresh: { viewModel.load(refresh: true) }
                )

                ScrollView {
                    LazyVStack(spacing: 10) {
                        hero

                        CcFilterChipRow(
                            options: [(nil, "All time"), ("today", "Today"), ("7", "Last 7 days"), ("30", "Last 30 days")],
                            selection: rangeSelection
                        )

                        CcContentState(
                            isLoading: viewModel.isLoading && viewModel.entries.isEmpty,
                            errorMessage: viewModel.entries.isEmpty ? viewModel.errorMessage : nil,
                            isEmpty: viewModel.entries.isEmpty,
                            emptyTitle: "Nothing taken yet",
                            emptyBody: "Cash handed out for expenses will be listed here.",
                            emptyImage: "wallet.pass",
                            onRetry: { viewModel.load(refresh: true) }
                        ) {
                            VStack(spacing: 8) {
                                ForEach(viewModel.entries) { entry in
                                    AmountTakenRow(entry: entry) { approve in
                                        viewModel.updateStatus(entry, approve: approve)
                                    }
                                    .onAppear {
                                        if entry.id == viewModel.entries.last?.id {
                                            viewModel.loadMore()
                                        }
                                    }
                                }

                                if viewModel.isLoadingMore {
                                    ProgressView()
                                        .tint(CcColors.primary)
                                        .padding(.vertical, 12)
                                }
                            }
                        }

                        Color.clear.frame(height: 80)
                    }
                    .padding(12)
                }
            }

            VStack {
                Spacer()
                CcBottomActionBar {
                    CcPrimaryButton(title: "Record amount taken", systemImage: "plus") {
                        viewModel.isAdding = true
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if viewModel.entries.isEmpty {
                viewModel.load()
            }
        }
        .sheet(isPresented: $viewModel.isAdding) {
            AmountTakenForm(viewModel: viewModel)
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

    private var hero: some View {
        CcHero {
            CcHeroLabel(text: viewModel.range.label)
            Text(CashFormat.rupees(viewModel.total))
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.white)
            Text("\(viewModel.entries.count) \(viewModel.entries.count == 1 ? "entry" : "entries")")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var rangeSelection: Binding<String?> {
        Binding(
            get: {
                if viewModel.range.isAllTime { return nil }
                if viewModel.range == .today { return "today" }
                if viewModel.range == .lastDays(7) { return "7" }
                if viewModel.range == .lastDays(30) { return "30" }
                return nil
            },
            set: { key in
                switch key {
                case "today": viewModel.range = .today
                case "7": viewModel.range = .lastDays(7)
                case "30": viewModel.range = .lastDays(30)
                default: viewModel.range = .allTime
                }
                viewModel.load(refresh: true)
            }
        )
    }
}

private struct AmountTakenRow: View {
    let entry: AmountTaken
    var onReview: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                CcIconDisc(systemImage: "arrow.up.right", accent: CcColors.warn, size: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(CashFormat.rupees(entry.amount))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(CcColors.text)
                    if let name = entry.person?.name, !name.isEmpty {
                        Text(name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CcColors.textMuted)
                    }
                    Text(CashFormat.pretty(entry.date))
                        .font(.system(size: 11.5))
                        .foregroundStyle(CcColors.textFaint)
                }

                Spacer(minLength: 8)

                CcStatusPill(status: entry.status)
            }

            if let reason = entry.reason, !reason.isEmptyString {
                Text(reason)
                    .font(.system(size: 12.5))
                    .foregroundStyle(CcColors.textMuted)
            }

            if entry.isPending {
                HStack(spacing: 8) {
                    CcSecondaryButton(title: "Reject", tint: CcColors.err) { onReview(false) }
                    CcPrimaryButton(title: "Approve") { onReview(true) }
                }
            }
        }
        .padding(12)
        .background(CcColors.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(CcColors.border, lineWidth: 1)
        )
    }
}

private struct AmountTakenForm: View {

    @ObservedObject var viewModel: AmountTakenViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 10) {
                    CcSection(title: "Amount", systemImage: "indianrupeesign") {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("₹")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(CcColors.textMuted)
                                TextField("0", text: Binding(
                                    get: { viewModel.amountText },
                                    set: { viewModel.amountChanged($0) }
                                ))
                                .keyboardType(.numberPad)
                                .font(.system(size: 24, weight: .heavy))
                                .tint(CcColors.primary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(CcColors.border, lineWidth: 1)
                            )

                            let words = CashFormat.amountInWords(viewModel.amount)
                            if !words.isEmpty {
                                Text(words)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(CcColors.textMuted)
                            }
                        }
                    }

                    CcSection(title: "Details", systemImage: "person.text.rectangle") {
                        VStack(spacing: 10) {
                            FormField(title: "Staff id", text: $viewModel.personId, keyboard: .numberPad)
                            DatePicker(
                                "Date",
                                selection: $viewModel.date,
                                displayedComponents: .date
                            )
                            .font(.system(size: 13, weight: .semibold))
                            .tint(CcColors.primary)
                            FormField(title: "Reason", text: $viewModel.reason)
                            FormField(title: "Remark", text: $viewModel.remark)
                        }
                    }
                }
                .padding(12)
            }
            .background(CcColors.page)
            .navigationTitle("Record amount taken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { viewModel.save() }
                        .disabled(viewModel.isSaving)
                }
            }
            .alert("Can't save", isPresented: Binding(
                get: { viewModel.formError != nil },
                set: { if !$0 { viewModel.formError = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.formError = nil }
            } message: {
                Text(viewModel.formError ?? "")
            }
        }
    }
}

struct FormField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(CcColors.textMuted)
            TextField(title, text: $text)
                .keyboardType(keyboard)
                .font(.system(size: 14))
                .padding(10)
                .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(CcColors.border, lineWidth: 1)
                )
        }
    }
}
