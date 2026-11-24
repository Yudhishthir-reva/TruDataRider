//
//  DenominationSummaryView.swift
//  TrudataRider
//
//  Android `SummaryTab`: the Summary tab inside Cash Collection. Period and staff filters sit on
//  top; below them the figures animate in every time a new answer arrives, so switching Today →
//  Month visibly re-counts rather than silently swapping numbers.
//

import SwiftUI

/// A summary line resolved to its `Denomination`; unknown fields from a newer server are dropped.
private struct SummaryLine: Identifiable {
    let denomination: Denomination
    let qty: Int
    let total: Double

    var id: String { denomination.apiKey }
}

private func summaryLines(_ items: [SummaryDenomination]) -> [SummaryLine] {
    items.compactMap { item in
        item.denomination.map { SummaryLine(denomination: $0, qty: item.qty, total: item.total) }
    }
}

private func percent(_ share: Double) -> String {
    let p = share * 100
    if p <= 0 { return "0%" }
    if p < 0.1 { return "<0.1%" }
    return "\(Double(Int(p * 10)) / 10)%"
}

private func pcs(_ n: Int) -> String { n == 1 ? "1 pc" : "\(n) pcs" }

private let coinGold = Color(hex: "D4A72C")

struct DenominationSummaryView: View {

    @ObservedObject var viewModel: DenominationSummaryViewModel

    var body: some View {
        VStack(spacing: 10) {
            CashFilterBar(
                filter: viewModel.filter,
                staffOptions: viewModel.canFilterStaff ? viewModel.staffOptions : nil
            ) { viewModel.filterChanged($0) }

            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.data == nil {
            SummarySkeleton()
        } else if let error = viewModel.error, viewModel.data == nil {
            CashErrorState(message: error) { viewModel.refresh() }
        } else if let data = viewModel.data {
            if data.summary.totalEntries == 0 && !viewModel.isLoading {
                VStack(spacing: 0) {
                    CashEmptyState(
                        title: "No cash counted",
                        message: "Nothing was approved \(viewModel.filter.periodPhrase)"
                            + (viewModel.filter.staffIds.isEmpty ? "." : " by \(viewModel.staffLabel)."),
                        systemImage: "banknote"
                    )
                    if viewModel.filter.period == .today || viewModel.filter.period == .range {
                        CashSecondaryButton(title: "See this month", systemImage: "calendar") {
                            viewModel.seeThisMonth()
                        }
                        .fixedSize()
                    }
                }
            } else {
                let version = viewModel.loadVersion
                let lines = summaryLines(data.summary.denominations)
                TotalHero(viewModel: viewModel, data: data, lines: lines)
                    .cashEntrance(version: version, index: 0)
                NotesCoinsCard(lines: lines, version: version)
                    .cashEntrance(version: version, index: 1)
                DenominationBars(lines: lines, grand: data.summary.grandTotalAmount, version: version)
                    .cashEntrance(version: version, index: 2)
                if !data.staffWise.isEmpty && (viewModel.canFilterStaff || data.staffWise.count > 1) {
                    StaffBreakdown(viewModel: viewModel, data: data)
                        .cashEntrance(version: version, index: 3)
                }
            }
        }
    }
}

// MARK: - Figures

private struct TotalHero: View {
    @ObservedObject var viewModel: DenominationSummaryViewModel
    let data: DenominationSummaryResponse
    let lines: [SummaryLine]

    var body: some View {
        let notes = lines.filter { $0.denomination.kind == .note }.reduce(0) { $0 + $1.qty }
        let coins = lines.filter { $0.denomination.kind == .coin }.reduce(0) { $0 + $1.qty }
        CashHero {
            CashHeroLabel(text: "Approved cash counted")
            CashCountingAmount(target: data.summary.grandTotalAmount, version: viewModel.loadVersion)
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(.white)
            Text(viewModel.filter.periodLabel + (viewModel.filter.staffIds.isEmpty ? "" : " · \(viewModel.staffLabel)"))
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.8))
            if viewModel.isRefreshing {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.white)
                    .padding(.top, 6)
            }
            HStack(spacing: 6) {
                CashHeroStat(label: "Entries", value: "\(data.summary.totalEntries)")
                CashHeroStat(label: "Notes", value: pcs(notes))
                CashHeroStat(label: "Coins", value: pcs(coins))
            }
            .padding(.top, 6)
        }
    }
}

private struct NotesCoinsCard: View {
    let lines: [SummaryLine]
    let version: Int

    @State private var sweep: Double = 0

    var body: some View {
        let notes = lines.filter { $0.denomination.kind == .note }
        let coins = lines.filter { $0.denomination.kind == .coin }
        let notesAmount = notes.reduce(0) { $0 + $1.total }
        let coinsAmount = coins.reduce(0) { $0 + $1.total }
        let sum = notesAmount + coinsAmount > 0 ? notesAmount + coinsAmount : 1
        let notesShare = notesAmount / sum
        // Any non-zero share gets at least a few degrees, so a sliver of coins is still visible.
        let notesDeg = notesAmount > 0 ? min(max(360 * notesShare, 6), 354) : 0
        let coinsDeg = coinsAmount > 0 ? 360 - notesDeg : 0
        // A small gap either side keeps the two segments reading as two things.
        let gap = notesAmount > 0 && coinsAmount > 0 ? 2.0 : 0

        CashSection(title: "Notes vs coins", systemImage: "chart.pie", subtitle: "Share of the amount") {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(CcColors.track, lineWidth: 16)
                    if notesDeg * sweep > gap {
                        Circle()
                            .trim(from: 0, to: (notesDeg * sweep - gap) / 360)
                            .stroke(CcColors.primary, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                            .rotationEffect(.degrees(-90))
                    }
                    if coinsDeg * sweep > gap {
                        Circle()
                            .trim(from: 0, to: (coinsDeg * sweep - gap) / 360)
                            .stroke(coinGold, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                            .rotationEffect(.degrees(-90 + notesDeg))
                    }
                    VStack(spacing: 0) {
                        Text("\(Double(Int(notesShare * 1000)) / 10)%")
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(CcColors.text)
                        Text("in notes")
                            .font(.system(size: 10.5))
                            .foregroundStyle(CcColors.textMuted)
                    }
                }
                .padding(8)
                .frame(width: 112, height: 112)

                VStack(alignment: .leading, spacing: 12) {
                    legend(CcColors.primary, "Notes", CashFormat.rupees(notesAmount), pcs(notes.reduce(0) { $0 + $1.qty }))
                    legend(coinGold, "Coins", CashFormat.rupees(coinsAmount), pcs(coins.reduce(0) { $0 + $1.qty }))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear { replay() }
        .onChange(of: version) { _, _ in replay() }
    }

    private func replay() {
        sweep = 0
        withAnimation(.easeInOut(duration: 1.1)) { sweep = 1 }
    }

    private func legend(_ color: Color, _ label: String, _ amount: String, _ pieces: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(color).frame(width: 10, height: 10).padding(.top, 4)
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.system(size: 12)).foregroundStyle(CcColors.textMuted)
                Text(amount).font(.system(size: 16, weight: .heavy)).foregroundStyle(CcColors.text)
                Text(pieces).font(.system(size: 11.5)).foregroundStyle(CcColors.textFaint)
            }
        }
    }
}

private struct DenominationBars: View {
    let lines: [SummaryLine]
    let grand: Double
    let version: Int

    @State private var showEmpty = false

    var body: some View {
        let used = lines.filter { $0.qty > 0 }
        let unused = lines.filter { $0.qty == 0 }
        // Bars are scaled to the largest denomination, not the total, so small ones stay visible.
        let largest = used.map(\.total).max().flatMap { $0 > 0 ? $0 : nil } ?? 1
        let shown = showEmpty ? lines : used

        CashSection(title: "By denomination", systemImage: "banknote", subtitle: "\(used.count) of \(lines.count) used · bar = amount") {
            VStack(spacing: 12) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, line in
                    BarRow(
                        line: line,
                        fraction: line.total > 0 ? max(line.total / largest, 0.02) : 0,
                        share: grand > 0 ? line.total / grand : 0,
                        version: version,
                        index: index
                    )
                }
            }
            if !unused.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.26)) { showEmpty.toggle() }
                } label: {
                    Text(showEmpty
                         ? "Hide unused"
                         : "Show \(unused.count) unused (\(unused.map { "₹\($0.denomination.value) \($0.denomination.kind.rawValue)" }.joined(separator: ", ")))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CcColors.primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct BarRow: View {
    let line: SummaryLine
    let fraction: Double
    let share: Double
    let version: Int
    let index: Int

    @State private var progress: Double = 0

    var body: some View {
        let tint = denominationTint(line.denomination)
        HStack(spacing: 10) {
            DenominationBadge(denomination: line.denomination)
            VStack(spacing: 5) {
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text("× \(line.qty)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(CcColors.text)
                    if line.denomination.kind == .note && line.qty >= 100 {
                        Text("  " + cashBundleText(line.qty))
                            .font(.system(size: 11))
                            .foregroundStyle(CcColors.textFaint)
                    }
                    Spacer(minLength: 4)
                    Text(CashFormat.rupees(line.total))
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(CcColors.text)
                }
                HStack(spacing: 0) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            CcColors.track
                            LinearGradient(colors: [tint.opacity(0.65), tint], startPoint: .leading, endPoint: .trailing)
                                .frame(width: proxy.size.width * progress)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    .frame(height: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text(percent(share))
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(CcColors.textMuted)
                        .frame(width: 52, alignment: .trailing)
                }
            }
        }
        .opacity(line.qty == 0 ? 0.45 : 1)
        .onAppear { replay() }
        .onChange(of: version) { _, _ in replay() }
    }

    private func replay() {
        progress = 0
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.12 + Double(index) * 0.055)) {
            progress = min(max(fraction, 0), 1)
        }
    }
}

private struct StaffBreakdown: View {
    @ObservedObject var viewModel: DenominationSummaryViewModel
    let data: DenominationSummaryResponse

    var body: some View {
        let staff = data.staffWise.sorted { $0.totalAmount > $1.totalAmount }
        let grand = data.summary.grandTotalAmount > 0 ? data.summary.grandTotalAmount : 1
        CashSection(
            title: "By staff",
            systemImage: "person.3",
            subtitle: "\(staff.count) \(staff.count == 1 ? "person" : "people") · tap one to see their notes",
            accent: CcColors.info
        ) {
            VStack(spacing: 10) {
                ForEach(Array(staff.enumerated()), id: \.element.id) { rank, person in
                    StaffRow(
                        staff: person,
                        rank: rank,
                        share: person.totalAmount / grand,
                        version: viewModel.loadVersion,
                        expanded: viewModel.expandedStaff.contains(person.staffId),
                        canFocus: viewModel.canFilterStaff && viewModel.filter.staffIds != [person.staffId],
                        onToggle: { withAnimation(.easeInOut(duration: 0.26)) { viewModel.toggleExpanded(person.staffId) } },
                        onOnly: { viewModel.onlyStaff(person.staffId) }
                    )
                }
            }
        }
    }
}

private let rankColors = [Color(hex: "FFB300"), Color(hex: "78909C"), Color(hex: "8D6E63")]

private struct StaffRow: View {
    let staff: StaffSummary
    let rank: Int
    let share: Double
    let version: Int
    let expanded: Bool
    let canFocus: Bool
    var onToggle: () -> Void
    var onOnly: () -> Void

    @State private var progress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(cashInitials(staff.staffName))
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(CcColors.primary)
                    .frame(width: 40, height: 40)
                    .background(CcColors.container, in: Circle())
                    .overlay(Circle().stroke(rank < rankColors.count ? rankColors[rank] : CcColors.container, lineWidth: 2))
                VStack(alignment: .leading, spacing: 1) {
                    Text(staff.staffName.isEmpty ? "Staff #\(staff.staffId)" : staff.staffName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(CcColors.text)
                        .lineLimit(1)
                    Text("\(staff.entries) \(staff.entries == 1 ? "entry" : "entries") · \(percent(share)) of total")
                        .font(.system(size: 11.5))
                        .foregroundStyle(CcColors.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(CashFormat.rupees(staff.totalAmount))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(CcColors.text)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CcColors.textFaint)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
                    .accessibilityLabel(expanded ? "Collapse" : "Expand")
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    CcColors.track
                    CcColors.info.frame(width: proxy.size.width * progress).clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3))

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    FlowLayoutChips(lines: summaryLines(staff.denominations).filter { $0.qty > 0 })
                    if canFocus {
                        Button(action: onOnly) {
                            Text("Show only this person")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(CcColors.primary)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(expanded ? CcColors.page : .white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(expanded ? CcColors.primary.opacity(0.35) : CcColors.divider, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .onAppear { replay() }
        .onChange(of: version) { _, _ in replay() }
    }

    private func replay() {
        progress = 0
        withAnimation(.easeInOut(duration: 0.8).delay(0.2 + Double(rank) * 0.07)) {
            progress = min(max(share, 0), 1)
        }
    }
}

/// Android `FlowRow` of `MiniDenomChip`s.
private struct FlowLayoutChips: View {
    let lines: [SummaryLine]

    var body: some View {
        CashFlowLayout(spacing: 6) {
            ForEach(lines) { line in
                let tint = denominationTint(line.denomination)
                HStack(spacing: 6) {
                    Group {
                        if line.denomination.kind == .note {
                            RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 12, height: 9)
                        } else {
                            Circle().fill(tint).frame(width: 9, height: 9)
                        }
                    }
                    Text("₹\(line.denomination.value) × \(line.qty)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(CcColors.text)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

/// Wraps its children onto as many rows as they need.
struct CashFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Loading

private struct SummarySkeleton: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 16).fill(CcColors.primary.opacity(0.25)).frame(height: 150)
            RoundedRectangle(cornerRadius: 14).fill(Color(hex: "E5E9E7")).frame(height: 140)
            VStack(spacing: 14) {
                ForEach(0..<5, id: \.self) { i in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 5).fill(Color(hex: "E5E9E7")).frame(width: 60, height: 30)
                        GeometryReader { proxy in
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color(hex: "E5E9E7"))
                                .frame(width: proxy.size.width * (0.9 - Double(i) * 0.12), height: 10)
                                .frame(maxHeight: .infinity, alignment: .center)
                        }
                        .frame(height: 30)
                    }
                }
            }
            .padding(12)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
        }
        .opacity(pulse ? 0.9 : 0.45)
        .onAppear {
            withAnimation(.linear(duration: 0.75).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

// MARK: - Motion

/// Android `animatedNumber`: counts from 0 up to `target`, restarting when `version` changes; lands
/// exactly on `target`.
struct CashCountingAmount: View {
    let target: Double
    let version: Int

    @State private var shown: Double = 0

    var body: some View {
        CountingText(value: shown, target: target)
            .onAppear { replay() }
            .onChange(of: version) { _, _ in replay() }
    }

    private func replay() {
        shown = 0
        withAnimation(.easeInOut(duration: 1.0)) { shown = target }
    }

    private struct CountingText: View, Animatable {
        var value: Double
        let target: Double

        var animatableData: Double {
            get { value }
            set { value = newValue }
        }

        var body: some View {
            Text(CashFormat.rupees(value == target ? target : value.rounded()))
        }
    }
}

extension View {
    /// Android `Entrance`: fades and lifts in, staggered by `index`, each time `version` changes.
    func cashEntrance(version: Int, index: Int) -> some View {
        modifier(CashEntrance(version: version, index: index))
    }
}

private struct CashEntrance: ViewModifier {
    let version: Int
    let index: Int

    @State private var progress: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .offset(y: (1 - progress) * 24)
            .onAppear { replay() }
            .onChange(of: version) { _, _ in replay() }
    }

    private func replay() {
        progress = 0
        withAnimation(.easeOut(duration: 0.38).delay(Double(index) * 0.07)) { progress = 1 }
    }
}
