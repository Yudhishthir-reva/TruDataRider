//
//  OperationsScreen.swift
//  TrudataRider
//

import SwiftUI

struct OperationsScreen: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: DashboardViewModel
    let type: RiderOperationsType
    var onNavigate: (String) -> Void
    var onHome: (() -> Void)?

    private let appBlue = Color(red: 0.00, green: 0.20, blue: 0.31)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "DEE6F8"), Color(hex: "E7EBEF")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                let items = viewModel.items(for: type)
                if items.isEmpty {
                    Text("No items available for this section")
                        .font(.system(size: 16))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(items) { item in
                                RiderDashboardItemCard(item: item, onNavigate: onNavigate)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
            }

            Text(type.title)
                .font(.system(size: 22, weight: .semibold))
                .lineLimit(1)

            Spacer()

            Button { viewModel.loadHome(isRefresh: true) } label: {
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
}
