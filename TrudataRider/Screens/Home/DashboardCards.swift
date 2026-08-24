//
//  DashboardCards.swift
//  TrudataRider
//

import SwiftUI

enum DashboardTheme {
    static let primaryBlue = Color(hex: "225EC2")
    static let secondaryPurple = Color(hex: "7C3AED")
    static let infoBlue = Color(hex: "3B82F6")
    static let successGreen = Color(hex: "10B981")
    static let warningYellow = Color(hex: "F59E0B")
    static let dangerRed = Color(hex: "EF4444")
    static let pickupOrange = Color(hex: "F97316")
    static let neutralDark = Color(hex: "1F2937")
    static let neutralMedium = Color(hex: "6B7280")
    static let surfaceVariant = Color(hex: "F3F4F6")
    static let cardBackground = Color.white
    static let indigo = Color(hex: "4F46E5")
}

struct DashboardCardChrome<Content: View>: View {
    var cornerRadius: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: DashboardTheme.primaryBlue.opacity(0.05), radius: 8, y: 2)
    }
}

struct DashboardCompactButton: View {
    let title: String
    var color: Color = DashboardTheme.primaryBlue
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SellerProfileSearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DashboardTheme.primaryBlue)
            TextField(placeholder, text: $text)
                .font(.system(size: 14))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.white)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DashboardTheme.primaryBlue.opacity(0.35), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension Double {
    var currencyLabel: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        let text = formatter.string(from: NSNumber(value: self)) ?? "0"
        return "₹\(text)"
    }
}

struct RiderDashboardItemCard: View {
    let item: DashboardItem
    var onNavigate: (String) -> Void

    var body: some View {
        switch item.route {
        case "rider_orders":
            RiderOrdersCard(
                title: item.title,
                statusText: item.payload?["todayOrders"]?.string(for: "desc_string") ?? "No orders",
                onView: { onNavigate(item.route) }
            )
        case "rider_order_history":
            RiderOrderSummaryCard(title: item.title, payload: item.payload, onView: { onNavigate(item.route) })
        case "rider_travel_history":
            RiderTravelHistoryCard(title: item.title, payload: item.payload, onView: { onNavigate(item.route) })
        case "vehicle_overview":
            RiderVehicleOverviewCard(title: item.title, payload: item.payload, onNavigate: onNavigate)
        case "support":
            RiderSupportCard(
                title: item.title,
                salesNumber: item.payload?.string(for: "forSales") ?? "",
                onClick: { onNavigate(item.route) }
            )
        case "registered_sellers":
            RiderSellerSummaryCard(title: item.title, payload: item.payload, onView: { onNavigate(item.route) })
        case "attendance":
            RiderAttendanceCard(title: item.title, payload: item.payload, onView: { onNavigate(item.route) })
        case "regularization_requests":
            RiderCountInfoCard(
                title: item.title,
                subtitle: item.payload?.string(for: "remark", "status") ?? "Regularization",
                pending: item.payload?.int(for: "pendingRegularizeCount") ?? 0,
                total: item.payload?.int(for: "allRegularizeCount") ?? 0,
                today: item.payload?.int(for: "todayRegulizeCount") ?? 0,
                onView: { onNavigate(item.route) }
            )
        case "apply_reimbursements":
            RiderCountInfoCard(
                title: item.title,
                subtitle: item.payload?.string(for: "remark", "status") ?? "Expenses",
                pending: item.payload?.int(for: "pendingExpenseCount") ?? 0,
                total: item.payload?.int(for: "totalExpenseCount") ?? 0,
                today: item.payload?.int(for: "todayExpenseCount") ?? 0,
                onView: { onNavigate(item.route) }
            )
        case "view_leaves":
            RiderCountInfoCard(
                title: item.title,
                subtitle: leaveSubtitle,
                pending: item.payload?.int(for: "pendingLeaveCount") ?? 0,
                total: item.payload?.int(for: "totalLeaveCount") ?? 0,
                today: item.payload?.int(for: "todayLeaveCount") ?? 0,
                onView: { onNavigate(item.route) }
            )
        case "today_achievements":
            RiderTodayAchievementCard(title: item.title, payload: item.payload, onView: { onNavigate(item.route) })
        default:
            EmptyView()
        }
    }

    private var leaveSubtitle: String {
        let start = item.payload?.string(for: "start_date") ?? ""
        let end = item.payload?.string(for: "end_date") ?? ""
        if start.isEmpty && end.isEmpty {
            return item.payload?.string(for: "status") ?? "Leave"
        }
        return "\(start) - \(end)"
    }
}

struct RiderOrdersCard: View {
    let title: String
    let statusText: String
    let onView: () -> Void

    var body: some View {
        RiderCardChrome {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    RiderBulletTitle(title: title)
                    Text(statusText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                RiderCardButton(title: "View", color: DashboardTheme.primaryBlue, action: onView)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

struct RiderOrderSummaryCard: View {
    let title: String
    let payload: JSONValue?
    let onView: () -> Void

    private var counts: [(label: String, value: Int, color: Color)] {
        var map: [String: Int] = [:]
        for row in payload?["summary"]?.arrayValue ?? [] {
            map[row.string(for: "status")] = row.int(for: "count")
        }
        return [
            ("Delivered", map["3"] ?? 0, DashboardTheme.successGreen),
            ("To Deliver", map["1"] ?? 0, DashboardTheme.infoBlue),
            ("Assigned", map["6"] ?? 0, DashboardTheme.primaryBlue),
            ("Pickup", map["2"] ?? 0, DashboardTheme.pickupOrange),
            ("Cancelled", map["4"] ?? 0, DashboardTheme.dangerRed),
            ("Returned", map["5"] ?? 0, DashboardTheme.neutralMedium)
        ]
    }

    private var total: Int { counts.reduce(0) { $0 + $1.value } }

    var body: some View {
        RiderCardChrome(cornerRadius: 24) {
            VStack(spacing: 16) {
                RiderBulletTitle(title: title)
                RiderDonutChart(
                    total: total,
                    label: "Total Orders",
                    segments: counts.filter { $0.value > 0 }.map { ($0.value, $0.color) }
                )
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(counts, id: \.label) { item in
                        HStack(spacing: 8) {
                            Circle().fill(item.color).frame(width: 8, height: 8)
                            Text(item.label)
                                .font(.system(size: 12))
                                .foregroundStyle(DashboardTheme.neutralMedium)
                            Spacer()
                            Text("\(item.value)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DashboardTheme.neutralDark)
                        }
                    }
                }
                Button(action: onView) {
                    Text("View History")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DashboardTheme.primaryBlue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(16)
        }
    }
}

struct RiderTravelHistoryCard: View {
    let title: String
    let payload: JSONValue?
    let onView: () -> Void

    var body: some View {
        let total = payload?.string(for: "total_travelled") ?? "0.0"
        let today = payload?.string(for: "today_travelled") ?? "0.0"
        let failed = payload?.int(for: "failed_orders_count") ?? 0

        return RiderCardChrome(cornerRadius: 24) {
            VStack(spacing: 16) {
                RiderBulletTitle(
                    title: title,
                    colors: [DashboardTheme.primaryBlue, DashboardTheme.successGreen]
                )
                HStack {
                    travelStat(label: "Total Distance", value: "\(total) km", color: DashboardTheme.primaryBlue)
                    Rectangle()
                        .fill(DashboardTheme.neutralMedium.opacity(0.2))
                        .frame(width: 1, height: 40)
                    travelStat(label: "Today's Distance", value: "\(today) km", color: DashboardTheme.successGreen)
                }
                if failed > 0 {
                    HStack {
                        Circle().fill(DashboardTheme.dangerRed).frame(width: 8, height: 8)
                        Text("Failed Orders")
                            .font(.system(size: 13))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                        Spacer()
                        Text("\(failed)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DashboardTheme.dangerRed)
                    }
                    .padding(12)
                    .background(DashboardTheme.dangerRed.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                Button(action: onView) {
                    Text("View Travel History")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DashboardTheme.primaryBlue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(16)
        }
    }

    private func travelStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(DashboardTheme.neutralMedium)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RiderVehicleOverviewCard: View {
    let title: String
    let payload: JSONValue?
    let onNavigate: (String) -> Void

    var body: some View {
        let vehicle = payload?["assignedVehicle"]
        let isPunchIn = payload?.value(for: "isPunchIn")?.boolValue ?? false
        let vehicleId = vehicle?.int(for: "id") ?? 0
        let special = vehicle?.value(for: "enable_special_feature")?.boolValue ?? false
        let name = vehicle?.string(for: "name") ?? ""
        let plate = vehicle?.string(for: "no_plate") ?? ""
        let model = vehicle?.string(for: "modal") ?? ""
        let active = vehicle?.string(for: "status") == "1"

        return RiderCardChrome(cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    RiderBulletTitle(title: title, fontSize: 13)
                    Spacer()
                    Image(systemName: "car.fill")
                        .foregroundStyle(active ? DashboardTheme.successGreen : DashboardTheme.neutralMedium)
                }
                if name.isEmptyString {
                    Text("No vehicle assigned")
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                } else {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                    HStack {
                        if !model.isEmptyString {
                            Text(model).font(.system(size: 11)).foregroundStyle(DashboardTheme.neutralMedium)
                        }
                        if !plate.isEmptyString {
                            Text(plate)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DashboardTheme.neutralDark)
                        }
                    }
                }
                if isPunchIn {
                    Button {
                        onNavigate("vehicle_punch/\(max(vehicleId, 1))/\(special)")
                    } label: {
                        Text("Vehicle Punch")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(DashboardTheme.primaryBlue.opacity(0.4), lineWidth: 1)
                            }
                    }
                }
            }
            .padding(12)
        }
    }
}

struct RiderSupportCard: View {
    let title: String
    let salesNumber: String
    let onClick: () -> Void

    var body: some View {
        RiderCardChrome {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("🚨")
                        Text(title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                    }
                    Text(salesNumber.isEmptyString
                         ? "Get help with app issues or emergencies."
                         : "Call \(salesNumber) for support and emergencies.")
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
                Spacer()
                Button(action: onClick) {
                    HStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                        Text("Emergency")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DashboardTheme.dangerRed)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

struct RiderSellerSummaryCard: View {
    let title: String
    let payload: JSONValue?
    let onView: () -> Void

    var body: some View {
        RiderCardChrome(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 10) {
                RiderBulletTitle(title: title, fontSize: 14)
                HStack {
                    sellerStat("Total", payload?.int(for: "totalSellerCount") ?? 0, DashboardTheme.primaryBlue)
                    sellerStat("Active", payload?.int(for: "activeSellerCount") ?? 0, DashboardTheme.successGreen)
                    sellerStat("Inactive", payload?.int(for: "inactiveSellerCount") ?? 0, DashboardTheme.dangerRed)
                }
                Button("View Sellers", action: onView)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }
            .padding(12)
        }
    }

    private func sellerStat(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.system(size: 16, weight: .bold)).foregroundStyle(color)
            Text(label).font(.system(size: 11)).foregroundStyle(DashboardTheme.neutralMedium)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RiderAttendanceCard: View {
    let title: String
    let payload: JSONValue?
    let onView: () -> Void

    var body: some View {
        let checkIn = payload?.string(for: "in_time") ?? "No data available"
        let checkOut = payload?.string(for: "out_time") ?? "No data available"
        RiderCardChrome(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 10) {
                RiderBulletTitle(title: title, fontSize: 14)
                HStack {
                    timeBlock("In", checkIn, DashboardTheme.successGreen)
                    timeBlock("Out", checkOut, DashboardTheme.dangerRed)
                }
                Button("View Attendance", action: onView)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }
            .padding(12)
        }
    }

    private func timeBlock(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11)).foregroundStyle(DashboardTheme.neutralMedium)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RiderCountInfoCard: View {
    let title: String
    let subtitle: String
    let pending: Int
    let total: Int
    let today: Int
    let onView: () -> Void

    var body: some View {
        RiderCardChrome(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 8) {
                RiderBulletTitle(title: title, fontSize: 14)
                Text(subtitle.isEmptyString ? " " : subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .lineLimit(2)
                HStack {
                    miniStat("Pending", pending, DashboardTheme.pickupOrange)
                    miniStat("Total", total, DashboardTheme.primaryBlue)
                    miniStat("Today", today, DashboardTheme.successGreen)
                }
                Button("View", action: onView)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }
            .padding(12)
        }
    }

    private func miniStat(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.system(size: 15, weight: .bold)).foregroundStyle(color)
            Text(label).font(.system(size: 10)).foregroundStyle(DashboardTheme.neutralMedium)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RiderTodayAchievementCard: View {
    let title: String
    let payload: JSONValue?
    let onView: () -> Void

    private var sellerCount: Int { payload?.int(for: "todaySellerCount") ?? 0 }
    private var collection: String { payload?.string(for: "todayCollectionAmount") ?? "0" }
    private var approved: String { payload?.string(for: "todayApprovedCollectionAmount") ?? "0" }
    private var modes: JSONValue? { payload?["paymentModeWise"] }
    private var amounts: JSONValue? { payload?["paymentModeWiseAmount"] }

    private var totalTransactions: Int {
        (Int(modes?.string(for: "cash") ?? "0") ?? 0)
            + (Int(modes?.string(for: "upi") ?? "0") ?? 0)
            + (Int(modes?.string(for: "cheque") ?? "0") ?? 0)
    }

    var body: some View {
        RiderCardChrome(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(DashboardTheme.primaryBlue)
                        .frame(width: 6, height: 6)
                    Text(title.isEmptyString ? "Today Achievements" : title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                }

                HStack(spacing: 8) {
                    ringStat(value: "\(sellerCount)", label: "Sellers Ordered")
                    ringStat(value: "\(totalTransactions)", label: "Total Collection")
                }

                Divider()

                Text("Today's Collection Summary")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralMedium)

                VStack(spacing: 4) {
                    Text("Total Collection")
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                    Text(rupee(approved.isEmptyString ? collection : approved))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hex: "F3F4F6"))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text("Payment Methods Breakdown")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralMedium)

                paymentRow(
                    icon: "banknote",
                    color: DashboardTheme.successGreen,
                    title: "Cash",
                    count: modes?.string(for: "cash") ?? "0",
                    amount: amounts?.string(for: "cash") ?? "0"
                )
                paymentRow(
                    icon: "doc.text",
                    color: DashboardTheme.primaryBlue,
                    title: "UPI",
                    count: modes?.string(for: "upi") ?? "0",
                    amount: amounts?.string(for: "upi") ?? "0"
                )
                paymentRow(
                    icon: "creditcard",
                    color: Color(hex: "F59E0B"),
                    title: "Cheque",
                    count: modes?.string(for: "cheque") ?? "0",
                    amount: amounts?.string(for: "cheque") ?? "0"
                )

                Button(action: onView) {
                    HStack(spacing: 4) {
                        Text("View Details")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(DashboardTheme.primaryBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .padding(16)
        }
    }

    private func ringStat(value: String, label: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color(hex: "E5E7EB"), lineWidth: 8)
                    .frame(width: 78, height: 78)
                Text(value)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
            }
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func paymentRow(icon: String, color: Color, title: String, count: String, amount: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Text("\(count) transactions")
                    .font(.system(size: 11))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
            Spacer()
            Text(rupee(amount))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(hex: "F3F4F6"))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func rupee(_ value: String) -> String {
        let trimmed = value.trim
        if trimmed.hasPrefix("₹") { return trimmed }
        if let number = Double(trimmed) {
            return String(format: "₹%.0f", number)
        }
        return "₹\(trimmed.isEmpty ? "0" : trimmed)"
    }
}

struct OtherOperationsCard: View {
    let operations: [String]
    let onClick: (String) -> Void

    private let tileColors: [[Color]] = [
        [Color(hex: "E0F7FA"), Color(hex: "B2EBF2")],
        [Color(hex: "E8F5E9"), Color(hex: "C8E6C9")],
        [Color(hex: "FFF3E0"), Color(hex: "FFE0B2")]
    ]

    var body: some View {
        RiderCardChrome(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Circle().fill(DashboardTheme.indigo).frame(width: 6, height: 6)
                    Text("Other Operations")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(operations.enumerated()), id: \.offset) { index, operation in
                        let colors = tileColors[index % tileColors.count]
                        Button {
                            onClick(operation)
                        } label: {
                            Text(operation)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(DashboardTheme.neutralDark)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
            .padding(18)
        }
    }
}

struct RiderCardChrome<Content: View>: View {
    var cornerRadius: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DashboardTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 2)
    }
}

struct RiderBulletTitle: View {
    let title: String
    var fontSize: CGFloat = 16
    var colors: [Color] = [DashboardTheme.primaryBlue, DashboardTheme.secondaryPurple]

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
                .lineLimit(1)
        }
    }
}

struct RiderCardButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

struct RiderDonutChart: View {
    let total: Int
    let label: String
    let segments: [(Int, Color)]

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "E5E7EB"), lineWidth: 14)
            if total > 0 {
                ForEach(Array(segmentAngles.enumerated()), id: \.offset) { _, item in
                    Circle()
                        .trim(from: item.start, to: item.end)
                        .stroke(item.color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
            }
            VStack(spacing: 2) {
                Text("\(total)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
        }
        .frame(width: 140, height: 140)
    }

    private var segmentAngles: [(start: CGFloat, end: CGFloat, color: Color)] {
        guard total > 0 else { return [] }
        var cursor: CGFloat = 0
        let sum = CGFloat(max(segments.reduce(0) { $0 + $1.0 }, 1))
        return segments.map { value, color in
            let start = cursor
            cursor += CGFloat(value) / sum
            return (start, cursor, color)
        }
    }
}
