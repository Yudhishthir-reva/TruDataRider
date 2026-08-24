//
//  VehicleManagementViewModel.swift
//  TrudataRider
//

import Foundation
import Combine
import UIKit

final class VehicleManagementViewModel: ObservableObject {

    @Published var selectedTab = 0
    @Published var punchType: VehiclePunchType = .punchIn
    @Published var meterReading = ""
    @Published var capturedImage: UIImage?
    @Published var isSubmitting = false
    @Published var isProcessingImage = false
    @Published var toastMessage: String?

    @Published var isHistoryLoading = false
    @Published var isHistoryLoadingMore = false
    @Published var historyError: String?
    @Published var historyItems: [VehiclePunchHistoryItem] = []
    @Published var startDate = ""
    @Published var endDate = ""

    private(set) var vehicleId: String = ""
    private var imageData: Data?
    private var currentPage = 1
    private var canLoadMore = false
    private var cancellables = Set<AnyCancellable>()
    private let service = VehicleManagementServiceManager()
    private let locationHelper = LocationHelper()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var canSubmit: Bool {
        !isSubmitting
            && !isProcessingImage
            && imageData != nil
            && !meterReading.trim.isEmptyString
            && !vehicleId.isEmptyString
    }

    var dateRangeLabel: String {
        if startDate == endDate { return startDate }
        return "\(startDate) → \(endDate)"
    }

    func configure(vehicleId: String) {
        guard self.vehicleId != vehicleId || historyItems.isEmpty else { return }
        self.vehicleId = vehicleId
        let today = dateFormatter.string(from: Date())
        startDate = today
        endDate = today
        loadHistory(isInitial: true)
        locationHelper.refreshLocation()
    }

    func refresh() {
        if selectedTab == 1 {
            loadHistory(isInitial: true)
        }
    }

    func setCapturedImage(_ image: UIImage) {
        isProcessingImage = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let compressed = Self.compressedJPEG(from: image)
            DispatchQueue.main.async {
                self?.capturedImage = image
                self?.imageData = compressed
                self?.isProcessingImage = false
            }
        }
    }

    func clearCapturedImage() {
        capturedImage = nil
        imageData = nil
    }

    func submitPunch() {
        guard canSubmit, let imageData else {
            toastMessage = imageData == nil
                ? "Please capture an image first."
                : "Please enter the meter reading."
            return
        }

        isSubmitting = true
        let meta = buildImageMetaData(image: capturedImage)

        service.submitPunch(
            vehicleId: vehicleId,
            reading: meterReading.trim,
            status: punchType.rawValue,
            imageMetaData: meta,
            imageData: imageData
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isSubmitting = false
            if case .failure(let error) = completion {
                self.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isSubmitting = false
            self.toastMessage = response.message.isEmptyString
                ? (response.status ? "Submitted successfully" : "Something went wrong")
                : response.message
            if response.status {
                self.meterReading = ""
                self.clearCapturedImage()
                self.loadHistory(isInitial: true)
            }
        }
        .store(in: &cancellables)
    }

    func updateStartDate(_ date: Date) {
        startDate = dateFormatter.string(from: date)
        loadHistory(isInitial: true)
    }

    func updateEndDate(_ date: Date) {
        endDate = dateFormatter.string(from: date)
        loadHistory(isInitial: true)
    }

    func parsedDate(from string: String) -> Date {
        dateFormatter.date(from: string) ?? Date()
    }

    func loadMoreIfNeeded(currentItem: VehiclePunchHistoryItem) {
        guard canLoadMore, !isHistoryLoading, !isHistoryLoadingMore else { return }
        guard let index = historyItems.firstIndex(where: { $0.id == currentItem.id }) else { return }
        if index >= historyItems.count - 3 {
            loadHistory(isInitial: false)
        }
    }

    func loadHistory(isInitial: Bool) {
        guard !vehicleId.isEmptyString else { return }

        if isInitial {
            isHistoryLoading = true
            historyError = nil
            currentPage = 1
            canLoadMore = false
        } else {
            guard canLoadMore, !isHistoryLoadingMore else { return }
            isHistoryLoadingMore = true
            currentPage += 1
        }

        service.fetchHistory(
            vehicleId: vehicleId,
            startDate: startDate,
            endDate: endDate,
            page: currentPage
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isHistoryLoading = false
            self.isHistoryLoadingMore = false
            if case .failure(let error) = completion {
                self.historyError = (error as? RequestError)?.errorString ?? error.localizedDescription
                if !isInitial { self.currentPage = max(1, self.currentPage - 1) }
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isHistoryLoading = false
            self.isHistoryLoadingMore = false
            if response.status {
                if isInitial {
                    self.historyItems = response.items
                } else {
                    let existing = Set(self.historyItems.map(\.id))
                    self.historyItems.append(contentsOf: response.items.filter { !existing.contains($0.id) })
                }
                self.currentPage = response.currentPage
                self.canLoadMore = response.canLoadMore
                self.historyError = nil
            } else {
                if isInitial { self.historyItems = [] }
                self.historyError = response.message.isEmptyString
                    ? "No vehicle punch history found for the selected date range."
                    : response.message
            }
        }
        .store(in: &cancellables)
    }

    private func buildImageMetaData(image: UIImage?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var parts = [
            "Time: \(formatter.string(from: Date()))",
            "Device: \(UIDevice.current.model)",
            "iOS: \(UIDevice.current.systemVersion)"
        ]
        if let snapshot = locationHelper.snapshot {
            parts.append(String(format: "GPS: %.6f,%.6f", snapshot.latitude, snapshot.longitude))
        } else {
            parts.append("GPS: Not Available")
        }
        if let image {
            let size = "\(Int(image.size.width * image.scale))x\(Int(image.size.height * image.scale))"
            parts.append("Size: \(size)")
        }
        return parts.joined(separator: ", ")
    }

    private static func compressedJPEG(from image: UIImage, maxBytes: Int = 500_000) -> Data? {
        var quality: CGFloat = 0.8
        var data = image.jpegData(compressionQuality: quality)
        while let current = data, current.count > maxBytes, quality > 0.2 {
            quality -= 0.1
            data = image.jpegData(compressionQuality: quality)
        }
        return data
    }
}
