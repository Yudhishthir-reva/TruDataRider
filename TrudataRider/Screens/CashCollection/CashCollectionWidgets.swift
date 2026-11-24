//
//  CashCollectionWidgets.swift
//  TrudataRider
//
//  The Android cash module's building blocks (`CcKit.kt`, `CashFilter.kt`, the advance form fields)
//  at Android's own sizes, for the Cash Collection, Amount Taken, Payment Advance and Ledger screens.
//  `CashCollectionKit.swift` keeps the palette and formatting these build on.
//

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Section and hero

struct CashIconDisc: View {
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

/// Android `CcSection`: a titled white card with a tinted icon disc, an optional subtitle and an
/// optional trailing view.
struct CashSection<Content: View>: View {
    let title: String
    let systemImage: String
    var subtitle: String?
    var accent: Color = CcColors.primary
    var trailing: AnyView?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                CashIconDisc(systemImage: systemImage, accent: accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(CcColors.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(CcColors.textMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let trailing { trailing }
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CcColors.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(CcColors.border, lineWidth: 1))
    }
}

/// Android `CcHero`: the brand gradient with a soft glow, carrying the one figure a screen is about.
struct CashHero<Content: View>: View {
    var colors: [Color] = CcColors.heroBrand
    var glowAlpha: Double = 0.22
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(
                    colors: [CcColors.glow.opacity(glowAlpha), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 220
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct CashHeroLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(.white.opacity(0.68))
    }
}

/// Android `HeroStat`: a label and value in a translucent box.
struct CashHeroStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
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
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Pills

/// Android `advanceStatusTone`.
func cashAdvanceTone(_ status: String) -> PillTone {
    switch status.lowercased() {
    case AdvanceStatus.pending: return .warn
    case AdvanceStatus.partial: return .info
    case AdvanceStatus.completed: return .ok
    case AdvanceStatus.cancelled: return .err
    default: return .muted
    }
}

struct CashAdvanceStatusPill: View {
    let status: String

    var body: some View {
        CcPill(text: AdvanceStatus.label(status), tone: cashAdvanceTone(status))
    }
}

// MARK: - Segmented and chips

/// Android `CcSegmented`.
struct CashSegmented<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    let selection: Value
    var onSelect: (Value) -> Void

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.value) { option in
                let isOn = option.value == selection
                Button {
                    onSelect(option.value)
                } label: {
                    Text(option.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isOn ? .white : CcColors.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(isOn ? CcColors.primary : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(CcColors.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Android `FilterChipRow` inside a horizontal scroll; `nil` is usually the "all" option.
struct CashChipRow: View {
    let options: [(value: String?, title: String)]
    let selection: String?
    var onSelect: (String?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    let isOn = option.value == selection
                    Button {
                        onSelect(option.value)
                    } label: {
                        Text(option.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isOn ? CcColors.primary : Color(hex: "374151"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isOn ? CcColors.container : .white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(isOn ? CcColors.primary : Color(hex: "D1D5DB"), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(1)
        }
    }
}

// MARK: - Filter bar

/// Android `CashFilterBar`: period switch (Today · Range · Month · All) with its detail row, and the
/// staff filter when `staffOptions` is given. Owns its range picker and staff sheet.
struct CashFilterBar: View {
    let filter: CashFilter
    var staffOptions: [PersonOption]?
    var onChange: (CashFilter) -> Void

    @State private var showRange = false
    @State private var showStaff = false

    var body: some View {
        VStack(spacing: 8) {
            CashSegmented(
                options: CashPeriod.allCases.map { ($0, $0.rawValue) },
                selection: filter.period
            ) { period in
                if period == .range {
                    showRange = true
                } else {
                    var next = filter
                    next.period = period
                    onChange(next)
                }
            }

            switch filter.period {
            case .month:
                CashMonthBar(month: filter.month) { month in
                    var next = filter
                    next.month = month
                    onChange(next)
                }
            case .range:
                periodChip
                quickRanges
            case .today, .all:
                // The screen's header names the period.
                EmptyView()
            }

            if let staffOptions {
                staffRow(staffOptions)
            }
        }
        .sheet(isPresented: $showRange) {
            CashRangePickerSheet(from: filter.from, to: filter.to) { start, end in
                var next = filter
                next.period = .range
                next.from = start
                next.to = end
                onChange(next)
            }
        }
        .sheet(isPresented: $showStaff) {
            CashStaffFilterSheet(options: staffOptions ?? [], selected: filter.staffIds) { ids in
                var next = filter
                next.staffIds = ids
                onChange(next)
            }
        }
    }

    private var periodChip: some View {
        Button {
            showRange = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CcColors.primary)
                Text(filter.periodLabel)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(CcColors.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Change")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(CcColors.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(CcColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// One-tap ranges people ask for most, so the calendar is only needed for anything else.
    private var quickRanges: some View {
        let today = CashDates.today
        let options: [(String, Date, Date)] = [
            ("Yesterday", CashDates.addDays(-1, to: today), CashDates.addDays(-1, to: today)),
            ("Last 7 days", CashDates.addDays(-6, to: today), today),
            ("Last 30 days", CashDates.addDays(-29, to: today), today)
        ]
        func key(_ a: Date, _ b: Date) -> String { CashFormat.apiString(from: a) + "|" + CashFormat.apiString(from: b) }
        return CashChipRow(
            options: options.map { (key($0.1, $0.2), $0.0) },
            selection: key(filter.from, filter.to)
        ) { picked in
            guard let picked, let option = options.first(where: { key($0.1, $0.2) == picked }) else { return }
            var next = filter
            next.period = .range
            next.from = option.1
            next.to = option.2
            onChange(next)
        }
    }

    private func staffRow(_ people: [PersonOption]) -> some View {
        let active = !filter.staffIds.isEmpty
        return HStack(spacing: 8) {
            Image(systemName: active ? "line.3.horizontal.decrease.circle.fill" : "person.3.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(CcColors.primary)
            Text("Staff: ")
                .font(.system(size: 13))
                .foregroundStyle(CcColors.textMuted)
            + Text(filter.staffLabel(people))
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(CcColors.text)
            Spacer(minLength: 4)
            if active {
                Button {
                    var next = filter
                    next.staffIds = []
                    onChange(next)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                        Text("Clear").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(CcColors.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            } else {
                Text("Choose")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(CcColors.primary)
                    .padding(.trailing, 4)
            }
        }
        .lineLimit(1)
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(minHeight: 46)
        .background(active ? CcColors.container : .white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(active ? CcColors.primary.opacity(0.5) : CcColors.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { showStaff = true }
    }
}

/// Android `MonthBar`: ‹ September 2026 › — the month every list on these screens is scoped to.
struct CashMonthBar: View {
    let month: Date
    var onChange: (Date) -> Void

    private var canGoForward: Bool {
        CashDates.startOfMonth(month) < CashDates.startOfMonth(Date())
    }

    var body: some View {
        HStack(spacing: 0) {
            Button {
                onChange(CashDates.addMonths(-1, to: month))
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CcColors.primary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Previous month")

            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundStyle(CcColors.textMuted)
                Text(CashDates.format(month, "MMMM yyyy"))
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(CcColors.text)
            }
            .frame(maxWidth: .infinity)

            Button {
                onChange(CashDates.addMonths(1, to: month))
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(canGoForward ? CcColors.primary : CcColors.textFaint)
                    .frame(width: 44, height: 44)
            }
            .disabled(!canGoForward)
            .accessibilityLabel("Next month")
        }
        .padding(.horizontal, 4)
        .background(CcColors.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(CcColors.border, lineWidth: 1))
    }
}

/// Android `RangePickerDialog`: tap a start day, then an end day; a start alone means that single
/// day. Future days can't be picked.
struct CashRangePickerSheet: View {
    var onPick: (Date, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var start: Date?
    @State private var end: Date?
    @State private var tapped: Date

    init(from: Date, to: Date, onPick: @escaping (Date, Date) -> Void) {
        self.onPick = onPick
        _start = State(initialValue: from)
        _end = State(initialValue: to)
        _tapped = State(initialValue: to)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a date range")
                .font(.system(size: 13))
                .foregroundStyle(CcColors.textMuted)

            HStack(spacing: 12) {
                rangeEnd("From", start)
                Text("→")
                    .font(.system(size: 18))
                    .foregroundStyle(CcColors.textFaint)
                rangeEnd("To", end ?? start)
                Spacer(minLength: 0)
            }

            DatePicker("", selection: $tapped, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(CcColors.primary)
                .onChange(of: tapped) { _, day in
                    let day = CashDates.calendar.startOfDay(for: day)
                    if let first = start, end == nil {
                        start = min(first, day)
                        end = max(first, day)
                    } else {
                        start = day
                        end = nil
                    }
                }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .foregroundStyle(CcColors.textMuted)
                    .padding(.horizontal, 12)
                Button {
                    if let first = start {
                        let last = end ?? first
                        onPick(min(first, last), max(first, last))
                    }
                    dismiss()
                } label: {
                    Text("Show").fontWeight(.bold)
                }
                .foregroundStyle(CcColors.primary)
                .disabled(start == nil)
            }
            .font(.system(size: 15))
        }
        .padding(20)
        .presentationDetents([.large])
        .presentationBackground(.white)
    }

    private func rangeEnd(_ label: String, _ date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(CcColors.textMuted)
            Text(date.map { CashDates.format($0, "d MMM yyyy") } ?? "—")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(CcColors.text)
        }
    }
}

/// Android `StaffFilterSheet`: multi-select of staff with search. Nobody picked means everyone.
struct CashStaffFilterSheet: View {
    let options: [PersonOption]
    var onApply: (Set<Int>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picked: Set<Int>
    @State private var query = ""

    init(options: [PersonOption], selected: Set<Int>, onApply: @escaping (Set<Int>) -> Void) {
        self.options = options
        self.onApply = onApply
        _picked = State(initialValue: selected)
    }

    private var shown: [PersonOption] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return options.filter { q.isEmpty || $0.name.lowercased().contains(q) || $0.role.lowercased().contains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Filter by staff")
                        .font(.system(size: 18, weight: .heavy))
                    Text(picked.isEmpty ? "Everyone is included" : "\(picked.count) selected")
                        .font(.system(size: 12.5))
                        .foregroundStyle(CcColors.textMuted)
                }
                Spacer()
                if !picked.isEmpty {
                    Button("Clear") { picked = [] }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(CcColors.primary)
                }
            }

            CashSearchField(text: $query, placeholder: "Search by name or role")

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(shown) { person in
                        let isOn = picked.contains(person.id)
                        Button {
                            if isOn { picked.remove(person.id) } else { picked.insert(person.id) }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 20))
                                    .foregroundStyle(isOn ? CcColors.primary : CcColors.textFaint)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(person.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(CcColors.text)
                                    if !person.role.isEmpty {
                                        Text(person.role)
                                            .font(.system(size: 12))
                                            .foregroundStyle(CcColors.textMuted)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .background(isOn ? CcColors.container : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    if shown.isEmpty {
                        Text("Nobody matches “\(query)”.")
                            .font(.system(size: 14))
                            .foregroundStyle(CcColors.textMuted)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxHeight: 380)

            CashPrimaryButton(
                title: picked.isEmpty ? "Show all staff" : "Show \(picked.count) staff",
                systemImage: "line.3.horizontal.decrease"
            ) {
                onApply(picked)
                dismiss()
            }
        }
        .padding(16)
        .presentationDetents([.large])
        .presentationBackground(.white)
    }
}

struct CashSearchField: View {
    @Binding var text: String
    var placeholder: String
    var showsClear = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CcColors.textMuted)
            TextField(placeholder, text: $text)
                .font(.system(size: 15))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if showsClear && !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CcColors.textMuted)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(hex: "D1D5DB"), lineWidth: 1))
    }
}

// MARK: - States

/// Android `EmptyState`.
struct CashEmptyState: View {
    let title: String
    let message: String
    var systemImage: String = "tray"

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 26))
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
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
    }
}

/// Android `ErrorState`.
struct CashErrorState: View {
    let message: String
    var onRetry: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 32))
                .foregroundStyle(CcColors.err)
            Text(message)
                .font(.system(size: 13.5))
                .foregroundStyle(CcColors.text)
                .multilineTextAlignment(.center)
            Button(action: onRetry) {
                Text("Try again")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CcColors.primary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .overlay(Capsule().stroke(CcColors.primary, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
    }
}

/// Asks for the next page when a row near the end of the list appears (Android `LoadMoreEffect`).
extension View {
    func cashLoadMore<Item: Identifiable>(_ item: Item, in items: [Item], action: @escaping () -> Void) -> some View {
        onAppear {
            guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
            if index >= items.count - 3 { action() }
        }
    }
}

// MARK: - Buttons

/// Android `PrimaryButton`: brand gradient (flat for any other colour), optional icon, spinner while
/// working.
struct CashPrimaryButton: View {
    let title: String
    var systemImage: String?
    var color: Color = CcColors.primary
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var action: () -> Void

    private var active: Bool { isEnabled && !isLoading }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    if let systemImage {
                        Image(systemName: systemImage).font(.system(size: 16, weight: .bold))
                    }
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .foregroundStyle(.white.opacity(active || isLoading ? 1 : 0.85))
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(fill.opacity(active || isLoading ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: active ? color.opacity(0.35) : .clear, radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!active)
    }

    private var fill: LinearGradient {
        color == CcColors.primary
            ? LinearGradient(colors: [CcColors.deep, CcColors.primary, CcColors.bright], startPoint: .leading, endPoint: .trailing)
            : LinearGradient(colors: [color, color], startPoint: .leading, endPoint: .trailing)
    }
}

/// Android `SecondaryButton`: a tinted fill in its own colour, no outline.
struct CashSecondaryButton: View {
    let title: String
    var systemImage: String?
    var color: Color = CcColors.primary
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 15, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 14.5, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isEnabled ? color : color.opacity(0.4))
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(color.opacity(isEnabled ? 0.1 : 0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

/// Android `IconActionButton`: a square tinted button with room only for its icon.
struct CashIconActionButton: View {
    let systemImage: String
    let label: String
    var color: Color = CcColors.primary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 52, height: 52)
                .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Android `BottomActionBar`: the tray pinned under a screen — rounded top, soft shadow, a handle,
/// an optional summary line above the buttons.
struct CashActionTray<Summary: View, Buttons: View>: View {
    @ViewBuilder var summary: Summary
    @ViewBuilder var buttons: Buttons

    var body: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(CcColors.border)
                .frame(width: 36, height: 4)
            summary
            HStack(spacing: 10) { buttons }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.12), radius: 14, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

extension CashActionTray where Summary == EmptyView {
    init(@ViewBuilder buttons: () -> Buttons) {
        self.summary = EmptyView()
        self.buttons = buttons()
    }
}

/// Android `BarSummary`: a label and value on the left, a status pill on the right.
struct CashBarSummary: View {
    let label: String
    let value: String
    var tone: PillTone?
    var status: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11.5))
                    .foregroundStyle(CcColors.textMuted)
                    .lineLimit(1)
                Text(value)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(CcColors.text)
            }
            Spacer(minLength: 8)
            if let tone, let status {
                CcPill(text: status, tone: tone)
            }
        }
    }
}

/// Android `CountSummary`: what has been counted, and whether it matches the total.
struct CashCountSummary: View {
    let declared: Int
    let counts: DenominationCounts

    var body: some View {
        let counted = counts.cashTotal
        let diff = counted - declared
        let pill: (PillTone, String)? = {
            guard declared > 0 else { return nil }
            if diff == 0 { return (.ok, "Matches") }
            if diff < 0 { return (.warn, "Short \(CashFormat.rupees(-diff))") }
            return (.err, "Over \(CashFormat.rupees(diff))")
        }()
        CashBarSummary(
            label: declared > 0 ? "Counted of \(CashFormat.rupees(declared))" : "Counted",
            value: CashFormat.rupees(counted),
            tone: pill?.0,
            status: pill?.1
        )
    }
}

// MARK: - Dialogs and toast

/// Android `ConfirmDialog`: icon disc, title, body, and a quiet way out beside the action.
struct CashConfirmDialog: View {
    let title: String
    let message: String
    let confirmTitle: String
    var systemImage: String = "questionmark.circle"
    var confirmColor: Color = CcColors.primary
    var dismissTitle: String = "Cancel"
    var onConfirm: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        CcDialog(onDismiss: onDismiss) {
            CashDialogHeader(systemImage: systemImage, accent: confirmColor, title: title, message: message)
        } buttons: {
            CashSecondaryButton(title: dismissTitle, color: CcColors.textMuted, action: onDismiss)
            CashPrimaryButton(title: confirmTitle, color: confirmColor, action: onConfirm)
        }
    }
}

/// Android `ErrorDialog`: validation and server errors as a pop-up the user reads and dismisses.
struct CashErrorDialog: View {
    let message: String
    var title: String = "Can't continue"
    var onDismiss: () -> Void

    var body: some View {
        CcDialog(onDismiss: onDismiss) {
            CashDialogHeader(systemImage: "exclamationmark.circle", accent: CcColors.err, title: title, message: message)
        } buttons: {
            CashPrimaryButton(title: "OK", action: onDismiss)
        }
    }
}

private struct CashDialogHeader: View {
    let systemImage: String
    let accent: Color
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 60, height: 60)
                .background(accent.opacity(0.12), in: Circle())
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
    }
}

extension View {
    /// Android's success snackbar: a passing message, cleared once shown.
    func cashToast(_ message: Binding<String?>) -> some View {
        modifier(CashToastModifier(message: message))
    }

    /// Android `ErrorDialog` bound to an optional message.
    func cashErrorDialog(_ message: Binding<String?>, title: String = "Can't continue") -> some View {
        overlay {
            if let text = message.wrappedValue {
                CashErrorDialog(message: text, title: title) { message.wrappedValue = nil }
            }
        }
    }
}

private struct CashToastModifier: ViewModifier {
    @Binding var message: String?
    @State private var shown = false
    @State private var text = ""

    func body(content: Content) -> some View {
        content
            .onChange(of: message) { _, value in
                guard let value, !value.isEmpty else { return }
                text = value
                shown = true
                message = nil
            }
            .toast(isPresenting: $shown) {
                AlertToast(displayMode: .banner(.pop), type: .regular, title: text)
            }
    }
}

// MARK: - Form fields

/// Android `PickerField`: a label over a tappable field that opens a picker.
struct CashPickerField: View {
    let label: String
    let value: String
    let systemImage: String
    var error: String?
    var isPlaceholder = false
    var action: () -> Void

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
                    Text(value)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isPlaceholder ? CcColors.textFaint : CcColors.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 13))
                        .foregroundStyle(CcColors.textFaint)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 13)
                .background(error != nil ? CcColors.errBg : .white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(error != nil ? CcColors.err : Color(hex: "D1D5DB"), lineWidth: 1)
                )
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

/// Android's outlined text field (`fieldColors`): white fill, grey border, brand when focused,
/// red with a supporting line on error.
struct CashTextField: View {
    @Binding var text: String
    var placeholder: String
    var prefix: String?
    var supporting: String?
    var error: String?
    var minLines = 1
    var keyboard: UIKeyboardType = .default
    var onChange: ((String) -> Void)?

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: minLines > 1 ? .top : .center, spacing: 4) {
                if let prefix {
                    Text(prefix)
                        .font(.system(size: 16))
                        .foregroundStyle(CcColors.textMuted)
                }
                Group {
                    if minLines > 1 {
                        TextField(placeholder, text: binding, axis: .vertical)
                            .lineLimit(minLines...max(minLines, 6))
                    } else {
                        TextField(placeholder, text: binding)
                    }
                }
                .font(.system(size: 16))
                .keyboardType(keyboard)
                .focused($focused)
                .tint(CcColors.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 15)
            .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: focused || error != nil ? 2 : 1)
            )
            if let line = error ?? supporting, !line.isEmpty {
                Text(line)
                    .font(.system(size: 12))
                    .foregroundStyle(error != nil ? CcColors.err : CcColors.textMuted)
                    .padding(.horizontal, 14)
            }
        }
    }

    private var borderColor: Color {
        if error != nil { return CcColors.err }
        return focused ? CcColors.bright : Color(hex: "D1D5DB")
    }

    private var binding: Binding<String> {
        Binding(
            get: { text },
            set: { value in
                if let onChange { onChange(value) } else { text = value }
            }
        )
    }
}

/// Android `DetailLine`: a fixed-width label and its value.
struct CashDetailLine: View {
    let label: String
    let value: String
    var labelWidth: CGFloat = 100
    var trailingValue = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .font(.system(size: trailingValue ? 12.5 : 13))
                .foregroundStyle(CcColors.textMuted)
                .frame(width: labelWidth, alignment: .leading)
            Text(value)
                .font(.system(size: trailingValue ? 13 : 13.5, weight: .semibold))
                .foregroundStyle(CcColors.text)
                .multilineTextAlignment(trailingValue ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: trailingValue ? .trailing : .leading)
        }
    }
}

/// Android `PersonPickerDialog`: search the staff list and pick one.
struct CashPersonPicker: View {
    let state: PeopleState
    let selected: PersonOption?
    var onRetry: () -> Void
    var onPick: (PersonOption) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var shown: [PersonOption] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return state.items.filter { q.isEmpty || $0.name.lowercased().contains(q) || $0.role.lowercased().contains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose a person")
                .font(.system(size: 20, weight: .bold))
            CashSearchField(text: $query, placeholder: "Search by name or role")
            if state.isLoading {
                CcLoadingBlock()
            } else if let error = state.error {
                CashErrorState(message: error, onRetry: onRetry)
            } else {
                if shown.isEmpty {
                    Text("Nobody matches “\(query)”.")
                        .font(.system(size: 13))
                        .foregroundStyle(CcColors.textMuted)
                }
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(shown) { person in
                            Button {
                                onPick(person)
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    Text(cashInitials(person.name))
                                        .font(.system(size: 12, weight: .heavy))
                                        .foregroundStyle(CcColors.primary)
                                        .frame(width: 34, height: 34)
                                        .background(CcColors.container, in: Circle())
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(person.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(CcColors.text)
                                        if !person.role.isEmpty {
                                            Text(person.role)
                                                .font(.system(size: 12))
                                                .foregroundStyle(CcColors.textMuted)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 10)
                                .background(
                                    person.id == selected?.id ? CcColors.container : .clear,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 380)
            }
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .foregroundStyle(CcColors.textMuted)
            }
        }
        .padding(20)
        .presentationDetents([.medium, .large])
        .presentationBackground(.white)
    }
}

/// Android `AdvanceDatePickerDialog` / the Amount Taken date picker: one day between `earliest` (if
/// any) and today.
struct CashDatePickerSheet: View {
    var earliest: Date?
    var onPick: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date

    init(date: Date, earliest: Date? = nil, onPick: @escaping (Date) -> Void) {
        self.earliest = earliest
        self.onPick = onPick
        _date = State(initialValue: date)
    }

    var body: some View {
        VStack(spacing: 12) {
            Group {
                if let earliest {
                    DatePicker("", selection: $date, in: earliest...Date(), displayedComponents: .date)
                } else {
                    DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                }
            }
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(CcColors.primary)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .foregroundStyle(CcColors.textMuted)
                    .padding(.horizontal, 12)
                Button {
                    onPick(CashDates.calendar.startOfDay(for: date))
                    dismiss()
                } label: {
                    Text("OK").fontWeight(.bold)
                }
                .foregroundStyle(CcColors.primary)
            }
        }
        .padding(20)
        .presentationDetents([.medium, .large])
        .presentationBackground(.white)
    }
}

// MARK: - Attachments

/// Android `AttachmentField`: take a photo or choose a JPG / PNG / PDF; shows the picked file with a
/// remove button, and the rules (or the error) underneath.
struct CashAttachmentField: View {
    let picked: CashAttachment?
    let isReading: Bool
    let error: String?
    var onPhoto: (UIImage) -> Void
    var onFile: (URL) -> Void
    var onRemove: () -> Void

    @State private var showCamera = false
    @State private var showFiles = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isReading {
                HStack(spacing: 10) {
                    ProgressView().tint(CcColors.primary)
                    Text("Preparing the file…")
                        .font(.system(size: 13))
                        .foregroundStyle(CcColors.textMuted)
                    Spacer()
                }
                .padding(14)
                .background(CcColors.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if let picked {
                HStack(spacing: 10) {
                    Group {
                        if picked.isImage, let image = UIImage(data: picked.data) {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(CcColors.err)
                        }
                    }
                    .frame(width: 48, height: 48)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(picked.name)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(CcColors.text)
                            .lineLimit(1)
                        Text(picked.sizeLabel)
                            .font(.system(size: 12))
                            .foregroundStyle(CcColors.textMuted)
                    }
                    Spacer()
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(CcColors.textMuted)
                            .frame(width: 40, height: 40)
                    }
                    .accessibilityLabel("Remove attachment")
                }
                .padding(8)
                .background(CcColors.container, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                HStack(spacing: 8) {
                    attachButton("Take photo", "camera.fill") { showCamera = true }
                    attachButton("Choose file", "paperclip") { showFiles = true }
                }
            }
            Text(error ?? "JPG, PNG or PDF, up to 5 MB")
                .font(.system(size: 11.5))
                .foregroundStyle(error != nil ? CcColors.err : CcColors.textFaint)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker(
                preferRearCamera: true,
                onImageCaptured: { image in
                    showCamera = false
                    onPhoto(image)
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: CashAttachmentReader.allowedTypes) { result in
            if case .success(let url) = result { onFile(url) }
        }
    }

    private func attachButton(_ title: String, _ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).font(.system(size: 16))
                Text(title).font(.system(size: 13.5, weight: .semibold))
            }
            .foregroundStyle(CcColors.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(CcColors.primary.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Android `AttachmentLink`: an image shows as a thumbnail that opens full screen; a PDF opens in the
/// system viewer.
struct CashAttachmentLink: View {
    let url: String

    @Environment(\.openURL) private var openURL
    @State private var showImage = false

    private var isPdf: Bool {
        (url.split(separator: "?").first.map(String.init) ?? url).lowercased().hasSuffix(".pdf")
    }

    var body: some View {
        if isPdf {
            Button {
                if let link = URL(string: url.trim) { openURL(link) }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(CcColors.err)
                    Text("View PDF")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(CcColors.primary)
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12))
                        .foregroundStyle(CcColors.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(CcColors.container, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        } else {
            Button {
                showImage = true
            } label: {
                HStack(spacing: 10) {
                    RemoteImage(url: url)
                        .frame(width: 56, height: 56)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Bill / document")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(CcColors.text)
                        Text("Tap to view")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CcColors.primary)
                    }
                    .padding(.trailing, 10)
                }
                .padding(6)
                .background(CcColors.container, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .fullScreenCover(isPresented: $showImage) {
                CashImageViewer(url: url)
            }
        }
    }
}

/// Android `ImageViewerDialog`: full screen, pinch to zoom, drag to pan, double tap toggles 2.5×.
private struct CashImageViewer: View {
    let url: String

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var failed = false
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in scale = min(max(lastScale * value, 1), 5) }
                            .onEnded { _ in
                                lastScale = scale
                                if scale == 1 { offset = .zero; lastOffset = .zero }
                            }
                            .simultaneously(with: DragGesture()
                                .onChanged { value in
                                    guard scale > 1 else { return }
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in lastOffset = offset })
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if scale > 1 {
                                scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
                            } else {
                                scale = 2.5; lastScale = 2.5
                            }
                        }
                    }
            } else if failed {
                Text("Couldn't load the image")
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.16), in: Circle())
            }
            .padding(12)
            .accessibilityLabel("Close")
        }
        .task(id: url) {
            guard let link = URL(string: url.trim) else { failed = true; return }
            do {
                let (data, _) = try await URLSession.shared.data(from: link)
                if let loaded = UIImage(data: data) { image = loaded } else { failed = true }
            } catch {
                failed = true
            }
        }
    }
}
