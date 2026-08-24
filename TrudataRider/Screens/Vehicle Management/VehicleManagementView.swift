//
//  VehicleManagementView.swift
//  TrudataRider
//

import SwiftUI

private enum VehicleTheme {
    static let appBlue = Color(red: 0.00, green: 0.20, blue: 0.31)
    static let buttonBlue = Color(red: 0.00, green: 0.48, blue: 0.95)
    static let lightBackground = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let punchInPurple = Color(red: 0.90, green: 0.84, blue: 1.0)
    static let punchInText = Color(red: 0.35, green: 0.20, blue: 0.55)
    static let successGreen = Color(red: 0.13, green: 0.65, blue: 0.35)
}

struct VehicleManagementView: View {

    let vehicleId: String
    var onHome: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = VehicleManagementViewModel()
    @State private var showCamera = false
    @State private var showDateFilter = false
    @State private var showToast = false
    @State private var zoomImageURL: String?

    var body: some View {
        ZStack {
            VehicleTheme.lightBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                tabBar
                Group {
                    if viewModel.selectedTab == 0 {
                        punchTab
                    } else {
                        historyTab
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.configure(vehicleId: vehicleId) }
        .onChange(of: viewModel.toastMessage) { _, message in
            showToast = !(message?.isEmptyString ?? true)
        }
        .toast(isPresenting: $showToast) {
            AlertToast(type: .regular, title: viewModel.toastMessage ?? "")
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker(
                preferRearCamera: true,
                onImageCaptured: { image in
                    viewModel.setCapturedImage(image)
                    showCamera = false
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showDateFilter) {
            dateFilterSheet
                .presentationDetents([.medium])
        }
        .fullScreenCover(item: Binding(
            get: { zoomImageURL.map { ZoomImageItem(url: $0) } },
            set: { zoomImageURL = $0?.url }
        )) { item in
            ImageZoomView(url: item.url) { zoomImageURL = nil }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
            }

            Text("Vehicle Management")
                .font(.system(size: 22, weight: .semibold))
                .lineLimit(1)

            Spacer()

            Button { viewModel.refresh() } label: {
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
        .background(VehicleTheme.appBlue.ignoresSafeArea(edges: .top))
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "Punch In/Out", index: 0)
            tabButton(title: "History", index: 1)
        }
        .padding(4)
        .background(Color.white)
        .clipShape(Capsule())
        .overlay { Capsule().stroke(Color.gray.opacity(0.15), lineWidth: 1) }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedTab = index
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(viewModel.selectedTab == index ? .white : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(viewModel.selectedTab == index ? VehicleTheme.appBlue : Color.clear)
                .clipShape(Capsule())
        }
    }

    // MARK: - Punch

    private var punchTab: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    instructionsCard
                    punchTypeCard
                    captureCard
                    readingCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }

            Button {
                viewModel.submitPunch()
            } label: {
                ZStack {
                    if viewModel.isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text(viewModel.punchType.submitTitle)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundStyle(viewModel.canSubmit ? .white : Color.gray.opacity(0.7))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(viewModel.canSubmit ? VehicleTheme.appBlue : Color.gray.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(!viewModel.canSubmit)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
        }
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📸 How to capture meter reading")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(VehicleTheme.buttonBlue)
            Text("""
            • Ensure good lighting on the meter
            • Keep the camera steady and focused
            • Capture the complete odometer display
            • Make sure numbers are clearly visible
            """)
            .font(.system(size: 14))
            .foregroundStyle(VehicleTheme.appBlue.opacity(0.85))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VehicleTheme.buttonBlue.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var punchTypeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Punch Type")
                .font(.system(size: 16, weight: .bold))

            HStack(spacing: 12) {
                ForEach(VehiclePunchType.allCases) { type in
                    let selected = viewModel.punchType == type
                    Button {
                        viewModel.punchType = type
                    } label: {
                        Text(type.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selected ? VehicleTheme.punchInText : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(selected ? VehicleTheme.punchInPurple : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(selected ? Color.clear : Color.gray.opacity(0.25), lineWidth: 1)
                            }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var captureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Capture Meter Reading")
                .font(.system(size: 16, weight: .bold))

            if let image = viewModel.capturedImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button {
                        viewModel.clearCapturedImage()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white, .black.opacity(0.55))
                            .padding(8)
                    }
                }
            }

            Button { showCamera = true } label: {
                HStack(spacing: 8) {
                    if viewModel.isProcessingImage {
                        ProgressView()
                    } else {
                        Image(systemName: "camera.fill")
                        Text(viewModel.capturedImage == nil ? "Take Photo (High Quality)" : "Retake Photo")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .foregroundStyle(.primary.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                }
            }
            .disabled(viewModel.isProcessingImage)

            Text("Please capture an image of the vehicle's meter reading.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var readingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meter Reading")
                .font(.system(size: 16, weight: .bold))

            TextField("Enter kilometer reading", text: $viewModel.meterReading)
                .keyboardType(.numberPad)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - History

    private var historyTab: some View {
        VStack(spacing: 12) {
            Button { showDateFilter = true } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Date Range")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text(viewModel.dateRangeLabel)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(VehicleTheme.buttonBlue)
                }
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 16)

            if viewModel.isHistoryLoading && viewModel.historyItems.isEmpty {
                ProgressView()
                    .tint(VehicleTheme.appBlue)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.historyError, viewModel.historyItems.isEmpty {
                VStack(spacing: 12) {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { viewModel.loadHistory(isInitial: true) }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VehicleTheme.buttonBlue)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.historyItems.isEmpty {
                Text("No vehicle punch history found for the selected date range.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.historyItems) { item in
                            VehiclePunchHistoryCard(item: item) {
                                zoomImageURL = item.imageURL
                            }
                            .onAppear { viewModel.loadMoreIfNeeded(currentItem: item) }
                        }
                        if viewModel.isHistoryLoadingMore {
                            ProgressView()
                                .tint(VehicleTheme.buttonBlue)
                                .padding(.vertical, 10)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private var dateFilterSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Filter by Date")
                .font(.system(size: 20, weight: .bold))

            VStack(alignment: .leading, spacing: 8) {
                Text("Start Date").font(.system(size: 13, weight: .medium))
                DatePicker(
                    "",
                    selection: Binding(
                        get: { viewModel.parsedDate(from: viewModel.startDate) },
                        set: { viewModel.updateStartDate($0) }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("End Date").font(.system(size: 13, weight: .medium))
                DatePicker(
                    "",
                    selection: Binding(
                        get: { viewModel.parsedDate(from: viewModel.endDate) },
                        set: { viewModel.updateEndDate($0) }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
            }

            Spacer()

            Button("Done") { showDateFilter = false }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(VehicleTheme.buttonBlue)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(20)
    }
}

// MARK: - History Card

private struct VehiclePunchHistoryCard: View {
    let item: VehiclePunchHistoryItem
    let onZoom: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(item.punchType.badge)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(item.punchType == .punchIn ? VehicleTheme.successGreen : VehicleTheme.buttonBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        (item.punchType == .punchIn ? VehicleTheme.successGreen : VehicleTheme.buttonBlue)
                            .opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Spacer()

                Text(item.inOutTime)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(14)

            Divider()

            HStack(alignment: .top, spacing: 14) {
                Button(action: onZoom) {
                    RemoteImage(url: item.imageURL)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    detailRow(icon: "car.fill", label: "Reading", value: item.reading, highlight: true)
                    detailRow(icon: "person.fill", label: "Rider", value: item.riderName)
                    detailRow(icon: "car.fill", label: "Vehicle", value: item.vehicleLabel)
                }
            }
            .padding(14)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        }
    }

    private func detailRow(icon: String, label: String, value: String, highlight: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text("\(label):")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: highlight ? .bold : .semibold))
                .foregroundStyle(highlight ? VehicleTheme.buttonBlue : .primary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Zoom

private struct ZoomImageItem: Identifiable {
    let url: String
    var id: String { url }
}

private struct ImageZoomView: View {
    let url: String
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            RemoteImage(url: url, contentMode: .fit)
                .padding()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .padding()
            }
        }
    }
}

#Preview {
    NavigationStack {
        VehicleManagementView(vehicleId: "1")
    }
}
