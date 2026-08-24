//
//  TravelHistoryView.swift
//  TrudataRider
//

import SwiftUI

private enum TravelTheme {
    static let appBlue = Color(red: 0.00, green: 0.20, blue: 0.31)
    static let buttonBlue = Color(red: 0.00, green: 0.48, blue: 0.95)
    static let lightBackground = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let chipGray = Color(red: 0.95, green: 0.95, blue: 0.96)
    static let successGreen = Color(red: 0.13, green: 0.65, blue: 0.35)
}

struct TravelHistoryView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TravelHistoryViewModel()

    var onHome: (() -> Void)?

    var body: some View {
        ZStack {
            TravelTheme.lightBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                filterPanel
                if viewModel.travelData != nil {
                    tabBar
                }
                content
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.onAppear() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
            }

            Text("Travel History")
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
        .background(TravelTheme.appBlue.ignoresSafeArea(edges: .top))
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                                    ? TravelTheme.buttonBlue
                                    : TravelTheme.chipGray
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Text("Custom Range")
                .font(.system(size: 15, weight: .semibold))

            HStack(spacing: 12) {
                dateField(date: viewModel.parsedDate(from: viewModel.startDate)) {
                    viewModel.updateStartDate($0)
                }
                dateField(date: viewModel.parsedDate(from: viewModel.endDate)) {
                    viewModel.updateEndDate($0)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
    }

    private func dateField(date: Date, onChange: @escaping (Date) -> Void) -> some View {
        HStack {
            DatePicker(
                "",
                selection: Binding(get: { date }, set: onChange),
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

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(TravelHistoryTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedTab = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(viewModel.selectedTab == tab ? .white : TravelTheme.appBlue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            viewModel.selectedTab == tab
                            ? TravelTheme.appBlue
                            : Color.blue.opacity(0.08)
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(Color.white)
        .clipShape(Capsule())
        .overlay {
            Capsule().stroke(Color.gray.opacity(0.12), lineWidth: 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.travelData == nil {
            ProgressView()
                .tint(TravelTheme.appBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.travelData == nil {
            VStack(spacing: 12) {
                Text(error)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") { viewModel.retry() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TravelTheme.buttonBlue)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let data = viewModel.travelData {
            ScrollView(showsIndicators: false) {
                Group {
                    switch viewModel.selectedTab {
                    case .overview:
                        travelOverview(data)
                    case .failedOrders:
                        failedOrders(data.failedOrders)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        } else {
            Text("No travel history found for the selected date range.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func travelOverview(_ data: RiderTravelHistoryData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                summaryCard(
                    icon: "car.fill",
                    color: TravelTheme.buttonBlue,
                    value: data.totalDistanceLabel,
                    title: "Total Distance"
                )
                summaryCard(
                    icon: "mappin.circle.fill",
                    color: TravelTheme.successGreen,
                    value: data.todayDistanceLabel,
                    title: "Today's Distance"
                )
            }

            Text("Seller-wise Travel Details")
                .font(.system(size: 17, weight: .bold))
                .padding(.top, 4)

            if data.sellerWiseTravelled.isEmpty {
                Text("No seller-wise travel data available.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                ForEach(data.sellerWiseTravelled) { seller in
                    SellerTravelCard(seller: seller)
                }
            }
        }
    }

    private func failedOrders(_ orders: [TravelFailedOrder]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if orders.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(TravelTheme.successGreen)
                    Text("No Failed Orders")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(TravelTheme.successGreen)
                    Text("Great job! All your deliveries were successful.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
            } else {
                Text("Failed Orders (\(orders.count))")
                    .font(.system(size: 17, weight: .bold))

                ForEach(orders) { order in
                    FailedOrderCard(order: order)
                }
            }
        }
    }

    private func summaryCard(icon: String, color: Color, value: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .bold))
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

// MARK: - Cards

private struct SellerTravelCard: View {
    let seller: SellerWiseTravel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(seller.title)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(2)
                Spacer(minLength: 8)
                Text(seller.distanceLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(TravelTheme.buttonBlue)
            }

            detailRow(icon: "storefront", label: "Shop", value: seller.shopName.isEmptyString ? "N/A" : seller.shopName)
            detailRow(icon: "person", label: "Seller", value: seller.sellerName.isEmptyString ? "N/A" : seller.sellerName)
        }
        .padding(.leading, 16)
        .padding([.top, .bottom, .trailing], 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 12,
                bottomLeadingRadius: 12,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(TravelTheme.buttonBlue)
            .frame(width: 4)
        }
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.gray)
                .frame(width: 14)
            Text("\(label):")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}

private struct FailedOrderCard: View {
    let order: TravelFailedOrder

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(order.orderId)
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Text(order.displayDate)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            detailRow(icon: "storefront", label: "Seller", value: order.sellerName)
            detailRow(icon: "exclamationmark.circle", label: "Remark", value: order.remark.isEmptyString ? "No remark" : order.remark)
            detailRow(icon: "mappin", label: "Lat", value: "\(order.latitude)")
            detailRow(icon: "mappin", label: "Lng", value: "\(order.longitude)")

            if order.mapsURL != nil {
                Button {
                    if let url = order.mapsURL {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                        Text("View Location")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.red.opacity(0.7), lineWidth: 1)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.leading, 16)
        .padding([.top, .bottom, .trailing], 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 12,
                bottomLeadingRadius: 12,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(Color.red)
            .frame(width: 4)
        }
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.gray)
                .frame(width: 14)
            Text("\(label):")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    NavigationStack {
        TravelHistoryView()
    }
}
