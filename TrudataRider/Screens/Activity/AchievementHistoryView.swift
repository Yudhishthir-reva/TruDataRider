//
//  AchievementHistoryView.swift
//  TrudataRider
//

import SwiftUI

private enum ActivityTheme {
    static let appBlue = Color(red: 0.00, green: 0.20, blue: 0.31)
    static let buttonBlue = Color(red: 0.00, green: 0.48, blue: 0.95)
    static let lightBackground = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let chipGray = Color(red: 0.95, green: 0.95, blue: 0.96)
}

struct AchievementHistoryView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AchievementHistoryViewModel()
    var onHome: (() -> Void)?

    var body: some View {
        ZStack {
            ActivityTheme.lightBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                filterPanel
                modeToggle
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
            Text("Achievement Insights")
                .font(.system(size: 20, weight: .semibold))
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
        .background(ActivityTheme.appBlue.ignoresSafeArea(edges: .top))
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Date Presets")
                .font(.system(size: 14, weight: .semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DeliveryHistoryDatePreset.selectable) { preset in
                        Button { viewModel.selectPreset(preset) } label: {
                            Text(preset.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(viewModel.selectedPreset == preset ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(viewModel.selectedPreset == preset ? ActivityTheme.buttonBlue : ActivityTheme.chipGray)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            HStack(spacing: 12) {
                dateField(viewModel.parsedDate(from: viewModel.startDate)) { viewModel.updateStartDate($0) }
                dateField(viewModel.parsedDate(from: viewModel.endDate)) { viewModel.updateEndDate($0) }
            }
        }
        .padding(16)
        .background(Color.white)
    }

    private func dateField(_ date: Date, onChange: @escaping (Date) -> Void) -> some View {
        HStack {
            DatePicker("", selection: Binding(get: { date }, set: onChange), displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 4) {
            ForEach(AchievementViewMode.allCases) { mode in
                Button {
                    withAnimation { viewModel.viewMode = mode }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode == .report ? "chart.bar.fill" : "list.bullet")
                        Text(mode.rawValue)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(viewModel.viewMode == mode ? ActivityTheme.buttonBlue : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(viewModel.viewMode == mode ? Color.white : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(4)
        .background(ActivityTheme.chipGray)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.data == nil {
            ProgressView().tint(ActivityTheme.appBlue).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.data == nil {
            VStack(spacing: 12) {
                Text(error).multilineTextAlignment(.center).foregroundStyle(.secondary)
                Button("Retry") { viewModel.refresh() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ActivityTheme.buttonBlue)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let data = viewModel.data {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if viewModel.viewMode == .report {
                        reportContent(data)
                    } else {
                        listContent(data)
                    }
                }
                .padding(16)
            }
        }
    }

    private func reportContent(_ data: AchievementHistoryData) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            summaryRow(data)
            if !data.sellerOrderCounts.isEmpty {
                sectionCard(title: "Top Sellers by Orders") {
                    ForEach(data.sellerOrderCounts.prefix(10)) { item in
                        leaderRow(item.sellerName, "\(item.orderCount)")
                    }
                }
            }
            if !data.sellerCollections.isEmpty {
                sectionCard(title: "Top Sellers by Collection") {
                    ForEach(data.sellerCollections.prefix(10)) { item in
                        leaderRow(item.sellerName, rupee(item.totalAmount))
                    }
                }
            }
            if !data.aggregatedPaymentModes.isEmpty {
                sectionCard(title: "Collections by Payment Mode") {
                    ForEach(data.aggregatedPaymentModes) { item in
                        leaderRow(item.label.capitalized, rupee(item.totalAmount))
                    }
                }
            }
        }
    }

    private func listContent(_ data: AchievementHistoryData) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionCard(title: "Seller Orders") {
                ForEach(data.sellerOrderCounts) { item in
                    leaderRow(item.sellerName, "\(item.orderCount) orders")
                }
            }
            sectionCard(title: "Seller Collections") {
                ForEach(data.sellerCollections) { item in
                    leaderRow(item.sellerName, rupee(item.totalAmount))
                }
            }
            sectionCard(title: "Payment Modes") {
                ForEach(data.paymentModeStats.indices, id: \.self) { index in
                    let item = data.paymentModeStats[index]
                    let label = data.paymentModeMap[item.paymentModeId] ?? "Mode"
                    leaderRow("\(item.sellerName) • \(label)", rupee(item.totalAmount))
                }
            }
        }
    }

    private func summaryRow(_ data: AchievementHistoryData) -> some View {
        HStack(spacing: 12) {
            summaryTile("Sellers", "\(data.totalSellersOrdered)", ActivityTheme.buttonBlue)
            summaryTile("Collection", rupee(data.totalCollection), Color.green)
        }
    }

    private func summaryTile(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.system(size: 20, weight: .bold)).foregroundStyle(color)
            Text(title).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 15, weight: .bold))
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func leaderRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(ActivityTheme.buttonBlue)
        }
        .padding(.vertical, 4)
    }

    private func rupee(_ value: Double) -> String {
        String(format: "₹%.0f", value)
    }
}

#Preview {
    NavigationStack { AchievementHistoryView() }
}
