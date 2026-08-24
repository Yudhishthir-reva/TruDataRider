//
//  ExpenseListScreen.swift
//  TrudataRider
//

import SwiftUI

struct ExpenseListScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ExpenseViewModel()
    @State private var showAddExpense = false
    @State private var previewImageURL: String?

    var onHome: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Expense Requests",
                    onBack: { dismiss() },
                    onHome: { if let onHome { onHome() } else { dismiss() } },
                    onRefresh: { viewModel.load() }
                )

                AttendanceRequestTabBar(selectedTab: $viewModel.selectedTab)
                content
            }

            if !viewModel.isLoading && viewModel.errorMessage == nil {
                AttendanceFloatingAddButton {
                    showAddExpense = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.load() }
        .navigationDestination(isPresented: $showAddExpense) {
            AddExpenseScreen(
                onSubmitted: { viewModel.load() },
                onHome: onHome
            )
        }
        .alert("Error", isPresented: errorBinding) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: previewImageBinding) {
            if let url = previewImageURL {
                ExpenseImagePreviewSheet(imageURL: url)
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && !viewModel.items.isEmpty },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var previewImageBinding: Binding<Bool> {
        Binding(get: { previewImageURL != nil }, set: { if !$0 { previewImageURL = nil } })
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            ProgressView()
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.items.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                PrimaryActionButton(title: "Retry") {
                    viewModel.load()
                }
                .padding(.horizontal, 40)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.filteredItems.isEmpty {
            Text("No expense requests found for this category.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredItems) { item in
                        ExpenseRequestCard(
                            item: item,
                            indicatorColor: viewModel.selectedTab.indicatorColor,
                            onImageTap: {
                                if let image = item.expenseImage, item.hasImage {
                                    previewImageURL = image
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 88)
            }
        }
    }
}

private struct ExpenseRequestCard: View {
    let item: ExpenseItem
    let indicatorColor: Color
    var onImageTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(indicatorColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.amountLabel)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                        Text(item.expenseDate.isEmpty ? "N/A" : item.expenseDate)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    if item.hasImage, let imageURL = item.expenseImage {
                        Button(action: onImageTap) {
                            RemoteImage(url: imageURL, contentMode: .fill)
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !item.remark.isEmpty {
                    Text("Remark: \(item.remark)")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Text(item.statusLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(indicatorColor)
            }
            .padding(14)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
    }
}

private struct ExpenseImagePreviewSheet: View {
    let imageURL: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                RemoteImage(url: imageURL, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .background(Color.black)
            .navigationTitle("Expense Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
