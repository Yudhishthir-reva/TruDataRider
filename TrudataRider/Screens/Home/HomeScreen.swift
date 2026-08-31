//
//  HomeScreen.swift
//  TrudataRider
//

import SwiftUI

enum HomeDestination: Hashable {
    case riderOrders
    case riderOrderHistory
    case riderTravelHistory
    case vehicleManagement(vehicleId: String)
    case achievementHistory
    case sellerList
    case sellerDetail(sellerId: String)
    case addPayment(sellerId: String, sellerName: String)
    case billSettlement(sellerId: String)
    case markAttendance
    case viewLeaves
    case regularizationRequests
    case expenseList
    case operations(RiderOperationsType)
    case profile
    case support(salesNumber: String, riderNumber: String)
    case placeholder(title: String)
}

struct HomeScreen: View {

    @StateObject private var viewModel = DashboardViewModel()
    @ObservedObject private var permissionManager = PermissionManager.shared
    @State private var showLogoutDialog = false
    @State private var navigationPath = NavigationPath()
    @State private var didRedirectToAttendance = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            homeContent
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: HomeDestination.self) { destination in
                    switch destination {
                    case .riderOrders:
                        RiderOrdersScreen(onHome: { navigationPath = NavigationPath() })
                    case .riderOrderHistory:
                        TodayRiderOrderHistoryView(onHome: { navigationPath = NavigationPath() })
                    case .riderTravelHistory:
                        TravelHistoryView(onHome: { navigationPath = NavigationPath() })
                    case .vehicleManagement(let vehicleId):
                        VehicleManagementView(
                            vehicleId: vehicleId,
                            onHome: { navigationPath = NavigationPath() }
                        )
                    case .achievementHistory:
                        AchievementHistoryView(onHome: { navigationPath = NavigationPath() })
                    case .sellerList:
                        SellerListView(
                            onHome: { navigationPath = NavigationPath() },
                            onOpenSeller: { id in
                                navigationPath.append(HomeDestination.sellerDetail(sellerId: id))
                            }
                        )
                    case .sellerDetail(let sellerId):
                        SellerDetailView(
                            sellerId: sellerId,
                            onHome: { navigationPath = NavigationPath() },
                            onAddPayment: { id in
                                navigationPath.append(
                                    HomeDestination.addPayment(sellerId: id, sellerName: "Add Payment")
                                )
                            },
                            onBillSettlement: { id in
                                navigationPath.append(HomeDestination.billSettlement(sellerId: id))
                            }
                        )
                    case .addPayment(let sellerId, let sellerName):
                        AddPaymentScreen(
                            sellerId: Int(sellerId) ?? 0,
                            appBarTitle: sellerName.isEmptyString ? "Add Payment" : sellerName,
                            onHome: { navigationPath = NavigationPath() }
                        )
                    case .billSettlement(let sellerId):
                        BillSettlementScreen(
                            sellerId: Int(sellerId) ?? 0,
                            onHome: { navigationPath = NavigationPath() }
                        )
                    case .markAttendance:
                        MarkAttendanceScreen(onHome: { navigationPath = NavigationPath() })
                    case .viewLeaves:
                        LeaveListScreen(onHome: { navigationPath = NavigationPath() })
                    case .regularizationRequests:
                        RegularizationListScreen(onHome: { navigationPath = NavigationPath() })
                    case .expenseList:
                        ExpenseListScreen(onHome: { navigationPath = NavigationPath() })
                    case .operations(let type):
                        OperationsScreen(
                            viewModel: viewModel,
                            type: type,
                            onNavigate: navigate,
                            onHome: { navigationPath = NavigationPath() }
                        )
                    case .profile:
                        ProfileView(onHome: { navigationPath = NavigationPath() })
                    case .support(let salesNumber, let riderNumber):
                        SupportView(
                            salesNumber: salesNumber,
                            riderNumber: riderNumber,
                            onHome: { navigationPath = NavigationPath() }
                        )
                    case .placeholder(let title):
                        PlaceholderScreen(title: title)
                    }
                }
        }
    }

    private var homeContent: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "DEE6F8"), Color(hex: "E7EBEF")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if permissionManager.canShowDashboard {
                if viewModel.maintenanceMode {
                    MaintenanceScreen()
                } else {
                    VStack(spacing: 0) {
                        HomeAppBar(
                            title: viewModel.screenTitle,
                            role: viewModel.displayRole,
                            profileUrl: viewModel.profileUrl,
                            onProfileTap: { navigationPath.append(HomeDestination.profile) },
                            onRefresh: { viewModel.loadHome(isRefresh: true) },
                            onLogout: { showLogoutDialog = true }
                        )
                        dashboardBody
                    }
                }
            } else {
                PermissionRequestView(
                    isLocationPermanentlyDenied: permissionManager.isLocationPermanentlyDenied,
                    showNotificationPermission: permissionManager.needsNotificationPermission,
                    showLocationServicesDisabled: !permissionManager.locationServicesEnabled,
                    onGrantPermission: { permissionManager.requestPermissions() },
                    onOpenSettings: { permissionManager.openAppSettings() },
                    onEnableLocationServices: { permissionManager.openLocationSettings() }
                )
            }
        }
        .onAppear {
            permissionManager.refreshStatus()
            if permissionManager.canShowDashboard {
                viewModel.loadHomeIfNeeded()
            }
            redirectToAttendanceIfNeeded()
        }
        .onChange(of: permissionManager.canShowDashboard) { _, canShow in
            if canShow { viewModel.loadHomeIfNeeded() }
        }
        .onChange(of: viewModel.attendanceScreen) { _, _ in
            redirectToAttendanceIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            permissionManager.refreshStatus()
            if permissionManager.canShowDashboard {
                viewModel.loadHomeForResume()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didReceivePushNotification)) { notification in
            if let userInfo = notification.object as? [AnyHashable: Any] {
                handlePushNotification(userInfo)
            } else {
                viewModel.loadHome(isRefresh: true)
            }
        }
        .alert("Logout", isPresented: $showLogoutDialog) {
            Button("Cancel", role: .cancel) {}
            Button("Logout", role: .destructive) { viewModel.logout() }
        } message: {
            Text("Are you sure you want to logout?")
        }
    }

    @ViewBuilder
    private var dashboardBody: some View {
        if viewModel.isLoading && viewModel.response == nil {
            ProgressView()
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.response == nil {
            VStack(spacing: 12) {
                Text(error)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                Button(error.lowercased().contains("token") ? "Logout" : "Retry") {
                    if error.lowercased().contains("token") {
                        viewModel.softLogout()
                    } else {
                        viewModel.loadHome(isRefresh: true)
                    }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DashboardTheme.primaryBlue)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.homeItems) { item in
                        RiderDashboardItemCard(item: item, onNavigate: navigate)
                    }
                    OtherOperationsCard(operations: ["Activity", "Seller", "Actions"]) { name in
                        if let type = RiderOperationsType(rawValue: name) {
                            navigationPath.append(HomeDestination.operations(type))
                        }
                    }
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            .refreshable {
                viewModel.loadHome(isRefresh: true)
            }
        }
    }

    private func navigate(_ route: String) {
        switch route {
        case "rider_orders":
            navigationPath.append(HomeDestination.riderOrders)
        case "rider_order_history":
            navigationPath.append(HomeDestination.riderOrderHistory)
        case "rider_travel_history":
            navigationPath.append(HomeDestination.riderTravelHistory)
        case "today_achievements":
            navigationPath.append(HomeDestination.achievementHistory)
        case "registered_sellers":
            navigationPath.append(HomeDestination.sellerList)
        case "attendance", "mark_attendance":
            navigationPath.append(HomeDestination.markAttendance)
        case "view_leaves", "leave_approval":
            navigationPath.append(HomeDestination.viewLeaves)
        case "regularization_requests", "regularize_approval":
            navigationPath.append(HomeDestination.regularizationRequests)
        case "apply_reimbursements", "expense_approval":
            navigationPath.append(HomeDestination.expenseList)
        case "support":
            let item = viewModel.homeItems.first(where: { $0.route == "support" })
            let sales = item?.payload?.string(for: "forSales", "sales_number", "sales") ?? "9257040297"
            let rider = item?.payload?.string(for: "forRider", "rider_number", "rider") ?? "9257040297"
            navigationPath.append(HomeDestination.support(salesNumber: sales, riderNumber: rider))
        case "profile", "user_profile", "my_profile":
            navigationPath.append(HomeDestination.profile)
        case let value where value.hasPrefix("vehicle_punch/"):
            let parts = value.split(separator: "/").map(String.init)
            let vehicleId = parts.count > 1 ? parts[1] : "1"
            navigationPath.append(HomeDestination.vehicleManagement(vehicleId: vehicleId))
        default:
            navigationPath.append(HomeDestination.placeholder(title: title(for: route)))
        }
    }

    private func title(for route: String) -> String {
        switch route {
        case "rider_orders": return "Orders"
        case "rider_order_history": return "Order History"
        case "rider_travel_history": return "Travel History"
        case "registered_sellers": return "Sellers"
        case "attendance": return "Attendance"
        case "view_leaves": return "Leaves"
        case "apply_reimbursements": return "Expenses"
        case "regularization_requests": return "Regularization"
        case "today_achievements": return "Achievements"
        case "payment_history": return "Payment History"
        case "profile", "user_profile", "my_profile": return "My Profile"
        default: return route.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func handlePushNotification(_ userInfo: [AnyHashable: Any]) {
        viewModel.loadHome(isRefresh: true)

        let route = (userInfo["route"] as? String)
            ?? (userInfo["screen"] as? String)
            ?? (userInfo["type"] as? String)
            ?? (userInfo["action"] as? String)
            ?? ""

        if !route.isEmpty {
            navigate(route)
        }
    }

    private func redirectToAttendanceIfNeeded() {
        guard permissionManager.canShowDashboard,
              viewModel.attendanceScreen,
              !didRedirectToAttendance else { return }
        didRedirectToAttendance = true
        navigate(viewModel.attendanceRoute)
    }
}

#Preview {
    HomeScreen()
}
