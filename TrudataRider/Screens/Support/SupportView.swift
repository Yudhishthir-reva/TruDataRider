//
//  SupportView.swift
//  TrudataRider
//
//  Created by Reva on 21/08/26.
//

import SwiftUI

struct SupportView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SupportViewModel

    var onBack: (() -> Void)?
    var onHome: (() -> Void)?

    private let screenBackground = Color(hex: "F4F6F9")

    init(
        salesNumber: String? = nil,
        riderNumber: String? = nil,
        onBack: (() -> Void)? = nil,
        onHome: (() -> Void)? = nil
    ) {
        self.onBack = onBack
        self.onHome = onHome
        _viewModel = StateObject(
            wrappedValue: SupportViewModel(
                salesNumber: salesNumber,
                riderNumber: riderNumber
            )
        )
    }

    var body: some View {
        ZStack {
            screenBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                appBar
                mainContent
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.onAppear()
        }
    }

    // MARK: - App Bar

    private var appBar: some View {
        HStack(spacing: 14) {
            Button {
                if let onBack {
                    onBack()
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            Text(viewModel.headerTitle)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Button {
                if let onHome {
                    onHome()
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "house.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(AppTheme.darkMidnightBlue.ignoresSafeArea(edges: .top))
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(viewModel.contacts) { contact in
                        supportContactCard(contact)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }

            Spacer(minLength: 16)

            emergencyNoteBanner
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
        }
    }

    // MARK: - Support Card

    private func supportContactCard(_ contact: SupportContactItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: contact.type.titleColor))

                Text(contact.description)
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundStyle(Color(hex: contact.type.subtitleColor))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                viewModel.callContact(contact)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color(hex: "374151"))
                        .rotationEffect(.degrees(0))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.formattedNumber)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(hex: "111827"))

                        Text("Tap to call")
                            .font(.system(size: 12.5, weight: .regular))
                            .foregroundStyle(Color(hex: "6B7280"))
                    }

                    Spacer()

                    Circle()
                        .fill(Color(hex: contact.type.buttonColor))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white)
                }
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: contact.type.cardBackgroundColor))
        }
    }

    // MARK: - Emergency Note Banner

    private var emergencyNoteBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("⚠️ \(viewModel.noteText)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "B91C1C"))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "FEE2E2"))
        }
    }
}

private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    SupportView()
}
