//
//  RiderOrderCard.swift
//  TrudataRider
//

import AVFoundation
import SwiftUI

struct RiderOrderCard: View {

    let order: RiderOrder
    var isUpdating: Bool = false
    var onPrimaryAction: () -> Void

    @State private var showDetails = false
    @State private var showHistory = false

    private let appBlue = Color(red: 0.00, green: 0.20, blue: 0.31)
    private let buttonBlue = Color(red: 0.00, green: 0.48, blue: 0.95)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Text(order.shopName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(appBlue)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                statusBadge
            }

            HStack(spacing: 8) {
                infoTag("ID: \(order.orderNo)")
                if !order.date.isEmptyString {
                    infoTag(order.date)
                }
                if !order.displayDistance.isEmptyString {
                    infoTag("Dist: \(order.displayDistance)", emphasized: true)
                }
            }
            .padding(.top, 10)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "mappin")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(appBlue)
                if !order.address.isEmptyString {
                    Text(order.address)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.gray)
                        .lineSpacing(3)
                }
            }
            .padding(.top, 12)

            if showDetails {
                expandedActions
            } else {
                compactActions
            }

            Divider()
                .padding(.top, 16)

            Button {
                withAnimation(.easeInOut) { showDetails.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Spacer()
                    Text(showDetails ? "View Less Details" : "View More Details")
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                }
                .foregroundStyle(.gray)
                .padding(.vertical, 12)
            }

            footer
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
        .opacity(isUpdating ? 0.6 : 1)
        .sheet(isPresented: $showHistory) {
            RemarksHistorySheet(order: order)
        }
    }

    private var statusBadge: some View {
        let pickup = order.status == .assign
        return Text(order.status.title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(pickup ? Color.blue : Color.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(pickup ? Color.blue.opacity(0.10) : Color.yellow.opacity(0.28))
            .clipShape(Capsule())
    }

    private var expandedActions: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                actionButton(title: "Navigate", icon: "location.north.fill", color: buttonBlue, action: openMaps)
                actionButton(title: "Seller", icon: "phone.fill", color: Color(red: 0.16, green: 0.65, blue: 0.27), action: callSeller)
            }
            if order.showStaffButton {
                Button(action: callStaff) {
                    HStack {
                        Image(systemName: "phone.fill")
                        Text("Sales Person: \(order.salesPersonName ?? "Staff")")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(appBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            if order.hasRemarks {
                remarksView
            }
        }
        .padding(.top, 16)
    }

    private var compactActions: some View {
        HStack(spacing: 8) {
            compactButton(title: "Navigate", icon: "location.north.fill", color: buttonBlue, action: openMaps)
            compactButton(title: "Seller", icon: "phone.fill", color: Color(red: 0.16, green: 0.65, blue: 0.27), action: callSeller)
            if order.showStaffButton {
                compactButton(title: "Staff", icon: "phone.fill", color: .gray, action: callStaff)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 14)
    }

    private var remarksView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Remarks")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(appBlue)
                Spacer()
                if !order.remarks.isEmpty {
                    Button("History") { showHistory = true }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.red)
                }
            }
            if !order.remark.isEmptyString {
                Text(order.remark)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            if !order.audioRemark.isEmptyString {
                OrderAudioPlayer(urlString: order.audioRemark)
            }
        }
        .padding(.top, 6)
    }

    @ViewBuilder
    private var footer: some View {
        switch order.status {
        case .assign:
            pickupSlider
        case .pickup:
            collectedFooter
        case .toDeliver:
            SlideToActionBar(title: "Slide to Mark Delivered", isLoading: isUpdating, onComplete: onPrimaryAction)
                .padding(.top, 4)
        case .delivered:
            statusFooter(icon: "checkmark.circle", text: "Delivered")
        default:
            EmptyView()
        }
    }

    private var pickupSlider: some View {
        SlideToActionBar(title: "Slide to Mark as Picked Up", isLoading: isUpdating, onComplete: onPrimaryAction)
            .padding(.top, 4)
    }

    private var collectedFooter: some View {
        statusFooter(icon: "archivebox", text: "Collected. Waiting to start delivery.")
    }

    private func statusFooter(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
            Text(text)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
        }
        .foregroundStyle(appBlue)
        .padding(.top, 6)
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func compactButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    private func infoTag(_ text: String, emphasized: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.gray.opacity(0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.purple.opacity(emphasized ? 0.16 : 0.10))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private func openMaps() {
        if let url = order.mapsURL {
            UIApplication.shared.open(url)
        }
    }

    private func callSeller() {
        call(order.sellerPhone)
    }

    private func callStaff() {
        call(order.staffMobile)
    }

    private func call(_ number: String) {
        let digits = number.filter(\.isNumber)
        guard let url = URL(string: "tel://\(digits)"), !digits.isEmpty else { return }
        UIApplication.shared.open(url)
    }
}

private struct OrderAudioPlayer: View {
    let urlString: String
    @State private var player: AVPlayer?
    @State private var isPlaying = false

    private let appBlue = Color(red: 0.00, green: 0.20, blue: 0.31)

    var body: some View {
        HStack(spacing: 10) {
            Button(action: toggle) {
                Circle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 42, height: 42)
                    .overlay {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .foregroundStyle(appBlue)
                    }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Audio remark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.gray)
                ProgressView(value: isPlaying ? 0.4 : 0.02)
                    .tint(appBlue)
            }
        }
        .padding(12)
        .background(Color.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onDisappear {
            player?.pause()
        }
    }

    private func toggle() {
        if isPlaying {
            player?.pause()
            isPlaying = false
            return
        }
        guard let url = URL(string: urlString) else { return }
        let item = AVPlayer(url: url)
        player = item
        item.play()
        isPlaying = true
    }
}

private struct RemarksHistorySheet: View {
    let order: RiderOrder
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(order.remarks) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.createdBy.isEmptyString ? "Staff" : item.createdBy)
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Text(item.createdAt)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    if !item.remark.isEmptyString {
                        Text(item.remark)
                            .font(.system(size: 14))
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Remarks History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
