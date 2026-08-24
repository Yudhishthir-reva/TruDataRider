//
//  VehicleManagementServiceManager.swift
//  TrudataRider
//

import Foundation
import Combine

// MARK: - Domain

enum VehiclePunchType: String, CaseIterable, Identifiable {
    case punchIn = "1"
    case punchOut = "2"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .punchIn: return "Punch In"
        case .punchOut: return "Punch Out"
        }
    }

    var badge: String {
        switch self {
        case .punchIn: return "PUNCH IN"
        case .punchOut: return "PUNCH OUT"
        }
    }

    var submitTitle: String {
        "Submit \(title)"
    }
}

struct VehiclePunchHistoryItem: Identifiable, Hashable {
    let id: Int
    let inOutTime: String
    let imageURL: String
    let reading: String
    let status: String
    let riderName: String
    let vehicleName: String
    let vehiclePlate: String

    var punchType: VehiclePunchType {
        status == "2" ? .punchOut : .punchIn
    }

    var vehicleLabel: String {
        if vehiclePlate.isEmptyString {
            return vehicleName.isEmptyString ? "N/A" : vehicleName
        }
        return "\(vehicleName) (\(vehiclePlate))"
    }
}

// MARK: - Responses

struct VehiclePunchSubmitResponse: Decodable {
    var status: Bool
    var message: String

    enum CodingKeys: String, CodingKey {
        case status, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.first ?? ""
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }
    }
}

struct VehiclePunchHistoryResponse: Decodable {
    var status: Bool
    var message: String
    var items: [VehiclePunchHistoryItem]
    var currentPage: Int
    var lastPage: Int
    var canLoadMore: Bool

    enum CodingKeys: String, CodingKey {
        case status, message
        case history = "RiderVehicleInOutHistory"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.first ?? ""
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }

        if let page = try? container.decode(VehiclePunchHistoryPageDto.self, forKey: .history) {
            items = page.data.map { $0.toDomain() }
            currentPage = page.currentPage
            lastPage = page.lastPage
            canLoadMore = page.nextPageURL != nil && !page.nextPageURL!.isEmptyString
        } else {
            items = []
            currentPage = 1
            lastPage = 1
            canLoadMore = false
        }
    }
}

private struct VehiclePunchHistoryPageDto: Decodable {
    var currentPage: Int
    var lastPage: Int
    var nextPageURL: String?
    var data: [VehiclePunchHistoryItemDto]

    enum CodingKeys: String, CodingKey {
        case data
        case currentPage = "current_page"
        case lastPage = "last_page"
        case nextPageURL = "next_page_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 1
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 1
        nextPageURL = container.decodeStringLeniently(forKey: .nextPageURL)
        data = (try? container.decode([VehiclePunchHistoryItemDto].self, forKey: .data)) ?? []
    }
}

private struct VehiclePunchHistoryItemDto: Decodable {
    var id: Int
    var inOutTime: String
    var image: String
    var reading: String
    var status: String
    var vehicle: VehicleHistoryInfoDto?
    var rider: RiderHistoryInfoDto?

    enum CodingKeys: String, CodingKey {
        case id, image, reading, status, rider
        case inOutTime = "in_out_time"
        case vehicle = "vechile"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        inOutTime = container.decodeStringLeniently(forKey: .inOutTime) ?? ""
        image = container.decodeStringLeniently(forKey: .image) ?? ""
        reading = container.decodeStringLeniently(forKey: .reading) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? "1"
        vehicle = try? container.decode(VehicleHistoryInfoDto.self, forKey: .vehicle)
        rider = try? container.decode(RiderHistoryInfoDto.self, forKey: .rider)
    }

    func toDomain() -> VehiclePunchHistoryItem {
        VehiclePunchHistoryItem(
            id: id,
            inOutTime: inOutTime,
            imageURL: image,
            reading: reading,
            status: status,
            riderName: rider?.name ?? "N/A",
            vehicleName: vehicle?.name ?? "",
            vehiclePlate: vehicle?.noPlate ?? ""
        )
    }
}

private struct VehicleHistoryInfoDto: Decodable {
    var name: String
    var noPlate: String

    enum CodingKeys: String, CodingKey {
        case name
        case noPlate = "no_plate"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        noPlate = container.decodeStringLeniently(forKey: .noPlate) ?? ""
    }
}

private struct RiderHistoryInfoDto: Decodable {
    var name: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decodeStringLeniently(forKey: .name) ?? ""
    }

    enum CodingKeys: String, CodingKey { case name }
}

// MARK: - Service

class VehicleManagementServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    func submitPunch(
        vehicleId: String,
        reading: String,
        status: String,
        imageMetaData: String,
        imageData: Data
    ) -> AnyPublisher<VehiclePunchSubmitResponse, Error> {
        let params: [String: Any] = [
            "vehicle_id": vehicleId,
            "reading": reading,
            "status": status,
            "image_meta_data": imageMetaData
        ]
        let file = MultipartFileUpload(
            fieldName: "image",
            fileName: "meter_\(Int(Date().timeIntervalSince1970)).jpg",
            mimeType: "image/jpeg",
            data: imageData
        )
        return networkService.uploadMultipart(
            APIRouter.vehiclePunchInOut,
            params: params,
            file: file,
            files: [file],
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func fetchHistory(
        vehicleId: String,
        startDate: String,
        endDate: String,
        page: Int
    ) -> AnyPublisher<VehiclePunchHistoryResponse, Error> {
        networkService.request(
            APIRouter.vehiclePunchHistory,
            params: [
                "vehicle_id": vehicleId,
                "start_date": startDate,
                "end_date": endDate,
                "page": "\(page)"
            ],
            headers: UserDefaultManager.shared.authHeader
        )
    }
}
