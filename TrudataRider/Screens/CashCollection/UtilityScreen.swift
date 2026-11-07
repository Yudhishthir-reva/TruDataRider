//
//  UtilityScreen.swift
//  TrudataRider
//
//  The Utility tile's landing screen: one card per tool the signed-in role may use.
//

import SwiftUI

struct UtilityScreen: View {

    @Environment(\.dismiss) private var dismiss

    var onHome: () -> Void

    private let access = CashAccess.current

    var body: some View {
        ZStack {
            CcColors.page.ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Utility",
                    onBack: { dismiss() },
                    onHome: onHome,
                    onRefresh: {}
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        header

                        UtilitySectionLabel(title: "DAILY CASH")

                        NavigationLink {
                            CashCollectionScreen(onHome: onHome)
                        } label: {
                            UtilityTile(
                                title: "Cash Collection",
                                subtitle: access.canReviewAll
                                    ? "Submit cash · Review collections"
                                    : "Submit cash · Track approval",
                                systemImage: "indianrupeesign.circle.fill",
                                accent: CcColors.primary,
                                isFilled: true
                            )
                        }
                        .buttonStyle(.plain)

                        if access.canManageAmountTaken {
                            NavigationLink {
                                AmountTakenScreen(onHome: onHome)
                            } label: {
                                UtilityTile(
                                    title: "Amount Taken",
                                    subtitle: "Record cash out for expenses",
                                    systemImage: "wallet.pass.fill",
                                    accent: Color(hex: "B45309")
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        UtilitySectionLabel(title: "PAYMENTS")

                        NavigationLink {
                            AdvanceListScreen(onHome: onHome)
                        } label: {
                            UtilityTile(
                                title: access.canManageAdvance ? "Payment Advance" : "My Payment Advance",
                                subtitle: access.canManageAdvance
                                    ? "Staff advances & repayments"
                                    : "Your advances & repayments",
                                systemImage: "indianrupeesign.square.fill",
                                accent: Color(hex: "1D4ED8")
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            BillRegisterListScreen(onHome: onHome)
                        } label: {
                            UtilityTile(
                                title: access.canManageBills ? "Bill Register" : "My Bill Register",
                                subtitle: access.canManageBills
                                    ? "Assign & track customer bills"
                                    : "Customer bills assigned to you",
                                systemImage: "doc.text.fill",
                                accent: Color(hex: "7C3AED")
                            )
                        }
                        .buttonStyle(.plain)

                        if access.canViewLedger {
                            UtilitySectionLabel(title: "REPORTS")

                            NavigationLink {
                                LedgerScreen(onHome: onHome)
                            } label: {
                                UtilityTile(
                                    title: "Ledger",
                                    subtitle: "View cash history & staff totals",
                                    systemImage: "book.fill",
                                    accent: Color(hex: "475569")
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
        }
        .navigationBarHidden(true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Cash & payments")
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(CcColors.text)
            Text("Choose the task you need")
                .font(.system(size: 13))
                .foregroundStyle(CcColors.textMuted)
        }
        .padding(.bottom, 6)
    }
}

private struct UtilitySectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(CcColors.textMuted)
            .padding(.leading, 2)
            .padding(.top, 6)
            .padding(.bottom, 1)
    }
}

private struct UtilityTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color
    var isFilled: Bool = false

    private var foreground: Color { isFilled ? .white : accent }

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: systemImage)
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 42, height: 42)
                .background(
                    isFilled ? Color.white.opacity(0.16) : accent.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isFilled ? .white : CcColors.text)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(isFilled ? Color.white.opacity(0.85) : CcColors.textMuted)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)

            Image(systemName: "arrow.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(foreground.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, isFilled ? 17 : 13)
        .frame(maxWidth: .infinity)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isFilled ? Color.clear : accent.opacity(0.14), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var background: some View {
        if isFilled {
            LinearGradient(
                colors: [CcColors.deep, CcColors.primary, CcColors.bright],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            Color.white
        }
    }
}
