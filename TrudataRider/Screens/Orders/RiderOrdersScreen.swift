//
//  RiderOrdersScreen.swift
//  TrudataRider
//

import SwiftUI

private enum OrderListTheme {
    static let appBlue = Color(red: 0.00, green: 0.20, blue: 0.31)
    static let buttonBlue = Color(red: 0.00, green: 0.48, blue: 0.95)
    static let lightBackground = Color(red: 0.96, green: 0.97, blue: 0.99)
}

struct RiderOrdersScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RiderOrdersViewModel()
    @State private var showToast = false

    var onHome: () -> Void

    var body: some View {
        ZStack {
            OrderListTheme.lightBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                tabBar
                content
            }

            if let pendingOrder = viewModel.pendingDeliveryOrder {
                DistanceAlertModalView(
                    shopName: pendingOrder.shopName,
                    distanceText: viewModel.pendingDeliveryDistanceText,
                    onCancel: {
                        viewModel.cancelDistanceAlert()
                    },
                    onDeliverAnyway: {
                        viewModel.confirmDeliverAnyway()
                    }
                )
                .zIndex(999)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadOrders() }
        .onChange(of: viewModel.toastMessage) { _, message in
            showToast = !(message?.isEmptyString ?? true)
        }
        .toast(isPresenting: $showToast) {
            AlertToast(type: .regular, title: viewModel.toastMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
            }

            Text(viewModel.headerTitle)
                .font(.system(size: 22, weight: .semibold))
                .lineLimit(1)

            Spacer()

            Button { viewModel.loadOrders() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 20, weight: .medium))
            }

            Button(action: onHome) {
                Image(systemName: "house.fill")
                    .font(.system(size: 20, weight: .medium))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
        .padding(.top, 10)
        .background(OrderListTheme.appBlue.ignoresSafeArea(edges: .top))
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.availableTabs, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedTab = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(viewModel.selectedTab == tab ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(viewModel.selectedTab == tab ? OrderListTheme.appBlue : Color.clear)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.9))
        .clipShape(Capsule())
        .overlay {
            Capsule().stroke(Color.gray.opacity(0.15), lineWidth: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.pickupOrders.isEmpty && viewModel.collectedOrders.isEmpty {
            ProgressView()
                .tint(OrderListTheme.appBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage,
                  viewModel.pickupOrders.isEmpty,
                  viewModel.collectedOrders.isEmpty,
                  viewModel.toDeliverOrders.isEmpty,
                  viewModel.deliveredOrders.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") { viewModel.loadOrders() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(OrderListTheme.appBlue)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        switch viewModel.selectedTab {
                        case .awaiting:
                            if !viewModel.pickupOrders.isEmpty {
                                sectionHeader(title: "To Pick Up", count: viewModel.pickupOrders.count)
                                ForEach(viewModel.pickupOrders) { order in
                                    RiderOrderCard(order: order, isUpdating: viewModel.updatingOrderId == order.orderId) {
                                        viewModel.markPickedUp(order)
                                    }
                                }
                            }
                            if !viewModel.collectedOrders.isEmpty {
                                sectionHeader(title: "Collected", count: viewModel.collectedOrders.count)
                                ForEach(viewModel.collectedOrders) { order in
                                    RiderOrderCard(order: order, isUpdating: false) {}
                                }
                            }
                            if viewModel.pickupOrders.isEmpty && viewModel.collectedOrders.isEmpty {
                                emptyState("No awaiting orders.")
                            }
                        case .toDeliver:
                            if viewModel.toDeliverOrders.isEmpty {
                                emptyState("No orders to deliver.")
                            } else {
                                ForEach(viewModel.toDeliverOrders) { order in
                                    RiderOrderCard(
                                        order: order,
                                        isUpdating: viewModel.updatingOrderId == order.orderId,
                                        onPrimaryAction: {
                                            viewModel.handleDeliverSlide(order: order)
                                        },
                                        onMarkNotAvailable: {
                                            viewModel.markSellerNotAvailable(order)
                                        }
                                    )
                                }
                            }
                        case .completed:
                            if viewModel.deliveredOrders.isEmpty {
                                emptyState("No completed orders.")
                            } else {
                                ForEach(viewModel.deliveredOrders) { order in
                                    RiderOrderCard(order: order, isUpdating: false) {}
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
                }

                if viewModel.selectedTab == .awaiting, viewModel.canStartDelivery {
                    SlideToActionBar(
                        title: "Slide to Start Delivery",
                        isLoading: viewModel.isStartingDelivery
                    ) {
                        viewModel.startDelivery()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .padding(.top, 4)
                }
            }
        }
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
    }

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            HStack(spacing: 9) {
                Capsule()
                    .fill(OrderListTheme.appBlue)
                    .frame(width: 5, height: 24)
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(OrderListTheme.appBlue)
            }
            Spacer()
            Text("\(count) Order(s)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.purple)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.10))
                .clipShape(Capsule())
        }
    }
}

struct SlideToActionBar: View {
    let title: String
    var isLoading: Bool = false
    let onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let buttonSize: CGFloat = 48
            let maxDrag = max(geo.size.width - buttonSize - 10, 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(red: 0.89, green: 0.93, blue: 0.98))

                Text(isLoading ? "Please wait..." : title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(OrderListTheme.appBlue)
                    .frame(maxWidth: .infinity)

                Circle()
                    .fill(OrderListTheme.appBlue)
                    .frame(width: buttonSize, height: buttonSize)
                    .overlay {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .offset(x: dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard !isLoading else { return }
                                dragOffset = min(max(0, value.translation.width), maxDrag)
                            }
                            .onEnded { _ in
                                if dragOffset > maxDrag * 0.65 {
                                    dragOffset = maxDrag
                                    onComplete()
                                }
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    dragOffset = 0
                                }
                            }
                    )
            }
            .padding(5)
        }
        .frame(height: 58)
    }
}
