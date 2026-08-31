//
//  String+Extension.swift
//  Truedata
//

import Foundation
import SwiftUI

extension String {
    var trim: String {
        trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    var isEmptyString: Bool {
        trim.isEmpty
    }

    var nilIfEmpty: String? {
        isEmptyString ? nil : self
    }

    var priceLabel: String {
        let trimmedString = trim
        return trimmedString.hasPrefix("₹") ? trimmedString : "₹\(trimmedString.removeZerosFromEnd(max: 2))"
    }

    func removeZerosFromEnd(min minDigitAfterDecimal: Int = 0, max maxDigitAfterDecimal: Int = 2) -> String {
        let formatter = NumberFormatter()
        let number = NSNumber(value: Double(self) ?? 0.0)
        formatter.minimumFractionDigits = minDigitAfterDecimal
        formatter.maximumFractionDigits = maxDigitAfterDecimal
        return String(formatter.string(from: number) ?? "")
    }

    func isValidIndianMobileNumber() -> Bool {
        let trimmed = self.trim
        let pattern = "^[6-9]\\d{9}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        return predicate.evaluate(with: trimmed)
    }

    func isValidMobileNumber() -> Bool {
        let trimmed = self.trim
        let pattern = "^\\d{10}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        return predicate.evaluate(with: trimmed)
    }

    func isValidEmail() -> Bool {
        let trimmed = self.trim
        guard !trimmed.isEmpty else { return false }
        let pattern = "^[A-Za-z0-9._%+-]+@([A-Za-z0-9-]+\\.)+[A-Za-z]{2,64}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        return predicate.evaluate(with: trimmed)
    }

    var digitsOnly: String {
        filter(\.isNumber)
    }

    var limitToMobileNumber: String {
        String(digitsOnly.prefix(10))
    }

    var hexToColor: Color {
        Color(hex: self)
    }
}

extension Date {
    var millisecondsSince1970: Int64 {
        Int64((timeIntervalSince1970 * 1000.0).rounded())
    }

    init(milliseconds: Int) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds / 1000))
    }

    func get(_ component: Calendar.Component, calendar: Calendar = Calendar.current) -> Int {
        calendar.component(component, from: self)
    }
}

extension Notification.Name {
    static let fcmTokenDidUpdate = Notification.Name("fcmTokenDidUpdate")
    static let didReceivePushNotification = Notification.Name("didReceivePushNotification")
}

