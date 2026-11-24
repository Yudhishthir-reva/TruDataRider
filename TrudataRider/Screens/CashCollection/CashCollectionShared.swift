//
//  CashCollectionShared.swift
//  TrudataRider
//
//  The non-visual plumbing every cash screen shares, ported from the Android module: the period /
//  staff filter (`CashFilter.kt`), the pager (`Paging.kt`), the change bus (`CashCollectionBus`),
//  the error wording (`CashCollectionApi.send`) and the attachment rules (`AttachmentReader`).
//

import Combine
import Foundation
import UIKit
import UniformTypeIdentifiers

// MARK: - Dates

enum CashDates {

    static var calendar: Calendar { Calendar.current }

    static var today: Date { calendar.startOfDay(for: Date()) }

    static func startOfMonth(_ date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    static func endOfMonth(_ date: Date) -> Date {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return date }
        return calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
    }

    static func addDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    static func addMonths(_ months: Int, to date: Date) -> Date {
        calendar.date(byAdding: .month, value: months, to: date) ?? date
    }

    static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    /// Android `prettyDate`: "3 Oct 2026" from `yyyy-MM-dd`; anything else comes back as sent.
    static func pretty(_ iso: String) -> String {
        guard let date = CashFormat.date(fromApi: iso), iso.count >= 10 else { return iso }
        return format(date, "d MMM yyyy")
    }
}

/// Android `initials`: up to two capital letters, "?" for a blank name.
func cashInitials(_ name: String) -> String {
    let letters = name.split(separator: " ")
        .filter { !$0.isEmpty }
        .prefix(2)
        .compactMap { $0.first.map { String($0).uppercased() } }
        .joined()
    return letters.isEmpty ? "?" : letters
}

/// Android `digitsOnly`: keeps only digits, drops leading zeros, caps the length.
func cashDigitsOnly(_ input: String, maxLength: Int = 9) -> String {
    String(input.filter(\.isNumber).drop(while: { $0 == "0" }).prefix(maxLength))
}

/// Android `bundleText`: notes come in bundles of 100.
func cashBundleText(_ count: Int) -> String {
    let bundles = count / 100
    let loose = count % 100
    return "\(bundles) bundle\(bundles > 1 ? "s" : "")" + (loose > 0 ? " + \(loose)" : "")
}

// MARK: - Filter

/// The period a list or summary covers. `.all` sends no dates, which the server reads as all time.
enum CashPeriod: String, CaseIterable, Hashable {
    case today = "Today"
    case range = "Range"
    case month = "Month"
    case all = "All"
}

/// Android `CashFilter`: a period, and (for reviewers) a set of staff. Empty `staffIds` is left out
/// of the request, which the server reads as everyone.
struct CashFilter: Equatable {
    var period: CashPeriod = .month
    /// The Range period, inclusive. One day sets both ends to it.
    var from: Date = CashDates.addDays(-6, to: CashDates.today)
    var to: Date = CashDates.today
    var month: Date = CashDates.startOfMonth(Date())
    var staffIds: Set<Int> = []

    init(period: CashPeriod = .month) {
        self.period = period
    }

    /// `date_from` / `date_to` for the request; both nil for `.all`.
    func dates() -> CashDateRange {
        switch period {
        case .today:
            let day = CashFormat.apiString(from: Date())
            return CashDateRange(from: day, to: day)
        case .range:
            return CashDateRange(from: CashFormat.apiString(from: from), to: CashFormat.apiString(from: to))
        case .month:
            return CashDateRange(
                from: CashFormat.apiString(from: CashDates.startOfMonth(month)),
                to: CashFormat.apiString(from: CashDates.endOfMonth(month))
            )
        case .all:
            return .allTime
        }
    }

    var periodLabel: String {
        switch period {
        case .today:
            return "Today · " + CashDates.format(Date(), "d MMM yyyy")
        case .range:
            let calendar = CashDates.calendar
            if calendar.isDate(from, inSameDayAs: to) {
                return CashDates.format(from, "EEE, d MMM yyyy")
            }
            if calendar.component(.year, from: from) == calendar.component(.year, from: to) {
                return CashDates.format(from, "d MMM") + " – " + CashDates.format(to, "d MMM yyyy")
            }
            return CashDates.format(from, "d MMM yyyy") + " – " + CashDates.format(to, "d MMM yyyy")
        case .month:
            return CashDates.format(month, "MMMM yyyy")
        case .all:
            return "All time"
        }
    }

    /// "today", "on Tue, 29 Sep 2026", "in September 2026" … for sentences like "Nothing … today."
    var periodPhrase: String {
        switch period {
        case .today: return "today"
        case .range: return CashDates.calendar.isDate(from, inSameDayAs: to) ? "on \(periodLabel)" : "between \(periodLabel)"
        case .month: return "in \(periodLabel)"
        case .all: return "yet"
        }
    }

    func staffLabel(_ people: [PersonOption]) -> String {
        switch staffIds.count {
        case 0: return "All staff"
        case 1: return people.first { staffIds.contains($0.id) }?.name ?? "1 staff"
        default: return "\(staffIds.count) staff"
        }
    }

    static func == (lhs: CashFilter, rhs: CashFilter) -> Bool {
        let calendar = CashDates.calendar
        return lhs.period == rhs.period
            && calendar.isDate(lhs.from, inSameDayAs: rhs.from)
            && calendar.isDate(lhs.to, inSameDayAs: rhs.to)
            && calendar.isDate(lhs.month, equalTo: rhs.month, toGranularity: .month)
            && lhs.staffIds == rhs.staffIds
    }
}

/// Android `mergePeople`: the staff list leaves out some accounts that still submit cash (admin, for
/// one), so anyone who shows up in the loaded data is offered in the filter too.
func cashMergePeople(_ people: [PersonOption], _ seen: [PersonOption]) -> [PersonOption] {
    var known = Set<Int>()
    return (people + seen)
        .filter { known.insert($0.id).inserted }
        .sorted { $0.name.lowercased() < $1.name.lowercased() }
}

/// Android rider `AppCashCollectionHost.people()`: the rider app has no staff list for the cash
/// screens. Only manager screens ask for it, and a rider never sees them.
enum CashPeople {
    static func load() -> AnyPublisher<[PersonOption], Error> {
        Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
}

// MARK: - Change bus

/// Android `CashCollectionBus`: tells open lists that a record changed somewhere else, so going back
/// shows the new state without a manual refresh.
enum CashChange: String {
    case collection, amountTaken, advance

    private static let name = Notification.Name("CashCollectionBus.change")

    static func notify(_ change: CashChange) {
        NotificationCenter.default.post(name: name, object: nil, userInfo: ["change": change.rawValue])
    }

    static var publisher: AnyPublisher<CashChange, Never> {
        NotificationCenter.default.publisher(for: name)
            .compactMap { ($0.userInfo?["change"] as? String).flatMap(CashChange.init(rawValue:)) }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
}

// MARK: - Errors

/// The wording Android's `CashCollectionApi.send` gives every failure, so screens never show a raw
/// status or a decoder message.
enum CashError {

    static let generic = "Something went wrong. Try again."
    static let offline = "No internet connection. Check your network and try again."
    static let unreadable = "The server's reply couldn't be read. Update the app or try again."
    static let empty = "The server sent an empty reply."

    static func message(_ error: Error) -> String {
        if let request = error as? RequestError {
            switch request {
            case .noInternet: return offline
            case .apiMessage(let text): return server(text) ?? generic
            case .unAuthroizedUser: return "Your session has expired. Log in again."
            case .forbidenRequest: return "You don't have access to this."
            case .invalidData, .invalidPayloadData: return unreadable
            default: return generic
            }
        }
        if error is DecodingError { return unreadable }
        if let url = error as? URLError {
            switch url.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost,
                 .cannotConnectToHost, .dataNotAllowed, .internationalRoamingOff:
                return offline
            default:
                return generic
            }
        }
        let text = error.localizedDescription
        return text.isEmptyString ? generic : text
    }

    /// A server message as Android shows it: Laravel's "first error (and 2 more errors)" trimmed to
    /// the field message, and the two auth replies reworded.
    static func server(_ raw: String?) -> String? {
        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        if text == "Unauthenticated." { return "Your session has expired. Log in again." }
        if text == "Unauthorized." { return "You don't have access to this." }
        if let range = text.range(of: #"\s*\(and \d+ more errors?\)$"#, options: .regularExpression) {
            text.removeSubrange(range)
        }
        return text
    }
}

/// A reply that says whether the server accepted the call (`status` / `success`).
protocol CashServerReply {
    var replyOK: Bool { get }
    var replyMessage: String { get }
}

extension DataResponse: CashServerReply {
    var replyOK: Bool { status }
    var replyMessage: String { message }
}

extension PagedResponse: CashServerReply {
    var replyOK: Bool { status }
    var replyMessage: String { message }
}

extension LedgerResponse: CashServerReply {
    var replyOK: Bool { status }
    var replyMessage: String { message }
}

extension AdvanceListResponse: CashServerReply {
    var replyOK: Bool { status }
    var replyMessage: String { message }
}

extension DenominationSummaryResponse: CashServerReply {
    var replyOK: Bool { status }
    var replyMessage: String { message }
}

extension Publisher where Output: CashServerReply {

    /// `{status:false, message}` becomes a failure, and every failure carries Android's wording, so
    /// a view model handles one path for both.
    func cashChecked() -> AnyPublisher<Output, Error> {
        tryMap { reply -> Output in
            guard reply.replyOK else {
                throw RequestError.apiMessage(CashError.server(reply.replyMessage) ?? CashError.generic)
            }
            return reply
        }
        .mapError { RequestError.apiMessage(CashError.message($0)) as Error }
        .eraseToAnyPublisher()
    }
}

// MARK: - Paging

/// Android `ListState`.
struct CashListState<Item> {
    var items: [Item] = []
    var total = 0
    var isLoading = false
    var isRefreshing = false
    var isLoadingMore = false
    var hasMore = false
    var error: String?
    var loaded = false
}

/// One page of rows and its paging, whatever reply it came in.
struct CashPage<Item> {
    var items: [Item]
    var meta: PageMeta

    var hasMore: Bool { meta.hasMore }
}

/// Android `Pager`: first page, refresh (keeps rows on screen), and next page. A new first-page load
/// cancels whatever was in flight, so switching month quickly can't land an old month's rows.
final class CashPager<Item> {

    private let read: () -> CashListState<Item>?
    private let write: ((inout CashListState<Item>) -> Void) -> Void
    private let fetch: (Int) -> AnyPublisher<CashPage<Item>, Error>
    private var job: AnyCancellable?
    private var isBusy = false
    private var page = 1

    init(
        read: @escaping () -> CashListState<Item>?,
        write: @escaping ((inout CashListState<Item>) -> Void) -> Void,
        fetch: @escaping (Int) -> AnyPublisher<CashPage<Item>, Error>
    ) {
        self.read = read
        self.write = write
        self.fetch = fetch
    }

    func load(refresh: Bool = false) {
        job?.cancel()
        write { state in
            if refresh && !state.items.isEmpty {
                state.isRefreshing = true
            } else {
                state.isLoading = true
                state.items = []
            }
            state.isLoadingMore = false
            state.error = nil
        }
        isBusy = true
        job = fetch(1)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isBusy = false
                if case .failure(let error) = completion {
                    let message = CashError.message(error)
                    self.write { state in
                        state.isLoading = false
                        state.isRefreshing = false
                        state.loaded = true
                        if state.items.isEmpty { state.error = message }
                    }
                }
            } receiveValue: { [weak self] page in
                guard let self else { return }
                self.page = page.meta.currentPage
                self.write { state in
                    state.items = page.items
                    state.total = page.meta.total
                    state.hasMore = page.hasMore
                    state.isLoading = false
                    state.isRefreshing = false
                    state.error = nil
                    state.loaded = true
                }
            }
    }

    func loadMore() {
        guard let state = read(), state.hasMore, !state.isLoading, !state.isLoadingMore, !isBusy else { return }
        write { $0.isLoadingMore = true }
        isBusy = true
        job = fetch(page + 1)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isBusy = false
                // A failed next page keeps what is on screen; scrolling to the end again retries.
                if case .failure = completion {
                    self.write { $0.isLoadingMore = false }
                }
            } receiveValue: { [weak self] page in
                guard let self else { return }
                self.page = page.meta.currentPage
                self.write { state in
                    state.items += page.items
                    state.hasMore = page.hasMore
                    state.total = page.meta.total
                    state.isLoadingMore = false
                }
            }
    }
}

// MARK: - Attachments

/// Android `PickedAttachment`: a bill or document the user picked, ready to upload.
struct CashAttachment: Equatable {
    var data: Data
    var name: String
    var mimeType: String

    var isImage: Bool { mimeType.hasPrefix("image/") }

    var sizeLabel: String {
        let bytes = data.count
        if bytes >= 1024 * 1024 {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576)
        }
        return "\(max(bytes / 1024, 1)) KB"
    }

    var upload: MultipartFileUpload {
        MultipartFileUpload(fieldName: "attachment", fileName: name.replacingOccurrences(of: "\"", with: ""), mimeType: mimeType, data: data)
    }
}

/// Android `AttachmentReader`: turns a camera photo or a picked file into something the server takes —
/// jpg, png or pdf, at most 5 MB. Photos are shrunk on the way (a bill reads fine at ~500 KB).
enum CashAttachmentReader {

    static let maxBytes = 5 * 1024 * 1024
    static let allowedTypes: [UTType] = [.jpeg, .png, .pdf]

    enum Failure: LocalizedError {
        case message(String)
        var errorDescription: String? {
            if case .message(let text) = self { return text }
            return nil
        }
    }

    static func read(photo: UIImage) -> Result<CashAttachment, Failure> {
        guard let data = shrink(photo) else { return .failure(.message("Couldn't read the file. Try another one.")) }
        let name = "attachment_\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
        return check(CashAttachment(data: data, name: name, mimeType: "image/jpeg"))
    }

    static func read(fileAt url: URL) -> Result<CashAttachment, Failure> {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let type = UTType(filenameExtension: url.pathExtension.lowercased())
        let mime: String
        if type?.conforms(to: .pdf) == true {
            mime = "application/pdf"
        } else if type?.conforms(to: .png) == true {
            mime = "image/png"
        } else if type?.conforms(to: .jpeg) == true {
            mime = "image/jpeg"
        } else {
            return .failure(.message("Only JPG, PNG or PDF files can be attached."))
        }
        guard let raw = try? Data(contentsOf: url) else {
            return .failure(.message("Couldn't read the file. Try another one."))
        }
        let name = url.lastPathComponent.isEmpty
            ? "attachment_\(Int(Date().timeIntervalSince1970 * 1000)).\(mime == "application/pdf" ? "pdf" : mime == "image/png" ? "png" : "jpg")"
            : url.lastPathComponent
        if mime == "application/pdf" {
            return check(CashAttachment(data: raw, name: name, mimeType: mime))
        }
        // The compressor hands back the original when it is already small, and JPEG otherwise.
        if raw.count <= targetBytes {
            return check(CashAttachment(data: raw, name: name, mimeType: mime))
        }
        guard let image = UIImage(data: raw), let shrunk = shrink(image) else {
            return .failure(.message("Couldn't read the file. Try another one."))
        }
        let base = (name as NSString).deletingPathExtension
        return check(CashAttachment(data: shrunk, name: base + ".jpg", mimeType: "image/jpeg"))
    }

    private static let targetBytes = 500 * 1024

    private static func check(_ attachment: CashAttachment) -> Result<CashAttachment, Failure> {
        attachment.data.count <= maxBytes
            ? .success(attachment)
            : .failure(.message("The file is larger than 5 MB. Choose a smaller one."))
    }

    /// JPEG at falling quality, then smaller dimensions, until it is near the target size.
    private static func shrink(_ image: UIImage) -> Data? {
        var current = image
        let longest = max(image.size.width, image.size.height)
        if longest > 2000 {
            let scale = 2000 / longest
            current = resized(image, scale: scale)
        }
        var quality: CGFloat = 0.85
        var data = current.jpegData(compressionQuality: quality)
        while let bytes = data?.count, bytes > targetBytes, quality > 0.35 {
            quality -= 0.15
            data = current.jpegData(compressionQuality: quality)
        }
        var attempts = 0
        while let bytes = data?.count, bytes > targetBytes, attempts < 3 {
            current = resized(current, scale: 0.75)
            data = current.jpegData(compressionQuality: quality)
            attempts += 1
        }
        return data
    }

    private static func resized(_ image: UIImage, scale: CGFloat) -> UIImage {
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
