//
//  PackerKit.swift
//  TrudataRider
//
//  Android `PackerKit.kt` and the slice of the cash-collection kit the packer screens draw with.
//  The packer module was ported from the TruDataa admin app, whose bill-register kit this app
//  doesn't have; these are its pieces, coloured from this app's `CcColors`, kept inside the
//  packer folder so the shared cash-collection files stay as they are.
//

import SwiftUI
import Combine

/// The brand and text colours the packer screens use (the admin app's `CashStyle`).
enum PkStyle {
    static let deep = CcColors.deep
    static let green = CcColors.primary
    static let bright = CcColors.bright
    static let pale = CcColors.container
    static let border = CcColors.border
    static let muted = CcColors.textMuted
    static let ink = CcColors.text
    static let gradient = LinearGradient(colors: [deep, green, bright], startPoint: .leading, endPoint: .trailing)
}

/// Status and surface tones (Android `CcColors`' semantic half).
enum PkTone {
    static let page = CcColors.page
    static let track = CcColors.track
    static let faint = CcColors.textFaint
    static let ok = CcColors.ok
    static let okBg = CcColors.okBg
    static let warn = CcColors.warn
    static let warnBg = CcColors.warnBg
    static let err = CcColors.err
    static let errBg = CcColors.errBg
    static let errInk = Color(hex: "991B1B")
    static let info = CcColors.info
    static let mutedFg = Color(hex: "4B5563")
    static let mutedBg = Color(hex: "F3F4F6")
}

/// Android `rupees`: up to two decimals, none forced.
func pkMoney(_ amount: Double) -> String { CashFormat.rupees(amount) }

// MARK: - Page

/// Android `CcTopBar` over a scrolling column: this app's bar (`SellersAppBar`), then the content.
struct PkPage<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    var onHome: () -> Void
    var onRefresh: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            SellersAppBar(title: title, onBack: { dismiss() }, onHome: onHome, onRefresh: onRefresh)
            ScrollView {
                VStack(alignment: .leading, spacing: 14, content: content)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    // Pinned to the screen's width so a long shop name can't let the page drift sideways.
                    .containerRelativeFrame(.horizontal)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
        .background(CcColors.page)
        .tint(PkStyle.green)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Small pieces

struct PkPill: View {
    let text: String
    let fg: Color
    let bg: Color
    var body: some View {
        Text(text).font(.system(size: 10.5, weight: .bold)).foregroundStyle(fg)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(bg, in: Capsule())
    }
}

struct PkIconDisc: View {
    let icon: String
    let color: Color
    var size: CGFloat = 28
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.12), in: Circle())
    }
}

/// A thin progress bar: how much of an order is in boxes.
struct PkClearedBar: View {
    let cleared: Int
    let total: Int
    var track: Color = PkTone.track
    var fill: Color = PkTone.ok
    private var fraction: CGFloat { total > 0 ? min(max(CGFloat(cleared) / CGFloat(total), 0), 1) : 0 }
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(fill).frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 6)
        .animation(.easeInOut(duration: 0.6), value: fraction)
    }
}

// MARK: - Buttons

/// Android `PrimaryButton`: 52pt, the brand gradient, or flat for any other colour.
struct PkPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = PkStyle.green
    var enabled = true
    var loading = false
    let action: () -> Void
    private var active: Bool { enabled && !loading }
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if loading { ProgressView().tint(.white).controlSize(.small) }
                else if let icon { Image(systemName: icon).font(.system(size: 15, weight: .semibold)) }
                Text(title).font(.system(size: 15, weight: .bold)).lineLimit(1)
            }
            .foregroundStyle(.white.opacity(active || loading ? 1 : 0.85))
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(
                color == PkStyle.green ? AnyShapeStyle(PkStyle.gradient) : AnyShapeStyle(color),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .opacity(active || loading ? 1 : 0.4)
            .shadow(color: color.opacity(active ? 0.3 : 0), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!active)
    }
}

/// Android `SecondaryButton`: the colour at 10% behind its own text.
struct PkSecondaryButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = PkStyle.green
    var enabled = true
    var loading = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if loading { ProgressView().tint(color).controlSize(.small) }
                else if let icon { Image(systemName: icon).font(.system(size: 15, weight: .semibold)) }
                Text(title).font(.system(size: 14.5, weight: .bold)).lineLimit(1).minimumScaleFactor(0.85)
            }
            .foregroundStyle(color.opacity(enabled ? 1 : 0.4))
            .frame(maxWidth: .infinity).frame(height: 52)
            .padding(.horizontal, 6)
            .background(color.opacity(enabled ? 0.1 : 0.05), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// Android `BottomActionBar`: white tray with a rounded top, a soft shadow and a grab handle.
struct PkBottomBar<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 10) {
            Capsule().fill(PkStyle.border).frame(width: 36, height: 4)
            content()
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 12, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

/// A row whose children share its width by `.pkWeight(_:)`, like Compose `Modifier.weight`.
struct PkWeightedRow: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let weights = subviews.map { $0[PkWeight.self] }
        let total = weights.reduce(0, +)
        let free = bounds.width - spacing * CGFloat(max(subviews.count - 1, 0))
        var x = bounds.minX
        for (view, weight) in zip(subviews, weights) {
            let width = total > 0 ? free * weight / total : 0
            view.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
                       proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width + spacing
        }
    }
}

nonisolated private struct PkWeight: LayoutValueKey {
    static let defaultValue: CGFloat = 1
}

extension View {
    func pkWeight(_ weight: CGFloat) -> some View { layoutValue(key: PkWeight.self, value: weight) }
}

// MARK: - States

struct PkEmptyState: View {
    let title: String
    let message: String
    var icon = "tray"
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 24)).foregroundStyle(PkTone.faint)
                .frame(width: 56, height: 56).background(PkTone.track, in: RoundedRectangle(cornerRadius: 16))
            Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(PkStyle.ink)
            Text(message).font(.system(size: 13)).foregroundStyle(PkStyle.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 36).padding(.horizontal, 24)
    }
}

/// Android `ErrorState`: the message and a Retry button, centred.
struct PkErrorState: View {
    let message: String
    let onRetry: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle").font(.system(size: 26)).foregroundStyle(PkTone.err)
            Text(message).font(.system(size: 13)).foregroundStyle(PkStyle.muted).multilineTextAlignment(.center)
            Button("Retry", action: onRetry).font(.system(size: 14, weight: .semibold)).foregroundStyle(PkStyle.green)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 36).padding(.horizontal, 24)
    }
}

// MARK: - Snackbar

private struct PkSnackbar: ViewModifier {
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
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color(hex: "313033"), in: RoundedRectangle(cornerRadius: 4))
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                        .padding(.horizontal, 12).padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onTapGesture { dismiss() }
                        .accessibilityAddTraits(.isStaticText)
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

    private func dismiss() {
        hideTask?.cancel()
        shown = nil
    }
}

extension View {
    func pkSnackbar(message: Binding<String?>) -> some View { modifier(PkSnackbar(message: message)) }
}

// MARK: - Dialogs

/// The pop-up the packer dialogs share: springs in, can't be closed while `busy`, and on a new
/// `error` shakes and shows it above the buttons.
struct PkDialog<Content: View, Buttons: View>: View {
    let busy: Bool
    let error: String?
    let onDismiss: () -> Void
    @ViewBuilder var content: () -> Content
    @ViewBuilder var buttons: () -> Buttons
    @State private var shown = false
    @State private var shake: CGFloat = 0
    @State private var keyboardUp = false
    /// IQKeyboardManager resigns the keyboard on the same outside tap before this view sees it,
    /// so a tap landing just after the keyboard went down was meant for the keyboard, not us.
    @State private var keyboardDownAt = Date.distantPast
    /// Set by the first outside tap, so a burst of taps closes the dialog once.
    @State private var closing = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(shown ? 0.4 : 0).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 24)
                        card
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 18)
                    .frame(minHeight: proxy.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: outsideTap)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: shown)
        .animation(.easeInOut(duration: 0.2), value: error)
        .transition(.opacity)
        .onAppear { shown = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardUp = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardUp = false
            keyboardDownAt = Date()
        }
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

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
            if let error {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle").foregroundStyle(PkTone.err)
                    Text(error).font(.system(size: 12.5)).foregroundStyle(PkTone.errInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(PkTone.errBg, in: RoundedRectangle(cornerRadius: 12))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            HStack(spacing: 10) { buttons() }
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
        // A tap on the card itself only puts the keyboard away; it never closes the dialog.
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .onTapGesture { hideKeyboard() }
        .scaleEffect(shown ? 1 : 0.88)
        .opacity(shown ? 1 : 0)
        .offset(x: shake)
    }

    private func outsideTap() {
        if keyboardUp || Date().timeIntervalSince(keyboardDownAt) < 0.6 { hideKeyboard(); return }
        guard !busy, !closing else { return }
        closing = true
        onDismiss()
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Runs an action once, so a double tap can't dismiss or confirm twice.
@MainActor
final class PkOnce: ObservableObject {
    private var fired = false
    func run(_ action: () -> Void) {
        guard !fired else { return }
        fired = true
        action()
    }
}

/// Android `ConfirmDialog`: an icon disc, a title, a body and two buttons.
struct PkConfirmDialog: View {
    let icon: String
    let title: String
    let message: String
    let confirmTitle: String
    var confirmColor: Color = PkStyle.green
    var dismissTitle = "Cancel"
    let onConfirm: () -> Void
    let onDismiss: () -> Void
    @StateObject private var once = PkOnce()
    var body: some View {
        PkDialog(busy: false, error: nil, onDismiss: { once.run(onDismiss) }) {
            VStack(spacing: 10) {
                PkIconDisc(icon: icon, color: confirmColor, size: 52)
                Text(title).font(.system(size: 18, weight: .heavy)).foregroundStyle(PkStyle.ink).multilineTextAlignment(.center)
                Text(message).font(.system(size: 14)).foregroundStyle(PkStyle.muted).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity)
        } buttons: {
            PkWeightedRow {
                PkSecondaryButton(title: dismissTitle, color: PkStyle.muted) { once.run(onDismiss) }
                PkPrimaryButton(title: confirmTitle, color: confirmColor) { once.run(onConfirm) }
            }
        }
    }
}

/// Android `ErrorDialog`: a red error disc, "Can't continue", the message and one OK button.
struct PkErrorDialog: View {
    let message: String
    var title = "Can't continue"
    let onDismiss: () -> Void
    @StateObject private var once = PkOnce()
    var body: some View {
        PkDialog(busy: false, error: nil, onDismiss: { once.run(onDismiss) }) {
            VStack(spacing: 10) {
                PkIconDisc(icon: "exclamationmark.circle", color: PkTone.err, size: 60)
                Text(title).font(.system(size: 18, weight: .heavy)).foregroundStyle(PkStyle.ink).multilineTextAlignment(.center)
                Text(message).font(.system(size: 14)).foregroundStyle(PkStyle.muted).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity).padding(.bottom, 4)
        } buttons: {
            PkPrimaryButton(title: "OK") { once.run(onDismiss) }
        }
    }
}
