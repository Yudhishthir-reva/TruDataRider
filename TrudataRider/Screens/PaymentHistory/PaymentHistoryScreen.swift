//
//  PaymentHistoryScreen.swift
//  TrudataRider
//
//  Payments the rider collected, newest first, filterable by mode, approval status and date.
//

import SwiftUI

struct PaymentHistoryScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PaymentHistoryViewModel()
    @State private var isPickingDates = false
    @State private var zoomImageURL: String?

    var onHome: () -> Void

    var body: some View {
        ZStack {
            DashboardTheme.surfaceVariant.ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Payment History",
                    onBack: { dismiss() },
                    onHome: onHome,
                    onRefresh: { viewModel.load(refresh: true) }
                )

                summaryBar
                filterBar

                ScrollView {
                    LazyVStack(spacing: 12) {
                        CcContentState(
                            isLoading: viewModel.isLoading && viewModel.transactions.isEmpty,
                            errorMessage: viewModel.transactions.isEmpty ? viewModel.errorMessage : nil,
                            isEmpty: viewModel.transactions.isEmpty,
                            emptyTitle: "No payments",
                            emptyBody: viewModel.hasActiveFilters
                                ? "Nothing matches these filters. Try widening them."
                                : "Payments you collect will be listed here.",
                            emptyImage: "creditcard",
                            onRetry: { viewModel.load(refresh: true) }
                        ) {
                            VStack(spacing: 12) {
                                ForEach(viewModel.transactions) { transaction in
                                    TransactionCard(transaction: transaction) {
                                        if let url = transaction.imageUrl, !url.isEmptyString {
                                            zoomImageURL = url
                                        }
                                    }
                                    .onAppear {
                                        if transaction.id == viewModel.transactions.last?.id {
                                            viewModel.loadMore()
                                        }
                                    }
                                }

                                if viewModel.isLoadingMore {
                                    ProgressView()
                                        .tint(DashboardTheme.primaryBlue)
                                        .padding(.vertical, 12)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if viewModel.transactions.isEmpty {
                viewModel.load()
            }
        }
        .sheet(isPresented: $isPickingDates) {
            PaymentDateFilterSheet(viewModel: viewModel)
        }
        .sheet(isPresented: Binding(
            get: { zoomImageURL != nil },
            set: { if !$0 { zoomImageURL = nil } }
        )) {
            if let zoomImageURL {
                BillImageViewer(urlString: zoomImageURL)
            }
        }
    }

    private var summaryBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Shown on this screen")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Text(CashFormat.rupees(viewModel.total))
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }

            Spacer()

            Text("\(viewModel.transactions.count) \(viewModel.transactions.count == 1 ? "payment" : "payments")")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralMedium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white)
    }

    private var filterBar: some View {
        VStack(spacing: 8) {
            CcFilterChipRow(
                options: PaymentType.list.map { (Optional($0.id), $0.displayName) },
                selection: Binding(
                    get: { viewModel.paymentType },
                    set: { viewModel.typeChanged($0 ?? "") }
                )
            )

            CcFilterChipRow(
                options: PaymentApprovalStatus.list.map { (Optional($0.id), $0.displayName) },
                selection: Binding(
                    get: { viewModel.paymentStatus },
                    set: { viewModel.statusChanged($0 ?? "") }
                )
            )

            HStack(spacing: 8) {
                Button {
                    isPickingDates = true
                } label: {
                    Label(dateLabel, systemImage: "calendar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.white, in: Capsule())
                        .overlay(Capsule().stroke(DashboardTheme.primaryBlue.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)

                if viewModel.hasActiveFilters {
                    Button("Clear") { viewModel.clearFilters() }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DashboardTheme.dangerRed)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 10)
        .background(.white)
    }

    private var dateLabel: String {
        guard let start = viewModel.startDate else { return "Any date" }
        let from = CashFormat.pretty(CashFormat.apiString(from: start))
        guard let end = viewModel.endDate else { return "From \(from)" }
        return "\(from) – \(CashFormat.pretty(CashFormat.apiString(from: end)))"
    }
}

// MARK: - Card

private struct TransactionCard: View {
    let transaction: PaymentTransaction
    var onTapImage: () -> Void

    private var status: PaymentApprovalStatus {
        PaymentApprovalStatus.from(api: transaction.status)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let imageUrl = transaction.imageUrl, !imageUrl.isEmptyString {
                    Button(action: onTapImage) {
                        RemoteImage(url: imageUrl)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.sellerName.isEmpty ? "—" : transaction.sellerName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .lineLimit(1)
                    Text(transaction.date)
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }

                Spacer(minLength: 8)

                Text(CashFormat.rupees(transaction.amountValue))
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(DashboardTheme.primaryBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(16)

            Divider().background(DashboardTheme.surfaceVariant)

            HStack(spacing: 10) {
                Label(transaction.paymentMode.isEmpty ? "—" : transaction.paymentMode, systemImage: "creditcard")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralMedium)

                if transaction.deductValue > 0 {
                    Text("Deduct \(CashFormat.rupees(transaction.deductValue))")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(DashboardTheme.dangerRed)
                }

                Spacer(minLength: 8)

                Text(status.displayName)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(status.color.opacity(0.12), in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if let clearDate = transaction.chequeClearDate, !clearDate.isEmptyString {
                HStack {
                    Text("Cheque clears \(clearDate)")
                        .font(.system(size: 11))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
        )
        .shadow(color: DashboardTheme.primaryBlue.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Date filter

private struct PaymentDateFilterSheet: View {

    @ObservedObject var viewModel: PaymentHistoryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var start = Date()
    @State private var end = Date()

    var body: some View {
        NavigationView {
            Form {
                DatePicker("From", selection: $start, displayedComponents: .date)
                DatePicker("To", selection: $end, in: start..., displayedComponents: .date)

                Section {
                    Button("Clear dates") {
                        viewModel.applyDateFilter(start: nil, end: nil)
                        dismiss()
                    }
                    .foregroundStyle(DashboardTheme.dangerRed)
                }
            }
            .navigationTitle("Date range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        viewModel.applyDateFilter(start: start, end: end)
                        dismiss()
                    }
                }
            }
            .onAppear {
                start = viewModel.startDate ?? Date()
                end = viewModel.endDate ?? Date()
            }
        }
    }
}

// MARK: - Image viewer

private struct BillImageViewer: View {

    let urlString: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                RemoteImage(url: urlString, contentMode: .fit)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}
