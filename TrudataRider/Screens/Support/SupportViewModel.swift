//
//  SupportViewModel.swift
//  TrudataRider
//
//  Created by Reva on 21/08/26.
//

import SwiftUI
import Combine

final class SupportViewModel: ObservableObject {

    @Published var contacts: [SupportContactItem] = []
    @Published var isLoading: Bool = false

    private let service: SupportServiceManager
    private let salesNumber: String?
    private let riderNumber: String?

    init(
        salesNumber: String? = nil,
        riderNumber: String? = nil,
        service: SupportServiceManager = SupportServiceManager()
    ) {
        self.salesNumber = salesNumber
        self.riderNumber = riderNumber
        self.service = service
        self.loadContacts()
    }

    var headerTitle: String {
        "Support"
    }

    var noteText: String {
        "Note: These numbers are for business emergencies and support only. Please use responsibly."
    }

    func onAppear() {
        loadContacts()
    }

    func refresh() {
        loadContacts()
    }

    func loadContacts() {
        contacts = service.getEmergencyContacts(
            salesNumber: salesNumber,
            riderNumber: riderNumber
        )
    }

    func callContact(_ contact: SupportContactItem) {
        guard let url = contact.callURL else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
