//
//  DenominationFormView.swift
//  TrudataRider
//
//  Android `DenominationForm`: the declared total plus the count of each note and coin, with the
//  running total checked against the declared amount. The server rejects a submission whose counts
//  don't add up to the declared total, so the mismatch is shown here, before anything is sent.
//

import SwiftUI

struct DenominationFormView: View {

    let declaredText: String
    let counts: DenominationCounts
    var declaredError: String?
    var onDeclaredChange: (String) -> Void
    var onCountChange: (Denomination, Int) -> Void

    private var declared: Int { Int(declaredText) ?? 0 }
    private var counted: Int { counts.cashTotal }

    var body: some View {
        VStack(spacing: 10) {
            totalSection
            MatchBanner(
                declared: declared,
                counted: counted,
                notes: counts.pieces(ofKind: .note),
                coins: counts.pieces(ofKind: .coin)
            )
            CashSection(title: "Notes", systemImage: "banknote", subtitle: "Tap a count to type it") {
                table(Denomination.notes)
            }
            CashSection(title: "Coins", systemImage: "indianrupeesign.circle", accent: CcColors.warn) {
                table(Denomination.coins)
            }
        }
    }

    // MARK: - Declared total

    private var totalSection: some View {
        CashSection(title: "Total cash amount", systemImage: "indianrupeesign", subtitle: "The cash you are handing over") {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("₹")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(CcColors.textMuted)

                    TextField("", text: Binding(get: { declaredText }, set: onDeclaredChange), prompt: Text("0").foregroundStyle(Color(hex: "D1D5DB")))
                        .keyboardType(.numberPad)
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(CcColors.text)
                        .tint(CcColors.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(fieldBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(fieldBorder, lineWidth: 1))

                let words = CashFormat.amountInWords(declared)
                if !words.isEmpty {
                    Text(words)
                        .font(.system(size: 11.5))
                        .foregroundStyle(CcColors.textMuted)
                }

                if let declaredError {
                    Text(declaredError)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(CcColors.err)
                }
            }
        }
    }

    private var fieldBackground: Color {
        if declaredError != nil { return CcColors.errBg }
        return declaredText.isEmpty ? Color(hex: "F5F5F5") : .white
    }

    private var fieldBorder: Color {
        if declaredError != nil { return CcColors.err }
        return declaredText.isEmpty ? Color(hex: "D1D5DB") : CcColors.bright
    }

    // MARK: - Tables

    private func table(_ denominations: [Denomination]) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Text("Currency").frame(width: 70, alignment: .leading)
                Text("Quantity").frame(maxWidth: .infinity, alignment: .center)
                Text("Total").frame(width: 84, alignment: .trailing)
            }
            .font(.system(size: 11))
            .foregroundStyle(CcColors.textFaint)

            ForEach(denominations) { denomination in
                DenominationRow(
                    denomination: denomination,
                    count: counts[denomination] ?? 0,
                    onChange: { onCountChange(denomination, $0) }
                )
            }
        }
    }
}

// MARK: - Match banner

private struct MatchBanner: View {
    let declared: Int
    let counted: Int
    let notes: Int
    let coins: Int

    private var style: (background: Color, foreground: Color, icon: String, text: String) {
        let diff = counted - declared
        if declared == 0 && counted == 0 {
            return (CcColors.track, CcColors.textMuted, "indianrupeesign", "Enter the total, then count each note and coin")
        }
        if diff == 0 {
            return (CcColors.okBg, CcColors.ok, "checkmark.circle.fill", "Counts match the total")
        }
        if diff < 0 {
            return (CcColors.warnBg, CcColors.warn, "exclamationmark.triangle", "Short by \(CashFormat.rupees(-diff))")
        }
        return (CcColors.errBg, CcColors.err, "exclamationmark.triangle", "Counts are \(CashFormat.rupees(diff)) over the total")
    }

    var body: some View {
        let style = style
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: style.icon)
                    .font(.system(size: 17, weight: .semibold))
                Text(style.text)
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Text("Counted \(CashFormat.rupees(counted))")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(notes) notes · \(coins) coins")
                    .font(.system(size: 12))
            }
        }
        .foregroundStyle(style.foreground)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Row

private struct DenominationRow: View {
    let denomination: Denomination
    let count: Int
    var onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            DenominationBadge(denomination: denomination)
                .frame(width: 70, alignment: .leading)

            HStack(spacing: 0) {
                StepButton(systemImage: "minus", label: "One less ₹\(denomination.value)", isEnabled: count > 0) {
                    onChange(count - 1)
                }

                TextField(
                    "",
                    text: Binding(
                        get: { count == 0 ? "" : String(count) },
                        set: { onChange(Int(cashDigitsOnly($0, maxLength: 6)) ?? 0) }
                    ),
                    prompt: Text("0").foregroundStyle(CcColors.textFaint)
                )
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(CcColors.text)
                .tint(CcColors.primary)
                .frame(maxWidth: .infinity)

                StepButton(systemImage: "plus", label: "One more ₹\(denomination.value)", isEnabled: true) {
                    onChange(count + 1)
                }
            }
            .frame(height: 38)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(CcColors.border, lineWidth: 1))

            VStack(alignment: .trailing, spacing: 1) {
                Text(CashFormat.rupees(denomination.value * count))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(count == 0 ? CcColors.textFaint : CcColors.text)
                // Notes come in bundles of 100; showing that makes a miscount of a whole bundle obvious.
                if denomination.kind == .note, count >= 100 {
                    Text(cashBundleText(count))
                        .font(.system(size: 10))
                        .foregroundStyle(CcColors.textFaint)
                }
            }
            .frame(width: 84, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

private struct StepButton: View {
    let systemImage: String
    let label: String
    let isEnabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isEnabled ? CcColors.primary : CcColors.textFaint)
                .frame(width: 38, height: 38)
                .background(CcColors.track)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }
}
