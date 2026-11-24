//
//  AdvanceFormScreens.swift
//  TrudataRider
//
//  Android `AdvanceFormScreens` / `AdvanceFormViewModels`: a manager hands an advance to a staff
//  member (Give Advance), or records money coming back against one (Receive Payment). Both can carry
//  a bill or document, so both go up as multipart.
//

import Combine
import SwiftUI

/// Give Advance and Receive Payment share this; `advance` is the one being paid back (receive only).
final class AdvanceFormViewModel: ObservableObject {

    enum Mode {
        case give
        case receive(advanceId: Int)
    }

    let mode: Mode

    @Published private(set) var people = PeopleState()
    @Published private(set) var person: PersonOption?
    @Published private(set) var personError: String?
    @Published private(set) var advance: Advance?
    @Published private(set) var isLoadingAdvance = false
    @Published private(set) var loadError: String?
    @Published private(set) var amountText = ""
    @Published private(set) var amountError: String?
    @Published private(set) var date = CashDates.today
    /// Purpose when giving, remark when receiving.
    @Published private(set) var note = ""
    @Published private(set) var attachment: CashAttachment?
    @Published private(set) var isReadingAttachment = false
    @Published private(set) var attachmentError: String?
    @Published private(set) var isSaving = false
    @Published var error: String?
    /// Set once saved; the screen closes.
    @Published private(set) var done = false

    private let service = CashCollectionServiceManager()
    private var jobs = Set<AnyCancellable>()
    private var saveJob: AnyCancellable?

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .give: loadPeople()
        case .receive: loadAdvance()
        }
    }

    var amount: Int { Int(amountText) ?? 0 }

    var busy: Bool { isSaving || isReadingAttachment }

    /// A return can't be dated before the advance it pays back.
    var earliestDate: Date? {
        guard case .receive = mode, let given = advance?.date else { return nil }
        return CashFormat.date(fromApi: given)
    }

    // MARK: - Intents

    func personChosen(_ value: PersonOption) {
        person = value
        personError = nil
    }

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

    func loadAdvance() {
        guard case .receive(let id) = mode else { return }
        isLoadingAdvance = true
        loadError = nil
        service.advanceDetail(id: id)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self, case .failure(let failure) = completion else { return }
                self.isLoadingAdvance = false
                self.loadError = CashError.message(failure)
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoadingAdvance = false
                if let advance = response.data {
                    self.advance = advance
                } else {
                    self.loadError = CashError.server(response.message) ?? CashError.empty
                }
            }
            .store(in: &jobs)
    }

    func amountChanged(_ text: String) {
        amountText = String(cashDigitsOnly(text).prefix(9))
        amountError = nil
    }

    func fillOutstanding() {
        guard let advance else { return }
        amountText = String(Int(advance.outstanding))
        amountError = nil
    }

    func dateChanged(_ value: Date) {
        guard value <= Date() else { return }
        if let earliest = earliestDate, value < earliest { return }
        date = value
    }

    func noteChanged(_ text: String) {
        note = String(text.prefix(250))
    }

    func photoPicked(_ image: UIImage) {
        read { CashAttachmentReader.read(photo: image) }
    }

    func filePicked(_ url: URL) {
        read { CashAttachmentReader.read(fileAt: url) }
    }

    func removeAttachment() {
        attachment = nil
        attachmentError = nil
    }

    private func read(_ work: @escaping () -> Result<CashAttachment, CashAttachmentReader.Failure>) {
        isReadingAttachment = true
        attachmentError = nil
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = work()
            DispatchQueue.main.async {
                guard let self else { return }
                self.isReadingAttachment = false
                switch result {
                case .success(let picked): self.attachment = picked
                case .failure(let failure): self.attachmentError = failure.errorDescription
                }
            }
        }
    }

    // MARK: - Submit

    func submit() {
        guard !busy else { return }
        switch mode {
        case .give: give()
        case .receive: receive()
        }
    }

    private func give() {
        let personError = person == nil ? "Choose who the advance is for" : nil
        let amountError = amount <= 0 ? "Enter an amount above ₹0" : nil
        if personError != nil || amountError != nil {
            self.personError = personError
            self.amountError = amountError
            error = [personError, amountError].compactMap { $0 }.joined(separator: ".\n") + "."
            return
        }
        guard let person else { return }
        isSaving = true
        saveJob = service.giveAdvance(
            personId: person.id,
            amount: amount,
            date: CashFormat.apiString(from: date),
            purpose: note,
            attachment: attachment?.upload
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self, case .failure(let failure) = completion else { return }
            self.showFailure(CashError.message(failure))
        } receiveValue: { [weak self] response in
            self?.finish(response)
        }
    }

    private func receive() {
        guard let advance else { return }
        let amountError: String?
        if !AdvanceStatus.isOpen(advance.status) {
            amountError = "This advance is \(AdvanceStatus.label(advance.status).lowercased()); nothing can be received against it"
        } else if amount <= 0 {
            amountError = "Enter an amount above ₹0"
        } else if Double(amount) > advance.outstanding {
            amountError = "Only \(CashFormat.rupees(advance.outstanding)) is outstanding"
        } else {
            amountError = nil
        }
        if let amountError {
            self.amountError = amountError
            error = amountError + "."
            return
        }
        isSaving = true
        saveJob = service.receiveAdvance(
            advanceId: advance.id,
            amount: amount,
            date: CashFormat.apiString(from: date),
            remark: note,
            attachment: attachment?.upload
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self, case .failure(let failure) = completion else { return }
            self.showFailure(CashError.message(failure))
        } receiveValue: { [weak self] response in
            self?.finish(response)
        }
    }

    private func finish(_ response: DataResponse<Advance>) {
        guard response.data != nil else {
            showFailure(CashError.server(response.message) ?? CashError.empty)
            return
        }
        CashChange.notify(.advance)
        isSaving = false
        done = true
    }

    /// Shows a failed save on the field it is about, and always as a pop-up.
    private func showFailure(_ message: String) {
        let lower = message.lowercased()
        isSaving = false
        if lower.contains("amount") {
            amountError = message
        } else if lower.contains("person") {
            personError = message
        } else if lower.contains("attachment") {
            attachmentError = message
        }
        error = message
    }
}

// MARK: - Screens

/// Admin, accountant or sales manager hands an advance to a staff member.
struct GiveAdvanceScreen: View {

    @StateObject private var viewModel = AdvanceFormViewModel(mode: .give)
    @State private var showPerson = false

    var onHome: () -> Void

    var body: some View {
        AdvanceFormScaffold(
            title: "Give Advance",
            viewModel: viewModel,
            summaryLabel: viewModel.person.map { "Advance to \($0.name)" } ?? "Choose a person",
            submitTitle: "Give Advance",
            onHome: onHome
        ) { pickDate in
            CashSection(title: "Who and when", systemImage: "person.fill") {
                CashPickerField(
                    label: "Person *",
                    value: viewModel.person?.nameWithRole ?? "Choose a person",
                    systemImage: "person.fill",
                    error: viewModel.personError,
                    isPlaceholder: viewModel.person == nil
                ) { showPerson = true }
                CashPickerField(
                    label: "Date *",
                    value: CashDates.format(viewModel.date, "d MMM yyyy"),
                    systemImage: "calendar",
                    action: pickDate
                )
            }
            AmountSection(viewModel: viewModel, outstanding: nil)
            NoteSection(title: "Purpose / Remark", hint: "e.g. For market visit and expenses", viewModel: viewModel)
            AttachmentSection(viewModel: viewModel)
        }
        .sheet(isPresented: $showPerson) {
            CashPersonPicker(
                state: viewModel.people,
                selected: viewModel.person,
                onRetry: { viewModel.loadPeople() },
                onPick: { viewModel.personChosen($0) }
            )
        }
    }
}

/// Money coming back against one advance; the person and outstanding come from the advance.
struct ReceivePaymentScreen: View {

    @StateObject private var viewModel: AdvanceFormViewModel

    var onHome: () -> Void

    init(advanceId: Int, onHome: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: AdvanceFormViewModel(mode: .receive(advanceId: advanceId)))
        self.onHome = onHome
    }

    var body: some View {
        let after = viewModel.advance.map { max($0.outstanding - Double(viewModel.amount), 0) }
        AdvanceFormScaffold(
            title: "Receive Payment",
            viewModel: viewModel,
            summaryLabel: after.map { "Outstanding after this: \(CashFormat.rupees($0))" } ?? "Receiving",
            submitTitle: "Receive",
            showForm: viewModel.advance != nil,
            onHome: onHome
        ) { pickDate in
            if let advance = viewModel.advance {
                AdvanceSummaryCard(advance: advance)
                AmountSection(viewModel: viewModel, outstanding: advance.outstanding)
                CashSection(title: "When", systemImage: "calendar") {
                    CashPickerField(
                        label: "Date *",
                        value: CashDates.format(viewModel.date, "d MMM yyyy"),
                        systemImage: "calendar",
                        action: pickDate
                    )
                }
                NoteSection(title: "Remark", hint: "e.g. Partial return", viewModel: viewModel)
                AttachmentSection(viewModel: viewModel)
            } else if viewModel.isLoadingAdvance {
                CcLoadingBlock()
            } else {
                CashErrorState(message: viewModel.loadError ?? "Couldn't load this advance.") { viewModel.loadAdvance() }
            }
        }
    }
}

private struct AdvanceFormScaffold<Content: View>: View {
    let title: String
    @ObservedObject var viewModel: AdvanceFormViewModel
    let summaryLabel: String
    let submitTitle: String
    var showForm = true
    var onHome: () -> Void
    @ViewBuilder var content: (_ pickDate: @escaping () -> Void) -> Content

    @Environment(\.dismiss) private var dismiss
    @State private var showDate = false

    var body: some View {
        VStack(spacing: 0) {
            SellersAppBar(title: title, onBack: { dismiss() }, onHome: onHome, onRefresh: nil)

            ScrollView {
                VStack(spacing: 10) {
                    content { showDate = true }
                }
                .padding(12)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showForm {
                    CashActionTray {
                        CashBarSummary(label: summaryLabel, value: CashFormat.rupees(viewModel.amount))
                    } buttons: {
                        CashSecondaryButton(title: "Cancel", color: CcColors.textMuted, isEnabled: !viewModel.isSaving) {
                            dismiss()
                        }
                        .containerRelativeFrame(.horizontal) { width, _ in (width - 42) * 0.8 / 2.2 }
                        CashPrimaryButton(
                            title: submitTitle,
                            systemImage: "checkmark",
                            isEnabled: !viewModel.isReadingAttachment,
                            isLoading: viewModel.isSaving
                        ) { viewModel.submit() }
                    }
                }
            }
        }
        .background(CcColors.page.ignoresSafeArea())
        .navigationBarHidden(true)
        .onChange(of: viewModel.done) { _, done in
            if done { dismiss() }
        }
        .sheet(isPresented: $showDate) {
            CashDatePickerSheet(date: viewModel.date, earliest: viewModel.earliestDate) { viewModel.dateChanged($0) }
        }
        .cashErrorDialog($viewModel.error)
    }
}

private struct AmountSection: View {
    @ObservedObject var viewModel: AdvanceFormViewModel
    let outstanding: Double?

    var body: some View {
        CashSection(title: outstanding != nil ? "Receive amount" : "Advance amount", systemImage: "indianrupeesign") {
            CashTextField(
                text: .constant(viewModel.amountText),
                placeholder: "0",
                prefix: "₹",
                supporting: CashFormat.amountInWords(viewModel.amount),
                error: viewModel.amountError,
                keyboard: .numberPad,
                onChange: { viewModel.amountChanged($0) }
            )
            if let outstanding, outstanding > 0 {
                let full = String(Int(outstanding))
                CashChipRow(
                    options: [(full, "Full \(CashFormat.rupees(outstanding))")],
                    selection: viewModel.amountText == full ? full : nil
                ) { _ in viewModel.fillOutstanding() }
            }
        }
    }
}

private struct NoteSection: View {
    let title: String
    let hint: String
    @ObservedObject var viewModel: AdvanceFormViewModel

    var body: some View {
        CashSection(title: title, systemImage: "text.alignleft", subtitle: "Optional") {
            CashTextField(
                text: .constant(viewModel.note),
                placeholder: hint,
                minLines: 3,
                onChange: { viewModel.noteChanged($0) }
            )
        }
    }
}

private struct AttachmentSection: View {
    @ObservedObject var viewModel: AdvanceFormViewModel

    var body: some View {
        CashSection(title: "Attachment", systemImage: "paperclip", subtitle: "Optional · bill or document") {
            CashAttachmentField(
                picked: viewModel.attachment,
                isReading: viewModel.isReadingAttachment,
                error: viewModel.attachmentError,
                onPhoto: { viewModel.photoPicked($0) },
                onFile: { viewModel.filePicked($0) },
                onRemove: { viewModel.removeAttachment() }
            )
        }
    }
}

/// Who the advance went to, how much, and what is still outstanding — read only.
private struct AdvanceSummaryCard: View {
    let advance: Advance

    var body: some View {
        CashSection(title: "Advance", systemImage: "doc.text", trailing: AnyView(CashAdvanceStatusPill(status: advance.status))) {
            HStack(spacing: 10) {
                Text(cashInitials(advance.person?.name ?? ""))
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(CcColors.primary)
                    .frame(width: 38, height: 38)
                    .background(CcColors.container, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(advance.person?.name ?? "—")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(CcColors.text)
                    Text((["Given \(CashDates.pretty(advance.date))", advance.purpose?.nilIfEmpty] as [String?]).compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 12))
                        .foregroundStyle(CcColors.textMuted)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                figure("Advance amount", CashFormat.rupees(advance.amount), strong: false)
                figure("Outstanding", CashFormat.rupees(advance.outstanding), strong: true)
            }
        }
    }

    private func figure(_ label: String, _ value: String, strong: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(CcColors.textMuted)
            Text(value)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(strong ? CcColors.warn : CcColors.text)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(strong ? CcColors.warnBg : CcColors.track, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(strong ? CcColors.warn.opacity(0.25) : CcColors.border, lineWidth: 1)
        )
    }
}
