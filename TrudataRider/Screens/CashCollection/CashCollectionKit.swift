//
//  CashCollectionKit.swift
//  TrudataRider
//
//  The shared furniture every cash screen is built from — the palette, money formatting, pills,
//  section cards, states and buttons. Ported from the Android module's `CcKit.kt` so both
//  platforms read the same.
//

import SwiftUI

// MARK: - Palette

enum CcColors {
    static let primary = AppTheme.brand.primary
    static let deep = AppTheme.brand.deep
    static let bright = AppTheme.brand.bright
    static let glow = AppTheme.brand.heroGlow
    static let container = AppTheme.brand.container

    static let page = Color(hex: "F7F9F8")
    static let card = Color.white
    static let border = Color(hex: "E4E7EB")
    static let divider = Color(hex: "F1F3F5")
    static let track = Color(hex: "F3F5F7")

    static let text = Color(hex: "111827")
    static let textMuted = Color(hex: "6B7280")
    static let textFaint = Color(hex: "9CA3AF")

    static let ok = Color(hex: "15803D")
    static let okBg = Color(hex: "DCFCE7")
    static let warn = Color(hex: "B45309")
    static let warnBg = Color(hex: "FEF3C7")
    static let err = Color(hex: "DC2626")
    static let errBg = Color(hex: "FFF1F2")
    static let info = Color(hex: "0369A1")
    static let infoBg = Color(hex: "E0F2FE")
    /// The dark red the error notes write in, over `errBg`.
    static let errInk = Color(hex: "991B1B")

    /// The deep-to-bright brand gradient behind `CcHero`.
    static let heroBrand = [deep, primary, bright]
    /// `heroBrand`'s slate twin, for a hero about something called off.
    static let heroMuted = [Color(hex: "1F2937"), Color(hex: "374151"), Color(hex: "4B5563")]
}

// MARK: - Money and dates

enum CashFormat {

    private static let inr: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    /// "₹1,25,000"; a negative amount reads "−₹500", never "₹-500".
    static func rupees(_ amount: Double) -> String {
        let sign = amount < 0 ? "−₹" : "₹"
        let magnitude = NSNumber(value: abs(amount))
        return sign + (inr.string(from: magnitude) ?? "0")
    }

    static func rupees(_ amount: Int) -> String {
        rupees(Double(amount))
    }

    /// "Fifty Thousand rupees" — Indian grouping, so a missing zero is easy to catch.
    static func amountInWords(_ amount: Int) -> String {
        guard amount > 0 else { return "" }

        let ones = ["", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten",
                    "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen", "Seventeen",
                    "Eighteen", "Nineteen"]
        let tens = ["", "", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety"]

        func two(_ n: Int) -> String {
            if n < 20 { return ones[n] }
            return tens[n / 10] + (n % 10 != 0 ? " " + ones[n % 10] : "")
        }

        func three(_ n: Int) -> String {
            var result = ""
            if n >= 100 { result += ones[n / 100] + " Hundred" }
            if n % 100 != 0 {
                if !result.isEmpty { result += " " }
                result += two(n % 100)
            }
            return result
        }

        var n = amount
        var parts: [String] = []

        let crore = n / 10_000_000
        n %= 10_000_000
        let lakh = n / 100_000
        n %= 100_000
        let thousand = n / 1000
        let rest = n % 1000

        if crore > 0 { parts.append((crore < 1000 ? three(crore) : String(crore)) + " Crore") }
        if lakh > 0 { parts.append(two(lakh) + " Lakh") }
        if thousand > 0 { parts.append(two(thousand) + " Thousand") }
        if rest > 0 { parts.append(three(rest)) }

        return parts.joined(separator: " ") + " rupees"
    }

    private static let apiDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let prettyDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// `yyyy-MM-dd`, the only date shape these endpoints take.
    static func apiString(from date: Date) -> String {
        apiDate.string(from: date)
    }

    static func date(fromApi string: String) -> Date? {
        apiDate.date(from: String(string.prefix(10)))
    }

    /// "12 Oct 2026" from either `yyyy-MM-dd` or a full timestamp; falls back to the raw text.
    static func pretty(_ string: String?) -> String {
        guard let string, !string.isEmpty else { return "—" }
        guard let date = date(fromApi: string) else { return string }
        return prettyDate.string(from: date)
    }

    static func monthLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}

// MARK: - Pills

enum PillTone {
    case ok, warn, err, info, muted, violet

    var foreground: Color {
        switch self {
        case .ok: return CcColors.ok
        case .warn: return CcColors.warn
        case .err: return CcColors.err
        case .info: return CcColors.info
        case .muted: return Color(hex: "4B5563")
        case .violet: return Color(hex: "6D28D9")
        }
    }

    var background: Color {
        switch self {
        case .ok: return CcColors.okBg
        case .warn: return CcColors.warnBg
        case .err: return CcColors.errBg
        case .info: return CcColors.infoBg
        case .muted: return Color(hex: "F3F4F6")
        case .violet: return Color(hex: "EDE9FE")
        }
    }
}

struct CcPill: View {
    let text: String
    var tone: PillTone = .muted

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold))
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tone.background, in: Capsule())
    }
}

struct CcStatusPill: View {
    let status: String

    var body: some View {
        CcPill(text: label, tone: tone)
    }

    private var label: String {
        switch status.lowercased() {
        case CashStatus.approved: return "Approved"
        case CashStatus.rejected: return "Rejected"
        case CashStatus.pending: return "Pending"
        default: return status.isEmpty ? "—" : status.capitalized
        }
    }

    private var tone: PillTone {
        switch status.lowercased() {
        case CashStatus.approved: return .ok
        case CashStatus.rejected: return .err
        case CashStatus.pending: return .warn
        default: return .muted
        }
    }
}

// MARK: - Section card

/// A titled white section with a tinted icon disc, as on the order screens.
struct CcSection<Content: View>: View {
    let title: String
    let systemImage: String
    var accent: Color = CcColors.primary
    var trailing: AnyView?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                CcIconDisc(systemImage: systemImage, accent: accent)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(CcColors.text)
                Spacer(minLength: 8)
                trailing
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CcColors.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(CcColors.border, lineWidth: 1)
        )
    }
}

struct CcIconDisc: View {
    let systemImage: String
    var accent: Color = CcColors.primary
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundStyle(accent)
            .frame(width: size, height: size)
            .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: size * 0.33, style: .continuous))
    }
}

// MARK: - Hero

/// The brand-gradient panel the money screens lead with.
struct CcHero<Content: View>: View {
    /// `CcColors.heroMuted` for a hero about something called off.
    var colors: [Color] = CcColors.heroBrand
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        // Drains from brand to slate rather than snapping when a register is cancelled.
        .animation(.easeInOut(duration: 0.7), value: colors)
    }
}

struct CcHeroLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(.white.opacity(0.75))
    }
}

struct CcHeroStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Segmented control

struct CcSegmented<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : CcColors.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? CcColors.primary : Color.clear,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(CcColors.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// A scrolling row of filter chips; `nil` is the "all" option.
struct CcFilterChipRow: View {
    let options: [(value: String?, title: String)]
    @Binding var selection: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    let isSelected = option.value == selection
                    Button {
                        selection = option.value
                    } label: {
                        Text(option.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : CcColors.textMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                isSelected ? CcColors.primary : CcColors.card,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().stroke(isSelected ? Color.clear : CcColors.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - States

struct CcEmptyState: View {
    let title: String
    var message: String = ""
    var systemImage: String = "tray"

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(CcColors.textFaint)
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(CcColors.text)
            if !message.isEmpty {
                Text(message)
                    .font(.system(size: 12.5))
                    .foregroundStyle(CcColors.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }
}

struct CcErrorState: View {
    let message: String
    var onRetry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(CcColors.err)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(CcColors.textMuted)
                .multilineTextAlignment(.center)
            CcSecondaryButton(title: "Try again", action: onRetry)
                .fixedSize()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
    }
}

struct CcLoadingBlock: View {
    var body: some View {
        ProgressView()
            .tint(CcColors.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 44)
    }
}

/// Loading / error / empty / content in one place, so every list handles the four the same way.
struct CcContentState<Content: View>: View {
    let isLoading: Bool
    let errorMessage: String?
    let isEmpty: Bool
    var emptyTitle: String = "Nothing here yet"
    var emptyBody: String = ""
    var emptyImage: String = "tray"
    var onRetry: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        if isLoading {
            CcLoadingBlock()
        } else if let errorMessage, !errorMessage.isEmpty {
            CcErrorState(message: errorMessage, onRetry: onRetry)
        } else if isEmpty {
            CcEmptyState(title: emptyTitle, message: emptyBody, systemImage: emptyImage)
        } else {
            content
        }
    }
}

// MARK: - Buttons

struct CcPrimaryButton: View {
    let title: String
    var systemImage: String?
    var isEnabled: Bool = true
    var isLoading: Bool = false
    /// Red for a destructive confirm (Discard); the brand colour otherwise.
    var color: Color = CcColors.primary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isEnabled && !isLoading ? color : color.opacity(0.4),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
    }
}

struct CcSecondaryButton: View {
    let title: String
    var systemImage: String?
    var tint: Color = CcColors.primary
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(isEnabled ? tint : tint.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(CcColors.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isEnabled ? tint.opacity(0.4) : CcColors.border, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

/// The pinned bar the forms and detail screens act from.
struct CcBottomActionBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 10) {
            content
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            CcColors.card
                .overlay(CcColors.border.frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

/// A labelled figure for the summary bars above an action bar.
struct CcBarSummary: View {
    let label: String
    let value: String
    var tone: PillTone?
    var status: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(CcColors.textMuted)
            HStack(spacing: 6) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(CcColors.text)
                if let status {
                    CcStatusPill(status: status)
                } else if let tone {
                    CcPill(text: label, tone: tone)
                }
            }
        }
    }
}

// MARK: - Dialogs

/// Android `CcDialog` / `BillDialog`: a white card over a dimmed page that springs in. It can't be
/// closed while `busy`, and a new `error` shakes it and shows above the buttons, so what was picked
/// stays. Shown as an overlay rather than an alert because the create summary needs real layout.
struct CcDialog<Content: View, Buttons: View>: View {
    var busy: Bool = false
    var error: String?
    let onDismiss: () -> Void
    @ViewBuilder var content: Content
    @ViewBuilder var buttons: Buttons

    @State private var shown = false
    @State private var shake: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.opacity(shown ? 0.4 : 0)
                .ignoresSafeArea()
                .onTapGesture { if !busy { onDismiss() } }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    content
                    if let error {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 15))
                                .foregroundStyle(CcColors.err)
                            Text(error)
                                .font(.system(size: 12.5))
                                .foregroundStyle(CcColors.errInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(CcColors.errBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    HStack(spacing: 10) { buttons }
                }
                .padding(20)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .scaleEffect(shown ? 1 : 0.88)
                .opacity(shown ? 1 : 0)
                .offset(x: shake)
                .padding(.horizontal, 18)
                .padding(.vertical, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            // Centred while it fits; scrolls once a long summary doesn't.
            .defaultScrollAnchor(.center)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: shown)
        .animation(.easeInOut(duration: 0.2), value: error)
        .onAppear { shown = true }
        .onChange(of: error) { _, value in
            guard value != nil else { return }
            Task { @MainActor in
                for x: CGFloat in [10, -8, 6, -4, 0] {
                    withAnimation(.linear(duration: 0.045)) { shake = x }
                    try? await Task.sleep(for: .milliseconds(45))
                }
            }
        }
    }
}

/// Android `ConfirmDialog`: an icon disc, a title, a body and two buttons. `dismissTitle` is worth
/// renaming when "Cancel" could be read as the action itself.
struct CcConfirmDialog: View {
    let systemImage: String
    let title: String
    let message: String
    let confirmTitle: String
    var confirmColor: Color = CcColors.primary
    var dismissTitle: String = "Cancel"
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        CcDialog(onDismiss: onDismiss) {
            VStack(spacing: 10) {
                CcIconDisc(systemImage: systemImage, accent: confirmColor, size: 52)
                Text(title)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(CcColors.text)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(CcColors.textMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        } buttons: {
            CcSecondaryButton(title: dismissTitle, tint: CcColors.textMuted, action: onDismiss)
            CcPrimaryButton(title: confirmTitle, color: confirmColor, action: onConfirm)
        }
    }
}

// MARK: - Rows

/// A label / value line, the building block of every detail card.
struct CcDetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = CcColors.text
    var isStrong: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 12.5))
                .foregroundStyle(CcColors.textMuted)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: isStrong ? 14.5 : 12.5, weight: isStrong ? .bold : .semibold))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Denominations

/// The colour of the real note or coin, used for its badge and its bars.
func denominationTint(_ denomination: Denomination) -> Color {
    switch denomination {
    case .note500: return Color(hex: "8C8A7A")
    case .note200: return Color(hex: "E9A21B")
    case .note100: return Color(hex: "8F7CC4")
    case .note50: return Color(hex: "2FAFC4")
    case .note20: return Color(hex: "93B63A")
    case .note10: return Color(hex: "8A5A30")
    case .note5: return Color(hex: "3F8F5A")
    case .coin20, .coin10: return Color(hex: "C9A33A")
    case .coin5: return Color(hex: "B8A06A")
    case .coin2, .coin1: return Color(hex: "A8AEB5")
    }
}

/// A note as a small banknote swatch, or a coin as a disc.
struct DenominationBadge: View {
    let denomination: Denomination

    private var tint: Color { denominationTint(denomination) }

    var body: some View {
        if denomination.kind == .note {
            HStack(spacing: 0) {
                tint.frame(width: 10, height: 30)
                Text(denomination.label)
                    .font(.system(size: 12.5, weight: .heavy))
                    .foregroundStyle(CcColors.text)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 6)
            }
            .frame(width: 60, height: 30)
            .background(tint.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(tint.opacity(0.55), lineWidth: 1)
            )
        } else {
            HStack {
                Text(denomination.label)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(CcColors.text)
                    .frame(width: 34, height: 34)
                    .background(
                        RadialGradient(colors: [.white, tint], center: .center, startRadius: 1, endRadius: 18),
                        in: Circle()
                    )
                    .overlay(Circle().stroke(tint, lineWidth: 1.5))
                Spacer(minLength: 0)
            }
            .frame(width: 60)
        }
    }
}
