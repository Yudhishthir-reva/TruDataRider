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
    var onMarkNotAvailable: (() -> Void)? = nil

    @State private var showDetails = false
    @State private var showHistory = false

    private let appBlue = Color(red: 0.00, green: 0.20, blue: 0.31)
    private let buttonBlue = Color(red: 0.00, green: 0.48, blue: 0.95)
    private let sellerGreen = Color(red: 0.16, green: 0.65, blue: 0.27)
    private let alertRed = Color(red: 0.85, green: 0.20, blue: 0.20)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Shop Name & Status Badge
            HStack(alignment: .top, spacing: 10) {
                Text(order.shopName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(appBlue)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                statusBadge
            }

            // Info tags: ID, Date, Dist
            HStack(spacing: 8) {
                let idText = order.orderNo.hasPrefix("#") ? order.orderNo : "#\(order.orderNo)"
                infoTag("ID: \(idText)")
                if !order.date.isEmptyString {
                    infoTag(order.date)
                }
                if !order.displayDistance.isEmptyString {
                    infoTag("Dist: \(order.displayDistance)")
                }
            }
            .padding(.top, 10)

            // Address
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "mappin")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(appBlue)
                    .padding(.top, 2)
                if !order.address.isEmptyString {
                    Text(order.address)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Color.primary.opacity(0.75))
                        .lineSpacing(3)
                }
            }
            .padding(.top, 12)

            // Actions row (Compact vs Expanded)
            if showDetails {
                expandedActions
            } else {
                compactActions
            }

            Divider()
                .padding(.top, 14)

            // View More / Less Details Toggle
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showDetails.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Spacer()
                    Text(showDetails ? "View Less Details" : "View More Details")
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                }
                .foregroundStyle(appBlue)
                .padding(.vertical, 12)
            }

            // Remarks section (when expanded)
            if showDetails && order.hasRemarks {
                remarksView
                    .padding(.bottom, 12)
            }

            // Seller Not Available section
            if order.status == .toDeliver || order.status == .assign {
                sellerNotAvailableRow
                    .padding(.bottom, 12)
            }

            // Footer / Action Slider
            footer
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .opacity(isUpdating ? 0.6 : 1)
        .sheet(isPresented: $showHistory) {
            RemarksHistorySheet(order: order)
        }
    }

    private var statusBadge: some View {
        let isDelivered = order.status == .delivered
        let isToDeliver = order.status == .toDeliver
        let isPickup = order.status == .assign

        let (text, textColor, bgColor): (String, Color, Color) = {
            if isToDeliver {
                return ("Out for Delivery", Color(red: 0.15, green: 0.55, blue: 0.35), Color(red: 0.85, green: 0.95, blue: 0.90))
            } else if isDelivered {
                return ("Delivered", Color(red: 0.15, green: 0.55, blue: 0.35), Color(red: 0.85, green: 0.95, blue: 0.90))
            } else if isPickup {
                return ("To Pick Up", buttonBlue, buttonBlue.opacity(0.12))
            } else {
                return (order.status.title, Color.orange, Color.yellow.opacity(0.25))
            }
        }()

        return Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(bgColor)
            .clipShape(Capsule())
    }

    private var expandedActions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                actionButton(title: "Navigate", icon: "location.north.fill", color: buttonBlue, action: openMaps)
                actionButton(title: "Seller", icon: "phone.fill", color: sellerGreen, action: callSeller)
            }
            if order.showStaffButton {
                Button(action: callStaff) {
                    HStack(spacing: 8) {
                        Image(systemName: "phone.fill")
                        Text("Sales Person: \(order.salesPersonName ?? "Staff")")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(appBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(.top, 14)
    }

    private var compactActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                compactButton(title: "Navigate", icon: "location.north.fill", color: buttonBlue, bgColor: buttonBlue.opacity(0.10), action: openMaps)
                compactButton(title: "Seller", icon: "phone.fill", color: sellerGreen, bgColor: sellerGreen.opacity(0.10), action: callSeller)
                if order.showStaffButton {
                    compactButton(title: "Staff", icon: "phone.fill", color: appBlue, bgColor: Color(red: 0.93, green: 0.95, blue: 0.96), action: callStaff)
                }
                Spacer(minLength: 0)
            }

            if order.hasRemarks {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { showDetails = true }
                } label: {
                    Text("Contains Special Note")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(alertRed)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(alertRed.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(alertRed.opacity(0.6), lineWidth: 1)
                        }
                }
                .padding(.top, 2)
            }
        }
        .padding(.top, 14)
    }

    private var remarksView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Remarks")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(appBlue)
                Spacer()
                if !order.remarks.isEmpty {
                    Button("History") { showHistory = true }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(alertRed)
                }
            }
            if !order.remark.isEmptyString {
                Text(order.remark)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.primary.opacity(0.75))
            }
            if !order.audioRemark.isEmptyString {
                OrderAudioPlayer(urlString: order.audioRemark)
            }
        }
        .padding(.top, 2)
    }

    private var sellerNotAvailableRow: some View {
        HStack {
            Text("Seller Not Available?")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.secondary)

            Spacer()

            Button {
                if let onMarkNotAvailable {
                    onMarkNotAvailable()
                }
            } label: {
                Text("Mark Not Available")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(alertRed)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(alertRed.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch order.status {
        case .assign:
            pickupSlider
        case .pickup:
            collectedFooter
        case .toDeliver:
            SlideToActionBar(title: "Slide to Mark as Delivered", isLoading: isUpdating, onComplete: onPrimaryAction)
                .padding(.top, 2)
        case .delivered:
            statusFooter(icon: "checkmark.circle.fill", text: "Delivered")
        default:
            EmptyView()
        }
    }

    private var pickupSlider: some View {
        SlideToActionBar(title: "Slide to Mark as Picked Up", isLoading: isUpdating, onComplete: onPrimaryAction)
            .padding(.top, 2)
    }

    private var collectedFooter: some View {
        statusFooter(icon: "archivebox.fill", text: "Collected. Waiting to start delivery.")
    }

    private func statusFooter(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 17))
            Text(text)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
        }
        .foregroundStyle(appBlue)
        .padding(.top, 4)
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
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func compactButton(title: String, icon: String, color: Color, bgColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(bgColor)
            .clipShape(Capsule())
        }
    }

    private func infoTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(Color.primary.opacity(0.75))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(red: 0.94, green: 0.91, blue: 0.98))
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
    @State private var currentTime: Double = 0
    @State private var duration: Double = 1.0
    @State private var timeObserver: Any?

    private let appBlue = Color(red: 0.00, green: 0.20, blue: 0.31)

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                Circle()
                    .fill(Color(red: 0.90, green: 0.92, blue: 0.95))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(appBlue)
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    // Waveform dots visualization
                    HStack(spacing: 4) {
                        ForEach(0..<16, id: \.self) { _ in
                            Circle()
                                .fill(Color.gray.opacity(0.4))
                                .frame(width: 3, height: 3)
                        }
                    }

                    Spacer()

                    Text(formattedTime(currentTime) + " / " + formattedTime(duration))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.8))
                }

                // Progress Bar with Knob
                GeometryReader { geo in
                    let progress = duration > 0 ? CGFloat(currentTime / duration) : 0
                    let trackWidth = geo.size.width
                    let knobOffset = max(0, min(progress * trackWidth, trackWidth))

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.20))
                            .frame(height: 5)

                        Capsule()
                            .fill(appBlue)
                            .frame(width: knobOffset, height: 5)

                        Circle()
                            .fill(appBlue)
                            .frame(width: 10, height: 10)
                            .offset(x: max(0, knobOffset - 5))
                    }
                }
                .frame(height: 10)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(red: 0.95, green: 0.95, blue: 0.98))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onDisappear {
            player?.pause()
            removeObserver()
        }
    }

    private func formattedTime(_ seconds: Double) -> String {
        let secs = Int(seconds)
        return String(format: "%02d:%02d", secs / 60, secs % 60)
    }

    private func toggle() {
        if isPlaying {
            player?.pause()
            isPlaying = false
            return
        }

        if player == nil {
            guard let url = URL(string: urlString) else { return }
            let item = AVPlayerItem(url: url)
            let newPlayer = AVPlayer(playerItem: item)
            player = newPlayer

            // Observe duration
            Task {
                if let dur = try? await item.asset.load(.duration) {
                    let totalSecs = dur.seconds
                    if totalSecs.isFinite && totalSecs > 0 {
                        await MainActor.run {
                            self.duration = totalSecs
                        }
                    }
                }
            }

            // Periodic time observer
            let interval = CMTime(seconds: 0.2, preferredTimescale: 600)
            timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                self.currentTime = time.seconds
            }

            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { _ in
                self.isPlaying = false
                self.currentTime = 0
                self.player?.seek(to: .zero)
            }
        }

        player?.play()
        isPlaying = true
    }

    private func removeObserver() {
        if let observer = timeObserver, let player {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
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
