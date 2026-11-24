//
//  BillRegisterComponents.swift
//  TrudataRider
//
//  The bill register's own pieces, ported from Android `BillUi.kt` and the parts of `CcKit.kt` it
//  draws with. They sit apart from `CashCollectionKit` because Android's buttons, bars, hero and
//  dialogs measure differently from the kit's, and the kit's other screens must not change.
//

import SwiftUI

/// Android literals the kit has no name for.
enum BillTone {
    /// Material outlined-field border, as Android's `PickerField` and search boxes draw it.
    static let fieldBorder = Color(hex: "D1D5DB")
    /// Material on-surface-variant: the order-id field's icons, label and helper line.
    static let onSurfaceVariant = Color(hex: "49454F")
    static let outline = Color(hex: "79747E")
}

// MARK: - Pills and bars

/// A register's or an order's status; a change pops the new pill in.
struct BillStatusPill: View {
    let status: String

    var body: some View {
        let key = status.lowercased()
        Group {
            switch key {
            case BillStatus.cleared: CcPill(text: "Cleared", tone: .ok)
            case BillStatus.pending: CcPill(text: "Pending", tone: .warn)
            case BillStatus.cancelled: CcPill(text: "Cancelled", tone: .err)
            case BillStatus.removed: CcPill(text: "Removed", tone: .err)
            default: CcPill(text: key.isEmpty ? "—" : key.prefix(1).uppercased() + key.dropFirst(), tone: .muted)
            }
        }
        .id(key)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
        .animation(.easeOut(duration: 0.22), value: key)
    }
}

/// cleared / total as a thin bar that eases to a new value.
struct BillClearedBar: View {
    let cleared: Int
    let total: Int
    var track: Color = CcColors.track
    var fill: Color = CcColors.ok

    private var fraction: CGFloat {
        total > 0 ? min(max(CGFloat(cleared) / CGFloat(total), 0), 1) : 0
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(track)
                RoundedRectangle(cornerRadius: 3).fill(fill).frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 6)
        .animation(.easeInOut(duration: 0.6), value: fraction)
    }
}

/// A cancel or remove reason, quoted and in italics. Blank reasons show nothing.
struct BillQuote: View {
    let text: String
    var lines: Int?
    var size: CGFloat = 12
    var color: Color = CcColors.textMuted

    var body: some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            Text("\u{201C}\(trimmed)\u{201D}")
                .font(.system(size: size))
                .italic()
                .foregroundStyle(color)
                .lineLimit(lines)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: lines == nil)
        }
    }
}

/// A dialog's bills, as shop and amount: the first few, then how many more.
struct BillLinesPreview: View {
    let lines: [(String, Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.prefix(3).enumerated()), id: \.offset) { _, line in
                HStack(spacing: 8) {
                    Text(line.0)
                        .font(.system(size: 12.5))
                        .foregroundStyle(CcColors.text)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(CashFormat.rupees(line.1))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(CcColors.text)
                }
            }
            if lines.count > 3 {
                Text("+\(lines.count - 3) more")
                    .font(.system(size: 11.5))
                    .foregroundStyle(CcColors.textMuted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CcColors.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Android `IconDisc`: an icon on a rounded square of its own colour at 12%.
struct BillIconDisc: View {
    let systemImage: String
    var accent: Color = CcColors.primary
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(accent)
            .frame(width: size, height: size)
            .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.29, style: .continuous))
    }
}

/// Android `CcSection`: a white bordered card headed by an icon disc and a title.
struct BillSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                BillIconDisc(systemImage: systemImage)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(CcColors.text)
                Spacer(minLength: 0)
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CcColors.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(CcColors.border, lineWidth: 1))
    }
}

// MARK: - Buttons and the action tray

/// Android `PrimaryButton`: 52pt, the brand gradient (flat for any other colour, e.g. red for a
/// destructive action), a spinner in place of the label while working.
struct BillPrimaryButton: View {
    let title: String
    var systemImage: String?
    var isEnabled = true
    var isLoading = false
    var color: Color = CcColors.primary
    let action: () -> Void

    private var active: Bool { isEnabled && !isLoading }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white).controlSize(.small)
                } else {
                    if let systemImage {
                        Image(systemName: systemImage).font(.system(size: 16, weight: .semibold))
                    }
                    Text(title).font(.system(size: 15, weight: .bold)).lineLimit(1).minimumScaleFactor(0.85)
                }
            }
            .foregroundStyle(.white.opacity(active || isLoading ? 1 : 0.85))
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(active || isLoading ? 1 : 0.4)
            .shadow(color: color.opacity(active ? 0.3 : 0), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!active)
    }

    private var fill: AnyShapeStyle {
        color == CcColors.primary
            ? AnyShapeStyle(LinearGradient(colors: CcColors.heroBrand, startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(color)
    }
}

/// Android `SecondaryButton`: its colour at 10% behind its own label, no outline.
struct BillSecondaryButton: View {
    let title: String
    var systemImage: String?
    var color: Color = CcColors.primary
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 15, weight: .semibold))
                }
                Text(title).font(.system(size: 14.5, weight: .bold)).lineLimit(1).minimumScaleFactor(0.85)
            }
            .foregroundStyle(color.opacity(isEnabled ? 1 : 0.4))
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(color.opacity(isEnabled ? 0.1 : 0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

/// Android `BottomActionBar`: a white tray with a rounded top, a soft shadow and a grab handle,
/// an optional summary line above the buttons.
struct BillBottomBar<Summary: View, Content: View>: View {
    @ViewBuilder var summary: Summary
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 10) {
            Capsule().fill(CcColors.border).frame(width: 36, height: 4)
            summary
            content
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 12, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

extension BillBottomBar where Summary == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.summary = EmptyView()
        self.content = content()
    }
}

/// Android `BarSummary`: a label over a large figure, filling the row.
struct BillBarSummary: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(CcColors.textMuted)
            Text(value)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(CcColors.text)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A row whose children share its width by `.billWeight(_:)`, like Compose `Modifier.weight`, so
/// Android's 1 : 1.4 and 0.9 : 1.3 button splits hold.
struct BillWeightedRow: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let weights = subviews.map { $0[BillWeight.self] }
        let total = weights.reduce(0, +)
        let free = bounds.width - spacing * CGFloat(max(subviews.count - 1, 0))
        var x = bounds.minX
        for (view, weight) in zip(subviews, weights) {
            let width = total > 0 ? free * weight / total : 0
            view.place(
                at: CGPoint(x: x, y: bounds.midY),
                anchor: .leading,
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            x += width + spacing
        }
    }
}

nonisolated private struct BillWeight: LayoutValueKey {
    static let defaultValue: CGFloat = 1
}

extension View {
    func billWeight(_ weight: CGFloat) -> some View { layoutValue(key: BillWeight.self, value: weight) }
}

// MARK: - Form pieces

/// Android `PickerField`: a small bold label over a tappable white box with an icon, the value
/// (faint while it is only a placeholder) and an up-down chevron; red with a line under it on error.
struct BillPickerField: View {
    let label: String
    let value: String
    let systemImage: String
    var error: String?
    var isPlaceholder = false
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(CcColors.textMuted)
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.system(size: 15))
                        .foregroundStyle(CcColors.textMuted)
                        .frame(width: 18)
                    Text(value)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isPlaceholder ? CcColors.textFaint : CcColors.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CcColors.textFaint)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 13)
                .background(error != nil ? CcColors.errBg : .white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(error != nil ? CcColors.err : BillTone.fieldBorder, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            if let error {
                Text(error)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(CcColors.err)
            }
        }
    }
}

/// Android's outlined search box (`fieldColors`): a magnifier, the text, a clear button once there
/// is text, and a 2pt bright border while focused.
struct BillSearchField: View {
    let placeholder: String
    @Binding var text: String
    var cornerRadius: CGFloat = 12
    /// Android's person picker search has no clear button; the order and beat searches do.
    var showsClear = true
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17))
                .foregroundStyle(BillTone.onSurfaceVariant)
            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .foregroundStyle(CcColors.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused)
            if showsClear && !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(BillTone.onSurfaceVariant)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
        .background(.white, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(focused ? CcColors.bright : BillTone.fieldBorder, lineWidth: focused ? 2 : 1)
        )
    }
}

/// Material 3 `Checkbox`: an 18pt rounded box, filled brand with a white tick once checked, in a
/// 48pt touch target. Disabled boxes fade.
struct BillCheckbox: View {
    let isChecked: Bool
    var isEnabled = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(isChecked ? CcColors.primary : .clear)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(isChecked ? CcColors.primary : BillTone.onSurfaceVariant, lineWidth: 2)
            if isChecked {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 18, height: 18)
        .opacity(isEnabled ? 1 : 0.38)
        .frame(width: 48, height: 48)
        .animation(.easeInOut(duration: 0.15), value: isChecked)
    }
}

// MARK: - States

/// Android `EmptyState`: a faint icon on a grey tile, a title and a centred line.
struct BillEmptyState: View {
    let title: String
    let message: String
    var systemImage = "tray"

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 24))
                .foregroundStyle(CcColors.textFaint)
                .frame(width: 56, height: 56)
                .background(CcColors.track, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(CcColors.text)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(CcColors.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
    }
}

/// Android `ErrorState`: a cloud-off mark, the message and an outlined "Try again".
struct BillErrorState: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 30))
                .foregroundStyle(CcColors.err)
            Text(message)
                .font(.system(size: 13.5))
                .foregroundStyle(CcColors.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onRetry) {
                Text("Try again")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CcColors.primary)
                    .padding(.horizontal, 24)
                    .frame(height: 40)
                    .overlay(Capsule().stroke(CcColors.primary, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
    }
}

/// Android `LoadingBlock`: a 32pt brand spinner with 40pt around it.
struct BillLoadingBlock: View {
    var body: some View {
        ProgressView()
            .tint(CcColors.primary)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .padding(40)
    }
}

/// Android `CcSegmented`: equal segments on a grey track; the picked one is brand-filled.
struct BillSegmented<Value: Hashable>: View {
    let options: [(Value, String)]
    let selection: Value
    let onSelect: (Value) -> Void

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let on = option.0 == selection
                Button { onSelect(option.0) } label: {
                    Text(option.1)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(on ? .white : CcColors.textMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(on ? CcColors.primary : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(CcColors.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeInOut(duration: 0.18), value: selection)
    }
}

// MARK: - Hero

/// Android `CcHero` as the register detail draws it: 14pt padding, 4pt between lines, the gradient
/// with a soft glow on top. A cancelled register passes the slate colours and a dimmer glow.
struct BillHero<Content: View>: View {
    var colors: [Color] = CcColors.heroBrand
    var glowAlpha: Double = 0.22
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(
                    colors: [CcColors.glow.opacity(glowAlpha), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 220
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        // Drains from brand to slate rather than snapping when a register is cancelled.
        .animation(.easeInOut(duration: 0.7), value: colors)
        .animation(.easeInOut(duration: 0.7), value: glowAlpha)
    }
}

/// Android `HeroLabel`.
struct BillHeroLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(.white.opacity(0.68))
    }
}

/// Android `HeroStat`: a label and figure on a faint white tile.
struct BillHeroStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Dialogs

/// The round icon Android's confirm and error dialogs lead with: a 60pt disc at 12%, a 30pt icon.
private struct BillAlertDisc: View {
    let systemImage: String
    let accent: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(accent)
            .frame(width: 60, height: 60)
            .background(accent.opacity(0.12), in: Circle())
    }
}

/// Android `ConfirmDialog`: a round icon, a title, a body and two equal buttons.
struct BillConfirmDialog: View {
    let systemImage: String
    let title: String
    let message: String
    let confirmTitle: String
    var confirmColor: Color = CcColors.primary
    /// Worth renaming when "Cancel" could be read as the action itself.
    var dismissTitle = "Cancel"
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        CcDialog(onDismiss: onDismiss) {
            VStack(spacing: 10) {
                BillAlertDisc(systemImage: systemImage, accent: confirmColor)
                Text(title)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(CcColors.text)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(CcColors.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)
        } buttons: {
            BillWeightedRow {
                BillSecondaryButton(title: dismissTitle, color: CcColors.textMuted, action: onDismiss)
                BillPrimaryButton(title: confirmTitle, color: confirmColor, action: onConfirm)
            }
        }
    }
}

/// Android `ErrorDialog`: validation and server errors as a pop-up that is read and dismissed.
struct BillErrorDialog: View {
    let message: String
    var title = "Can't continue"
    let onDismiss: () -> Void

    var body: some View {
        CcDialog(onDismiss: onDismiss) {
            VStack(spacing: 10) {
                BillAlertDisc(systemImage: "exclamationmark.circle", accent: CcColors.err)
                Text(title)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(CcColors.text)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(CcColors.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)
        } buttons: {
            BillPrimaryButton(title: "OK", action: onDismiss)
        }
    }
}

/// Material 3 `Snackbar` as Android's `SnackbarHost` shows it: a dark card at the bottom that goes
/// after four seconds (Android's Short) or on a tap.
private struct BillSnackbar: ViewModifier {
    @Binding var message: String?
    @State private var shown: String?
    @State private var hideTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let shown {
                    Text(shown)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "F4EFF4"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(hex: "313033"), in: RoundedRectangle(cornerRadius: 4))
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onTapGesture { hide() }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: shown)
            .onChange(of: message) { _, value in
                guard let value, !value.isEmpty else { return }
                // Taken off the model at once, like Android's messageShown(), so it shows once.
                message = nil
                shown = value
                hideTask?.cancel()
                hideTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(4))
                    guard !Task.isCancelled else { return }
                    shown = nil
                }
            }
            .onDisappear { hideTask?.cancel() }
    }

    private func hide() {
        hideTask?.cancel()
        shown = nil
    }
}

extension View {
    func billSnackbar(message: Binding<String?>) -> some View { modifier(BillSnackbar(message: message)) }
}

// MARK: - Order row pieces

/// Android `ViewOrderChip`. Android's rider app passes no order screen to the bill register, so the
/// rider screens leave `onOpenOrder` nil and this chip never shows there.
struct BillViewOrderChip: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "doc.text").font(.system(size: 11, weight: .semibold))
                Text("View order").font(.system(size: 11.5, weight: .bold))
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(CcColors.primary)
            .padding(.leading, 7)
            .padding(.trailing, 5)
            .padding(.vertical, 3)
            .background(CcColors.container, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Android `CallButton`: dials the shop's number; nothing shows without one.
struct BillCallButton: View {
    let mobile: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        let digits = (mobile ?? "").filter { $0.isNumber || $0 == "+" }
        if !digits.isEmpty, let url = URL(string: "tel:\(digits)") {
            Button { openURL(url) } label: {
                Image(systemName: "phone.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(CcColors.primary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Call \(mobile ?? digits)")
        }
    }
}

// MARK: - Person picker

/// Android `PersonPickerDialog`: "Choose a person", a search over name and role, and the list with
/// initials; the current pick is tinted. Tapping a person picks them at once.
struct BillPersonPicker: View {
    let state: PeopleState
    let selectedId: Int?
    let onRetry: () -> Void
    let onPick: (PersonOption) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var shown = false

    private var term: String { query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    private var matches: [PersonOption] {
        guard !term.isEmpty else { return state.items }
        return state.items.filter { $0.name.lowercased().contains(term) || $0.role.lowercased().contains(term) }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(shown ? 0.32 : 0)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            card
                .scaleEffect(shown ? 1 : 0.92)
                .opacity(shown ? 1 : 0)
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: shown)
        .onAppear { shown = true }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose a person")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(CcColors.text)
            VStack(alignment: .leading, spacing: 8) {
                BillSearchField(placeholder: "Search by name or role", text: $query, cornerRadius: 10, showsClear: false)
                list
            }
            HStack {
                Spacer()
                Button("Close", action: onDismiss)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CcColors.textMuted)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
            }
        }
        .padding(24)
        .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    @ViewBuilder
    private var list: some View {
        if state.isLoading {
            BillLoadingBlock()
        } else if let error = state.error {
            BillErrorState(message: error, onRetry: onRetry)
        } else {
            if matches.isEmpty {
                Text("Nobody matches \u{201C}\(query)\u{201D}.")
                    .font(.system(size: 13))
                    .foregroundStyle(CcColors.textMuted)
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(matches) { person in
                        row(person)
                    }
                }
            }
            .frame(maxHeight: 380)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func row(_ person: PersonOption) -> some View {
        Button { onPick(person) } label: {
            HStack(spacing: 10) {
                Text(initials(person.name))
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(CcColors.primary)
                    .frame(width: 34, height: 34)
                    .background(CcColors.container, in: Circle())
                VStack(alignment: .leading, spacing: 0) {
                    Text(person.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CcColors.text)
                    if !person.role.isEmpty {
                        Text(person.role)
                            .font(.system(size: 12))
                            .foregroundStyle(CcColors.textMuted)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .background(
                person.id == selectedId ? CcColors.container : .clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Android `initials`: the first letters of the first two words.
    private func initials(_ name: String) -> String {
        let words = name.split(separator: " ").prefix(2)
        let letters = words.compactMap(\.first).map { String($0).uppercased() }.joined()
        return letters.isEmpty ? "?" : letters
    }
}
