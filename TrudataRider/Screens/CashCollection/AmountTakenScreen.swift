//
//  AmountTakenScreen.swift
//  TrudataRider
//
//  Android `AmountTakenScreen` / `AmountTakenViewModel`: cash handed out for expenses — the Add tab
//  records one, the All Taken tab lists them with approve / reject. Reviewer roles only; a rider
//  never sees this (`CashAccess.canManageAmountTaken`).
//

import Combine
import SwiftUI

enum TakenTab: Hashable {
    case add, list
}

/// Android `TakenFormState`.
struct TakenFormState {
    var date = CashDates.today
    var person: PersonOption?
    var amountText = ""
    var reason = ""
    var remark = ""
    /// Collections of the chosen person in the chosen month; one can be linked.
    var collections: [CashCollection] = []
    var collectionsLoading = false
    var linkedCollectionId: Int?
    var personError: String?
    var amountError: String?
    var isSaving = false

    var amount: Int { Int(amountText) ?? 0 }
}

final class AmountTakenViewModel: ObservableObject {

    let access = CashAccess.current

    @Published private(set) var tab: TakenTab = .add
    @Published private(set) var form = TakenFormState()
    @Published private(set) var people = PeopleState()
    @Published private(set) var filter = CashFilter(period: .month)
    @Published private(set) var list = CashListState<AmountTaken>()
    /// The row whose detail sheet is open.
    @Published var selected: AmountTaken?
    @Published private(set) var isUpdatingStatus = false
    @Published var message: String?
    /// Shown as a pop-up; `message` is only for success.
    @Published var error: String?

    private let service = CashCollectionServiceManager()
    private var jobs = Set<AnyCancellable>()
    private var collectionsJob: AnyCancellable?
    private var saveJob: AnyCancellable?
    private var statusJob: AnyCancellable?

    private lazy var pager = CashPager<AmountTaken>(
        read: { [weak self] in self?.list },
        write: { [weak self] change in
            guard let self else { return }
            change(&self.list)
        },
        fetch: { [weak self] page in
            guard let self else { return Empty().eraseToAnyPublisher() }
            return self.service.amountTakenList(range: self.filter.dates(), staffIds: self.filter.staffIds, page: page)
                .map { CashPage(items: $0.items, meta: $0.meta) }
                .eraseToAnyPublisher()
        }
    )

    init() {
        loadPeople()
    }

    var staffOptions: [PersonOption] {
        cashMergePeople(people.items, list.items.compactMap { item in
            item.person.map { PersonOption(id: $0.id, name: $0.name, role: "") }
        })
    }

    // MARK: - Intents

    func selectTab(_ value: TakenTab) {
        tab = value
        if value == .list && !list.loaded { pager.load() }
    }

    func dateChanged(_ value: Date) {
        guard value <= Date() else { return }
        let monthChanged = !CashDates.calendar.isDate(value, equalTo: form.date, toGranularity: .month)
        form.date = value
        if monthChanged { loadCollectionsForPerson() }
    }

    func personChosen(_ value: PersonOption) {
        form.person = value
        form.personError = nil
        form.linkedCollectionId = nil
        loadCollectionsForPerson()
    }

    func amountChanged(_ text: String) {
        form.amountText = cashDigitsOnly(text)
        form.amountError = nil
    }

    func reasonChanged(_ text: String) { form.reason = String(text.prefix(100)) }

    func remarkChanged(_ text: String) { form.remark = String(text.prefix(250)) }

    func linkCollection(_ id: Int?) { form.linkedCollectionId = id }

    func filterChanged(_ value: CashFilter) {
        guard value != filter else { return }
        filter = value
        pager.load()
    }

    func refresh() { pager.load(refresh: true) }

    func loadMore() { pager.loadMore() }

    func loadPeople() {
        people = PeopleState(items: people.items, isLoading: true, error: nil)
        CashPeople.load()
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                if case .failure(let failure) = completion {
                    self?.people = PeopleState(error: failure.localizedDescription.isEmpty ? "Couldn't load the staff list" : failure.localizedDescription)
                }
            } receiveValue: { [weak self] items in
                self?.people = PeopleState(items: items)
            }
            .store(in: &jobs)
    }

    /// The chosen person's collections in the month of the chosen date, asked of the server by
    /// `staff_ids`. Linking is optional; if this fails the form still saves without it.
    private func loadCollectionsForPerson() {
        guard let person = form.person else { return }
        form.collectionsLoading = true
        form.collections = []
        collectionsJob = service.allCollections(
            range: .month(of: form.date),
            staffIds: [person.id],
            status: nil,
            page: 1,
            perPage: 50
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self, case .failure = completion else { return }
            self.form.collectionsLoading = false
            self.form.collections = []
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.form.collectionsLoading = false
            self.form.collections = response.items.filter { $0.status != CashStatus.rejected }
        }
    }

    func save() {
        guard !form.isSaving else { return }
        let personError = form.person == nil ? "Choose who took the amount" : nil
        let amountError = form.amount <= 0 ? "Enter an amount above ₹0" : nil
        if personError != nil || amountError != nil {
            form.personError = personError
            form.amountError = amountError
            error = [personError, amountError].compactMap { $0 }.joined(separator: ".\n") + "."
            return
        }
        guard let person = form.person else { return }
        let saved = form
        form.isSaving = true

        saveJob = service.addAmountTaken(
            personId: person.id,
            amount: saved.amount,
            reason: saved.reason,
            remark: saved.remark,
            date: CashFormat.apiString(from: saved.date),
            collectionId: saved.linkedCollectionId
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self, case .failure(let failure) = completion else { return }
            self.saveFailed(CashError.message(failure))
        } receiveValue: { [weak self] response in
            guard let self else { return }
            guard response.data != nil else {
                self.saveFailed(CashError.server(response.message) ?? CashError.empty)
                return
            }
            CashChange.notify(.amountTaken)
            var fresh = TakenFormState()
            fresh.date = saved.date
            self.form = fresh
            self.message = "\(CashFormat.rupees(saved.amount)) recorded for \(person.name)"
            if self.list.loaded { self.pager.load(refresh: true) }
        }
    }

    private func saveFailed(_ message: String) {
        let lower = message.lowercased()
        form.isSaving = false
        if lower.contains("person") {
            form.personError = message
        } else if lower.contains("amount") {
            form.amountError = message
        }
        error = message
    }

    func updateStatus(approve: Bool) {
        guard let item = selected, !isUpdatingStatus else { return }
        isUpdatingStatus = true
        statusJob = service.updateAmountTakenStatus(id: item.id, approve: approve)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self, case .failure(let failure) = completion else { return }
                self.isUpdatingStatus = false
                self.error = CashError.message(failure)
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isUpdatingStatus = false
                guard let updated = response.data else {
                    self.error = CashError.server(response.message) ?? CashError.empty
                    return
                }
                let newStatus = updated.status.isEmpty ? (approve ? CashStatus.approved : CashStatus.rejected) : updated.status
                self.list.items = self.list.items.map { row in
                    guard row.id == item.id else { return row }
                    var changed = row
                    changed.status = newStatus
                    return changed
                }
                self.selected = nil
                self.message = approve ? "Approved \(CashFormat.rupees(item.amount))" : "Rejected \(CashFormat.rupees(item.amount))"
                CashChange.notify(.amountTaken)
            }
    }
}

private let quickReasons = ["Petrol", "Office Expense", "Food", "Vehicle Repair", "Advance"]

struct AmountTakenScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AmountTakenViewModel()
    @State private var showDate = false
    @State private var showPerson = false

    var onHome: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SellersAppBar(
                title: "Amount Taken",
                onBack: { dismiss() },
                onHome: onHome,
                onRefresh: viewModel.tab == .list ? { viewModel.refresh() } : nil
            )

            ScrollView {
                LazyVStack(spacing: 10) {
                    CashSegmented(options: [(.add, "Add"), (.list, "All Taken")], selection: viewModel.tab) {
                        viewModel.selectTab($0)
                    }
                    if viewModel.tab == .add {
                        addForm
                    } else {
                        listTab
                    }
                }
                .padding(12)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if viewModel.tab == .add {
                    CashActionTray {
                        CashBarSummary(
                            label: viewModel.form.person.map { "Taken by \($0.name)" } ?? "Choose a person",
                            value: CashFormat.rupees(viewModel.form.amount)
                        )
                    } buttons: {
                        CashPrimaryButton(title: "Save", systemImage: "checkmark", isLoading: viewModel.form.isSaving) {
                            viewModel.save()
                        }
                    }
                }
            }
        }
        .background(CcColors.page.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showDate) {
            CashDatePickerSheet(date: viewModel.form.date) { viewModel.dateChanged($0) }
        }
        .sheet(isPresented: $showPerson) {
            CashPersonPicker(
                state: viewModel.people,
                selected: viewModel.form.person,
                onRetry: { viewModel.loadPeople() },
                onPick: { viewModel.personChosen($0) }
            )
        }
        .sheet(item: $viewModel.selected) { item in
            TakenDetailSheet(
                item: item,
                canManage: viewModel.access.canManageAmountTaken,
                isUpdating: viewModel.isUpdatingStatus,
                onApprove: { viewModel.updateStatus(approve: true) },
                onReject: { viewModel.updateStatus(approve: false) }
            )
            .cashErrorDialog($viewModel.error)
        }
        .cashToast($viewModel.message)
        .cashErrorDialog($viewModel.error)
    }

    // MARK: - Add

    private var addForm: some View {
        let form = viewModel.form
        return VStack(spacing: 10) {
            CashSection(title: "Who and when", systemImage: "person.fill") {
                CashPickerField(
                    label: "Date",
                    value: CashDates.format(form.date, "d MMM yyyy"),
                    systemImage: "calendar"
                ) { showDate = true }
                CashPickerField(
                    label: "Person",
                    value: form.person?.nameWithRole ?? "Choose a person",
                    systemImage: "person.fill",
                    error: form.personError,
                    isPlaceholder: form.person == nil
                ) { showPerson = true }
            }
            CashSection(title: "Amount", systemImage: "indianrupeesign") {
                CashTextField(
                    text: .constant(form.amountText),
                    placeholder: "0",
                    prefix: "₹",
                    supporting: CashFormat.amountInWords(form.amount),
                    error: form.amountError,
                    keyboard: .numberPad,
                    onChange: { viewModel.amountChanged($0) }
                )
            }
            CashSection(title: "Reason", systemImage: "text.alignleft", subtitle: "Optional") {
                CashChipRow(
                    options: quickReasons.map { ($0, $0) },
                    selection: quickReasons.contains(form.reason) ? form.reason : nil
                ) { picked in
                    viewModel.reasonChanged(picked == form.reason ? "" : (picked ?? ""))
                }
                CashTextField(
                    text: .constant(form.reason),
                    placeholder: "Or type a reason",
                    onChange: { viewModel.reasonChanged($0) }
                )
                CashTextField(
                    text: .constant(form.remark),
                    placeholder: "Remark (optional)",
                    minLines: 2,
                    onChange: { viewModel.remarkChanged($0) }
                )
            }
            if let person = form.person {
                CashSection(
                    title: "Link to a collection",
                    systemImage: "link",
                    subtitle: "Optional · \(person.name)'s collections this month",
                    accent: CcColors.info
                ) {
                    if form.collectionsLoading {
                        CcLoadingBlock()
                    } else if form.collections.isEmpty {
                        Text("No collections from \(person.name) in \(CashDates.format(form.date, "MMMM")).")
                            .font(.system(size: 12.5))
                            .foregroundStyle(CcColors.textMuted)
                    } else {
                        CashChipRow(
                            options: [(nil, "None")] + form.collections.map { collection in
                                let when = collection.submittedAt.map { String($0.split(separator: ",").first ?? "") } ?? "#\(collection.id)"
                                return (String(collection.id), "\(CashFormat.rupees(collection.totalAmount)) · \(when)")
                            },
                            selection: form.linkedCollectionId.map(String.init)
                        ) { viewModel.linkCollection($0.flatMap { Int($0) }) }
                    }
                }
            }
        }
    }

    // MARK: - List

    @ViewBuilder
    private var listTab: some View {
        CashFilterBar(filter: viewModel.filter, staffOptions: viewModel.staffOptions) { viewModel.filterChanged($0) }

        let list = viewModel.list
        if list.isLoading && list.items.isEmpty {
            CcLoadingBlock()
        } else if let error = list.error, list.items.isEmpty {
            CashErrorState(message: error) { viewModel.refresh() }
        } else if list.loaded && list.items.isEmpty {
            CashEmptyState(
                title: "Nothing recorded",
                message: "No amount was taken \(viewModel.filter.periodPhrase)" + (viewModel.filter.staffIds.isEmpty ? "." : " by the chosen staff.")
            )
        } else {
            Text("\(list.total) record\(list.total == 1 ? "" : "s") · \(CashFormat.rupees(list.items.reduce(0) { $0 + $1.amount })) shown")
                .font(.system(size: 12))
                .foregroundStyle(CcColors.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            ForEach(list.items) { item in
                TakenRow(item: item)
                    .onTapGesture { viewModel.selected = item }
                    .cashLoadMore(item, in: list.items) { viewModel.loadMore() }
            }
            if list.isLoadingMore {
                CcLoadingBlock()
            }
        }
    }
}

private struct TakenRow: View {
    let item: AmountTaken

    var body: some View {
        HStack(spacing: 10) {
            Text(cashInitials(item.person?.name ?? ""))
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(CcColors.primary)
                .frame(width: 38, height: 38)
                .background(CcColors.container, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(CashFormat.rupees(item.amount))
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(CcColors.text)
                Text(item.person?.name ?? "—")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CcColors.text)
                Text([item.reason?.nilIfEmpty, CashDates.pretty(item.date)].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 12))
                    .foregroundStyle(CcColors.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            CcStatusPill(status: item.status)
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(CcColors.border, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

private struct TakenDetailSheet: View {
    let item: AmountTaken
    let canManage: Bool
    let isUpdating: Bool
    var onApprove: () -> Void
    var onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(CashFormat.rupees(item.amount))
                        .font(.system(size: 24, weight: .heavy))
                    Text(item.person?.name ?? "—")
                        .font(.system(size: 14, weight: .semibold))
                }
                Spacer()
                CcStatusPill(status: item.status)
            }
            .foregroundStyle(CcColors.text)
            CashDetailLine(label: "Date", value: CashDates.pretty(item.date))
            CashDetailLine(label: "Reason", value: item.reason?.nilIfEmpty ?? "—")
            CashDetailLine(label: "Remark", value: item.remark?.nilIfEmpty ?? "—")
            CashDetailLine(label: "Recorded by", value: item.takenBy?.name ?? "—")
            if canManage && item.status.lowercased() == CashStatus.pending {
                HStack(spacing: 8) {
                    CashSecondaryButton(title: "Reject", systemImage: "xmark", color: CcColors.err, isEnabled: !isUpdating, action: onReject)
                    CashPrimaryButton(title: "Approve", systemImage: "checkmark", isLoading: isUpdating, action: onApprove)
                }
                .padding(.top, 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .presentationDetents([.medium])
        .presentationBackground(.white)
    }
}

/// A labelled single-line field; the bill register's create form uses it too.
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
