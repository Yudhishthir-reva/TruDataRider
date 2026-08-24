//
//  SellerDetailView.swift
//  TrudataRider
//

import SwiftUI

struct SellerDetailView: View {

    let sellerId: String
    var onHome: (() -> Void)?
    var onAddPayment: ((String) -> Void)?
    var onBillSettlement: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SellerDetailViewModel

    private let appBlue = Color(red: 0.00, green: 0.20, blue: 0.31)
    private let buttonBlue = Color(red: 0.00, green: 0.48, blue: 0.95)
    private let lightBackground = Color(red: 0.96, green: 0.97, blue: 0.99)
    private let activeBg = Color(red: 0.90, green: 0.98, blue: 0.94)
    private let activeText = Color(red: 0.08, green: 0.50, blue: 0.24)

    init(
        sellerId: String,
        onHome: (() -> Void)? = nil,
        onAddPayment: ((String) -> Void)? = nil,
        onBillSettlement: ((String) -> Void)? = nil
    ) {
        self.sellerId = sellerId
        self.onHome = onHome
        self.onAddPayment = onAddPayment
        self.onBillSettlement = onBillSettlement
        _viewModel = StateObject(wrappedValue: SellerDetailViewModel(sellerId: sellerId))
    }

    var body: some View {
        ZStack {
            lightBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                if viewModel.isLoading && viewModel.profile == nil {
                    ProgressView()
                        .tint(appBlue)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage, viewModel.profile == nil {
                    VStack(spacing: 12) {
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Retry") { viewModel.refresh() }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(buttonBlue)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let profile = viewModel.profile {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            profileCard(profile)
                            actionsSection
                        }
                        .padding(16)
                    }
                }
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
            Text(viewModel.headerTitle)
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
        .background(appBlue.ignoresSafeArea(edges: .top))
    }

    private func profileCard(_ profile: SellerProfileDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                profileAvatar(url: profile.profilePic)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.shopName.isEmptyString ? profile.name : profile.shopName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !profile.name.isEmptyString, profile.name != profile.shopName {
                        Text(profile.name)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                Text(profile.statusLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(profile.isActive ? activeText : .red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(profile.isActive ? activeBg : Color.red.opacity(0.12))
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                if profile.mailURL != nil {
                    actionCircle(icon: "envelope.fill") {
                        if let url = profile.mailURL { UIApplication.shared.open(url) }
                    }
                }
                if profile.mapsURL != nil {
                    actionCircle(icon: "mappin") {
                        if let url = profile.mapsURL { UIApplication.shared.open(url) }
                    }
                }
                if profile.callURL != nil {
                    actionCircle(icon: "phone.fill") {
                        if let url = profile.callURL { UIApplication.shared.open(url) }
                    }
                }
            }

            if viewModel.showDetails {
                VStack(alignment: .leading, spacing: 10) {
                    detailRow(icon: "envelope", label: "Contact", value: profile.email.isEmptyString ? "N/A" : profile.email)
                    detailRow(icon: "mappin", label: "Address", value: profile.address.isEmptyString ? "N/A" : profile.address)
                    detailRow(icon: "person.text.rectangle", label: "Seller ID", value: profile.sellerCode.isEmptyString ? "N/A" : profile.sellerCode)
                }
            }

            Button {
                withAnimation(.easeInOut) { viewModel.showDetails.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Spacer()
                    Text(viewModel.showDetails ? "Hide Details" : "Show Details")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: viewModel.showDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Actions")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(buttonBlue)
                Spacer()
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(buttonBlue)
                    .frame(height: 2)
                    .frame(maxWidth: 70, alignment: .leading)
            }

            actionCard(
                title: "Add Payment",
                description: "Add amount paid in cash here to settle...",
                button: "Go to Add Payment"
            ) {
                onAddPayment?(sellerId)
            }

            actionCard(
                title: "Bill Settlement",
                description: "Settle your bills here...",
                button: "Go to Bill Settlement"
            ) {
                onBillSettlement?(sellerId)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func actionCard(
        title: String,
        description: String,
        button: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle().fill(appBlue).frame(width: 6, height: 6)
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(appBlue)
            }
            Text(description)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Button(action: action) {
                HStack {
                    Image(systemName: "checkmark.square")
                    Text(button)
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(buttonBlue)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(buttonBlue.opacity(0.55), lineWidth: 1)
                }
            }
        }
        .padding(14)
        .background(Color(hex: "F8FAFC"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func profileAvatar(url: String) -> some View {
        Group {
            if !url.isEmptyString {
                RemoteImage(url: url)
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(hex: "E5E7EB"))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.gray)
                    }
            }
        }
    }

    private func actionCircle(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(buttonBlue.opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(buttonBlue)
                }
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SellerDetailView(sellerId: "1")
    }
}
