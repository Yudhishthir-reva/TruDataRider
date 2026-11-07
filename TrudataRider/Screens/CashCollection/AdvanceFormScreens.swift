//
//  AdvanceFormScreens.swift
//  TrudataRider
//
//  The two advance forms: a manager hands money out, and records money coming back. Both can carry
//  an attachment, so both go up as multipart.
//

import SwiftUI
import Combine

final class AdvanceFormViewModel: ObservableObject {

    @Published var amountText = ""
    @Published var date = Date()
    @Published var note = ""
    @Published var personId = ""
    @Published var attachment: UIImage?
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let service = CashCollectionServiceManager()
    private var cancellables = Set<AnyCancellable>()

    var amount: Int {
        Int(amountText) ?? 0
    }

    func amountChanged(_ text: String) {
        amountText = CashCollectionViewModel.digitsOnly(text)
        errorMessage = nil
    }

    private var upload: MultipartFileUpload? {
        guard let data = attachment?.jpegData(compressionQuality: 0.7) else { return nil }
        return MultipartFileUpload(
            fieldName: "attachment",
            fileName: "advance_attachment.jpg",
            mimeType: "image/jpeg",
            data: data
        )
    }

    func give(onSuccess: @escaping () -> Void) {
        guard let person = Int(personId), person > 0 else {
            errorMessage = "Enter the staff id the advance is for."
            return
        }
        guard amount > 0 else {
            errorMessage = "Enter the advance amount."
            return
        }

        isSaving = true
        errorMessage = nil

        service.giveAdvance(
            personId: person,
            amount: amount,
            date: CashFormat.apiString(from: date),
            purpose: note,
            attachment: upload
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isSaving = false
            if case .failure(let error) = completion {
                self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isSaving = false
            if response.data != nil {
                onSuccess()
            } else {
                self.errorMessage = response.message.isEmptyString
                    ? "The advance could not be saved." : response.message
            }
        }
        .store(in: &cancellables)
    }

    func receive(advanceId: Int, onSuccess: @escaping () -> Void) {
        guard amount > 0 else {
            errorMessage = "Enter the amount received."
            return
        }

        isSaving = true
        errorMessage = nil

        service.receiveAdvance(
            advanceId: advanceId,
            amount: amount,
            date: CashFormat.apiString(from: date),
            remark: note,
            attachment: upload
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isSaving = false
            if case .failure(let error) = completion {
                self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isSaving = false
            if response.data != nil {
                onSuccess()
            } else {
                self.errorMessage = response.message.isEmptyString
                    ? "The payment could not be saved." : response.message
            }
        }
        .store(in: &cancellables)
    }
}

// MARK: - Give

struct GiveAdvanceForm: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AdvanceFormViewModel()

    var onSaved: () -> Void

    var body: some View {
        AdvanceFormScaffold(
            title: "Give advance",
            viewModel: viewModel,
            amountLabel: "Advance amount",
            noteLabel: "Purpose",
            showsPersonField: true,
            onSave: {
                viewModel.give {
                    onSaved()
                    dismiss()
                }
            },
            onCancel: { dismiss() }
        )
    }
}

// MARK: - Receive

struct ReceiveAdvanceForm: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AdvanceFormViewModel()

    let advanceId: Int
    var onSaved: () -> Void

    var body: some View {
        AdvanceFormScaffold(
            title: "Receive payment",
            viewModel: viewModel,
            amountLabel: "Amount received",
            noteLabel: "Remark",
            showsPersonField: false,
            onSave: {
                viewModel.receive(advanceId: advanceId) {
                    onSaved()
                    dismiss()
                }
            },
            onCancel: { dismiss() }
        )
    }
}

// MARK: - Shared form

private struct AdvanceFormScaffold: View {

    let title: String
    @ObservedObject var viewModel: AdvanceFormViewModel
    let amountLabel: String
    let noteLabel: String
    let showsPersonField: Bool
    var onSave: () -> Void
    var onCancel: () -> Void

    @State private var isPickingImage = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 10) {
                    CcSection(title: amountLabel, systemImage: "indianrupeesign") {
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
                            if showsPersonField {
                                FormField(title: "Staff id", text: $viewModel.personId, keyboard: .numberPad)
                            }
                            DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                                .font(.system(size: 13, weight: .semibold))
                                .tint(CcColors.primary)
                            FormField(title: noteLabel, text: $viewModel.note)
                        }
                    }

                    CcSection(title: "Attachment", systemImage: "paperclip") {
                        VStack(alignment: .leading, spacing: 8) {
                            if let attachment = viewModel.attachment {
                                Image(uiImage: attachment)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            CcSecondaryButton(
                                title: viewModel.attachment == nil ? "Add a photo" : "Replace photo",
                                systemImage: "camera"
                            ) {
                                isPickingImage = true
                            }
                        }
                    }
                }
                .padding(12)
            }
            .background(CcColors.page)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .disabled(viewModel.isSaving)
                }
            }
            .sheet(isPresented: $isPickingImage) {
                CameraImagePicker(
                    preferRearCamera: true,
                    onImageCaptured: { image in
                        viewModel.attachment = image
                        isPickingImage = false
                    },
                    onCancel: { isPickingImage = false }
                )
            }
            .alert("Can't save", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}
