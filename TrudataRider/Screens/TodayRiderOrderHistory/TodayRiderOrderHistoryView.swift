//
//  TodayRiderOrderHistoryView.swift
//  TrudataRider
//

import SwiftUI

private enum HistoryTheme {
    static let appBlue = Color(red: 0.00, green: 0.20, blue: 0.31)
    static let buttonBlue = Color(red: 0.00, green: 0.48, blue: 0.95)
    static let lightBackground = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let chipGray = Color(red: 0.95, green: 0.95, blue: 0.96)
}

struct TodayRiderOrderHistoryView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TodayRiderOrderHistoryViewModel()
    @State private var showFilters = false
    @State private var draftStatus = ""

    var onHome: (() -> Void)?

    var body: some View {
        ZStack {
            HistoryTheme.lightBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                filterPanel
                listContent
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.onAppear() }
        .sheet(isPresented: $showFilters) {
            MoreFiltersSheet(
                summaries: viewModel.statusFilters,
                selectedStatus: $draftStatus,
                onReset: {
                    draftStatus = ""
                    viewModel.resetFilters()
                    showFilters = false
                },
                onApply: {
                    viewModel.applyFilters(status: draftStatus)
                    showFilters = false
                },
                onClose: { showFilters = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
            }

            Text("Delivery History")
                .font(.system(size: 22, weight: .semibold))
                .lineLimit(1)

            Spacer()

            Button { viewModel.refresh() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 20, weight: .medium))
            }

            Button {
                if let onHome {
                    onHome()
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "house.fill")
                    .font(.system(size: 20, weight: .medium))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
        .padding(.top, 10)
        .background(HistoryTheme.appBlue.ignoresSafeArea(edges: .top))
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.gray)
                TextField(
                    "Search by Order ID (#123456)...",
                    text: Binding(
                        get: { viewModel.orderIdSearch },
                        set: { viewModel.onSearchChanged($0) }
                    )
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 3, y: 1)

            Button {
                draftStatus = viewModel.orderStatus
                showFilters = true
            } label: {
                HStack {
                    Spacer()
                    Text("More Filters")
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                }
                .foregroundStyle(Color.primary.opacity(0.75))
                .padding(.vertical, 12)
                .background(HistoryTheme.chipGray)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Text("Date Presets")
                .font(.system(size: 15, weight: .semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DeliveryHistoryDatePreset.selectable) { preset in
                        Button {
                            viewModel.selectPreset(preset)
                        } label: {
                            Text(preset.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(viewModel.selectedPreset == preset ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    viewModel.selectedPreset == preset
                                    ? HistoryTheme.buttonBlue
                                    : HistoryTheme.chipGray
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Text("Custom Range")
                .font(.system(size: 15, weight: .semibold))

            HStack(spacing: 12) {
                dateField(
                    title: "Start",
                    date: viewModel.parsedDate(from: viewModel.startDate)
                ) { viewModel.updateStartDate($0) }

                dateField(
                    title: "End",
                    date: viewModel.parsedDate(from: viewModel.endDate)
                ) { viewModel.updateEndDate($0) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
    }

    private func dateField(title: String, date: Date, onChange: @escaping (Date) -> Void) -> some View {
        HStack {
            DatePicker(
                title,
                selection: Binding(
                    get: { date },
                    set: onChange
                ),
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if viewModel.isLoading && viewModel.orders.isEmpty {
            ProgressView()
                .tint(HistoryTheme.appBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.orders.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") { viewModel.retry() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HistoryTheme.buttonBlue)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.orders.isEmpty {
            Text("No delivery history found for the selected filters.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    Text("Total Deliveries: \(viewModel.totalDeliveries)")
                        .font(.system(size: 17, weight: .bold))
                        .padding(.top, 4)

                    ForEach(viewModel.orders) { order in
                        DeliveryHistoryCard(order: order)
                            .onAppear { viewModel.loadMoreIfNeeded(currentItem: order) }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .tint(HistoryTheme.buttonBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }
}

// MARK: - Card

private struct DeliveryHistoryCard: View {
    let order: DeliveryHistoryOrder

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(order.orderNumber)
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text(order.orderDate)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            detailRow(icon: "storefront", label: "Seller", value: order.sellerShopName)
            detailRow(icon: "mappin", label: "Address", value: order.sellerAddress)
            detailRow(icon: "calendar", label: "Delivered", value: order.displayDeliveryDate)
            detailRow(icon: "location", label: "Distance", value: order.displayDistance)

            HStack {
                Text(statusTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(statusColor)
                Spacer()
                Button {
                    if let url = order.mapsURL {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "mappin.and.ellipse")
                        Text("View on Map")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(HistoryTheme.buttonBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(HistoryTheme.buttonBlue.opacity(0.55), lineWidth: 1)
                    }
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(statusColor)
                .frame(width: 5)
        }
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.gray)
                .frame(width: 16)
            Text("\(label):")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }

    private var statusTitle: String {
        switch order.status.lowercased() {
        case "delivered": return "Delivered"
        case "to deliver": return "To Deliver"
        case "pickup": return "Pickup"
        case "cancel": return "Cancelled"
        case "return": return "Returned"
        case "assign": return "Assigned"
        default: return order.status.isEmptyString ? "Unknown" : order.status
        }
    }

    private var statusColor: Color {
        switch order.status.lowercased() {
        case "delivered": return Color(red: 0.13, green: 0.65, blue: 0.35)
        case "to deliver": return HistoryTheme.buttonBlue
        case "pickup": return Color(red: 0.99, green: 0.49, blue: 0.08)
        case "cancel": return .red
        case "return": return .purple
        case "assign": return HistoryTheme.buttonBlue
        default: return .gray
        }
    }
}

// MARK: - More Filters

private struct MoreFiltersSheet: View {
    let summaries: [DeliveryHistorySummary]
    @Binding var selectedStatus: String
    let onReset: () -> Void
    let onApply: () -> Void
    let onClose: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 110), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("More Filters")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                        .background(HistoryTheme.chipGray)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Order Status")
                        .font(.system(size: 17, weight: .semibold))

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                        ForEach(summaries) { item in
                            let selected = selectedStatus == item.statusId
                            Button {
                                selectedStatus = selected ? "" : item.statusId
                            } label: {
                                Text("\(item.label) (\(item.count))")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(selected ? .white : .primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(selected ? HistoryTheme.buttonBlue : HistoryTheme.chipGray)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(18)
            }

            HStack(spacing: 12) {
                Button(action: onReset) {
                    Text("Reset")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.gray.opacity(0.45), lineWidth: 1)
                        }
                }

                Button(action: onApply) {
                    Text("Apply Filters")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(HistoryTheme.buttonBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 20)
            .padding(.top, 8)
        }
        .background(Color.white)
    }
}

#Preview {
    NavigationStack {
        TodayRiderOrderHistoryView()
    }
}
