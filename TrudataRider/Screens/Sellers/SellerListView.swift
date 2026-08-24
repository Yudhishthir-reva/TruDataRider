//
//  SellerListView.swift
//  TrudataRider
//

import SwiftUI

private enum SellerTheme {
    static let appBlue = Color(red: 0.00, green: 0.20, blue: 0.31)
    static let buttonBlue = Color(red: 0.00, green: 0.48, blue: 0.95)
    static let lightBackground = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let activeBg = Color(red: 0.90, green: 0.98, blue: 0.94)
    static let activeText = Color(red: 0.08, green: 0.50, blue: 0.24)
}

struct SellerListView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SellerListViewModel()
    @State private var showFilters = false
    @State private var draftStatus = ""

    var onHome: (() -> Void)?
    var onOpenSeller: (String) -> Void

    var body: some View {
        ZStack {
            SellerTheme.lightBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                searchBar
                content
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.onAppear() }
        .sheet(isPresented: $showFilters) {
            filterSheet
                .presentationDetents([.medium])
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
            }
            Text("Registered Sellers")
                .font(.system(size: 22, weight: .semibold))
                .lineLimit(1)
            Spacer()
            Button { viewModel.refresh() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 20, weight: .medium))
            }
            Button {
                if let onHome { onHome() } else { dismiss() }
            } label: {
                Image(systemName: "house.fill")
                    .font(.system(size: 20, weight: .medium))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
        .padding(.top, 10)
        .background(SellerTheme.appBlue.ignoresSafeArea(edges: .top))
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.gray)
                TextField(
                    "Search shop name",
                    text: Binding(
                        get: { viewModel.searchText },
                        set: { viewModel.onSearchChanged($0) }
                    )
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button {
                draftStatus = viewModel.statusFilter
                showFilters = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "wrench")
                    Text("Filters")
                        .font(.system(size: 13, weight: .medium))
                    if viewModel.hasActiveFilters {
                        Circle()
                            .fill(SellerTheme.buttonBlue)
                            .frame(width: 6, height: 6)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.sellers.isEmpty {
            ProgressView()
                .tint(SellerTheme.appBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.sellers.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") { viewModel.refresh() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SellerTheme.buttonBlue)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.sellers.isEmpty {
            Text("No sellers found for selected filters.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.sellers) { seller in
                        SellerListCard(seller: seller) {
                            onOpenSeller("\(seller.id)")
                        }
                        .onAppear { viewModel.loadMoreIfNeeded(current: seller) }
                    }
                    if viewModel.isLoadingMore {
                        ProgressView()
                            .tint(SellerTheme.buttonBlue)
                            .padding(.vertical, 10)
                    }
                }
                .padding(16)
            }
        }
    }

    private var filterSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Filters")
                .font(.system(size: 20, weight: .bold))

            Text("Status")
                .font(.system(size: 15, weight: .semibold))

            HStack(spacing: 10) {
                statusChip("All", value: "")
                statusChip("Active", value: "Active")
                statusChip("Inactive", value: "Inactive")
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    draftStatus = ""
                    viewModel.resetFilters()
                    showFilters = false
                } label: {
                    Text("Reset")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        }
                }

                Button {
                    viewModel.applyStatusFilter(draftStatus)
                    showFilters = false
                } label: {
                    Text("Apply")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(SellerTheme.buttonBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(20)
    }

    private func statusChip(_ title: String, value: String) -> some View {
        Button {
            draftStatus = value
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(draftStatus == value ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(draftStatus == value ? SellerTheme.buttonBlue : Color(hex: "F3F4F6"))
                .clipShape(Capsule())
        }
    }
}

private struct SellerListCard: View {
    let seller: RegisteredSeller
    let onProfile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Text(seller.cardTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "1F2937"))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(seller.statusLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(seller.isActive ? SellerTheme.activeText : Color.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(seller.isActive ? SellerTheme.activeBg : Color.red.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            HStack {
                labeled("Mobile:", seller.mobile.isEmptyString ? "N/A" : seller.mobile)
                Spacer()
                labeled("City:", seller.city.isEmptyString ? "N/A" : seller.city)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            labeled("Beat:", seller.beat.isEmptyString ? "N/A" : seller.beat)
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 14)

            Divider()

            Button(action: onProfile) {
                Text("Profile")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SellerTheme.appBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
    }

    private func labeled(_ label: String, _ value: String) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "374151"))
            Text(" \(value)")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "374151"))
                .lineLimit(1)
        }
    }
}

#Preview {
    NavigationStack {
        SellerListView(onOpenSeller: { _ in })
    }
}
