import Foundation
import Contacts

/// Modern actor-based contact manager with thread safety and structured concurrency
@MainActor
final class ModernContactsManager: ContactManaging {
    
    // MARK: - Dependencies
    
    private let store = CNContactStore()
    private let analyzer: ContactAnalyzing
    private let filter: ContactFiltering
    private let logger: Logging?
    
    // MARK: - State
    
    private var accessGranted: Bool = false
    private var contactCache: [ContactID: Contact] = [:]
    private var lastCacheUpdate: Date?
    
    // MARK: - Configuration
    
    private let configuration: ContactConfiguration
    
    // MARK: - Initialization
    
    init(
        analyzer: ContactAnalyzing = DefaultContactAnalyzer(),
        filter: ContactFiltering = DefaultContactFilter(),
        configuration: ContactConfiguration = .default,
        logger: Logging? = nil
    ) {
        self.analyzer = analyzer
        self.filter = filter
        self.configuration = configuration
        self.logger = logger
    }
    
    // MARK: - ContactManaging Protocol
    
    func requestAccess() async throws -> Bool {
        logger?.log(level: .info, message: "Requesting contacts access", context: [:])
        
        return try await withCheckedThrowingContinuation { continuation in
            store.requestAccess(for: .contacts) { [weak self] granted, error in
                if let error = error {
                    self?.logger?.log(level: .error, message: "Access request failed", context: ["error": error.localizedDescription])
                    continuation.resume(throwing: ContactError.permission(.contactsAccessDenied))
                } else {
                    self?.accessGranted = granted
                    self?.logger?.log(level: .info, message: "Access granted: \(granted)", context: [:])
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func loadContacts(filter: ContactFilter) async -> Result<[Contact], ContactError> {
        guard accessGranted else {
            logger?.log(level: .error, message: "Attempted to load contacts without access", context: [:])
            return .failure(.permission(.contactsAccessDenied))
        }
        
        logger?.log(level: .info, message: "Loading contacts", context: [
            "filter": filter.mode.rawValue,
            "dubiousScore": filter.dubiousScore
        ])
        
        do {
            let cnContacts = try await loadCNContacts()
            let contacts = cnContacts.map { convertFromCNContact($0) }
            
            let filteredResult = await self.filter.filter(contacts, using: filter)
            
            switch filteredResult {
            case .success(let filtered):
                logger?.log(level: .info, message: "Loaded contacts successfully", context: [
                    "total": cnContacts.count,
                    "filtered": filtered.count
                ])
                return .success(filtered)
                
            case .failure(let error):
                logger?.log(level: .error, message: "Failed to filter contacts", context: ["error": error.localizedDescription])
                return .failure(error)
            }
            
        } catch {
            let contactError = ContactError.analysis(.contactLoadFailed(reason: error.localizedDescription))
            logger?.log(level: .error, message: "Failed to load contacts", context: ["error": error.localizedDescription])
            return .failure(contactError)
        }
    }
    
    func createContact(_ contact: Contact) async -> Result<ContactID, ContactError> {
        guard accessGranted else {
            return .failure(.permission(.contactsAccessDenied))
        }
        
        logger?.log(level: .info, message: "Creating contact", context: ["name": contact.name])
        
        do {
            let cnContact = convertToCNContact(contact)
            let saveRequest = CNSaveRequest()
            saveRequest.add(cnContact, toContainerWithIdentifier: nil)
            
            try store.execute(saveRequest)
            
            // Update cache
            contactCache[contact.id] = contact
            
            logger?.log(level: .info, message: "Contact created successfully", context: ["id": contact.id.value])
            return .success(contact.id)
            
        } catch {
            let contactError = ContactError.system(.internalError("Failed to create contact: \(error.localizedDescription)"))
            logger?.log(level: .error, message: "Failed to create contact", context: [
                "name": contact.name,
                "error": error.localizedDescription
            ])
            return .failure(contactError)
        }
    }
    
    func deleteContact(id: ContactID) async -> Result<Void, ContactError> {
        guard accessGranted else {
            return .failure(.permission(.contactsAccessDenied))
        }
        
        logger?.log(level: .info, message: "Deleting contact", context: ["id": id.value])
        
        do {
            // Find the contact first
            guard let contact = try findCNContact(by: id) else {
                return .failure(.analysis(.invalidContact(id)))
            }
            
            let saveRequest = CNSaveRequest()
            let mutableContact = contact.mutableCopy() as! CNMutableContact
            saveRequest.delete(mutableContact)
            
            try store.execute(saveRequest)
            
            // Update cache
            contactCache.removeValue(forKey: id)
            
            logger?.log(level: .info, message: "Contact deleted successfully", context: ["id": id.value])
            return .success(())
            
        } catch {
            let contactError = ContactError.system(.internalError("Failed to delete contact: \(error.localizedDescription)"))
            logger?.log(level: .error, message: "Failed to delete contact", context: [
                "id": id.value,
                "error": error.localizedDescription
            ])
            return .failure(contactError)
        }
    }
    
    func updateContact(id: ContactID, with contact: Contact) async -> Result<Void, ContactError> {
        guard accessGranted else {
            return .failure(.permission(.contactsAccessDenied))
        }
        
        logger?.log(level: .info, message: "Updating contact", context: [
            "id": id.value,
            "name": contact.name
        ])
        
        do {
            // Find the existing contact
            guard let existingContact = try findCNContact(by: id) else {
                return .failure(.analysis(.invalidContact(id)))
            }
            
            let mutableContact = existingContact.mutableCopy() as! CNMutableContact
            updateCNContact(mutableContact, with: contact)
            
            let saveRequest = CNSaveRequest()
            saveRequest.update(mutableContact)
            
            try store.execute(saveRequest)
            
            // Update cache
            contactCache[id] = contact
            
            logger?.log(level: .info, message: "Contact updated successfully", context: ["id": id.value])
            return .success(())
            
        } catch {
            let contactError = ContactError.system(.internalError("Failed to update contact: \(error.localizedDescription)"))
            logger?.log(level: .error, message: "Failed to update contact", context: [
                "id": id.value,
                "error": error.localizedDescription
            ])
            return .failure(contactError)
        }
    }
    
    // MARK: - Private Methods
    
    private func loadCNContacts() async throws -> [CNContact] {
        let keys = [
            CNContactIdentifierKey,
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactMiddleNameKey,
            CNContactNamePrefixKey,
            CNContactNameSuffixKey,
            CNContactNicknameKey,
            CNContactPhoneticGivenNameKey,
            CNContactPhoneticMiddleNameKey,
            CNContactPhoneticFamilyNameKey,
            CNContactEmailAddressesKey,
            CNContactPhoneNumbersKey,
            CNContactPostalAddressesKey,
            CNContactUrlAddressesKey,
            CNContactSocialProfilesKey,
            CNContactInstantMessageAddressesKey,
            CNContactBirthdayKey,
            CNContactDatesKey,
            CNContactOrganizationNameKey,
            CNContactDepartmentNameKey,
            CNContactJobTitleKey,
            CNContactNoteKey,
            CNContactImageDataKey,
            CNContactImageDataAvailableKey,
            CNContactThumbnailImageDataKey,
            CNContactTypeKey
        ] as [CNKeyDescriptor]
        
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .givenName
        
        return try await withCheckedThrowingContinuation { continuation in
            var contacts: [CNContact] = []
            
            do {
                try store.enumerateContacts(with: request) { contact, _ in
                    contacts.append(contact)
                }
                continuation.resume(returning: contacts)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func findCNContact(by id: ContactID) throws -> CNContact? {
        let keys = [CNContactIdentifierKey] as [CNKeyDescriptor]
        return try store.unifiedContact(withIdentifier: id.value, keysToFetch: keys)
    }
    
    private func convertFromCNContact(_ cnContact: CNContact) -> Contact {
        let id = ContactID(cnContact.identifier)
        let fullName = [
            cnContact.namePrefix,
            cnContact.givenName,
            cnContact.middleName,
            cnContact.familyName,
            cnContact.nameSuffix
        ].filter { !$0.isEmpty }.joined(separator: " ")
        
        let name = fullName.isEmpty ? "No Name" : fullName
        
        var contact = Contact(id: id, name: name)
        
        // Name components
        contact.nameComponents = NameComponents(
            prefix: cnContact.namePrefix.isEmpty ? nil : cnContact.namePrefix,
            given: cnContact.givenName.isEmpty ? nil : cnContact.givenName,
            middle: cnContact.middleName.isEmpty ? nil : cnContact.middleName,
            family: cnContact.familyName.isEmpty ? nil : cnContact.familyName,
            suffix: cnContact.nameSuffix.isEmpty ? nil : cnContact.nameSuffix,
            nickname: cnContact.nickname.isEmpty ? nil : cnContact.nickname,
            phoneticGiven: cnContact.phoneticGivenName.isEmpty ? nil : cnContact.phoneticGivenName,
            phoneticMiddle: cnContact.phoneticMiddleName.isEmpty ? nil : cnContact.phoneticMiddleName,
            phoneticFamily: cnContact.phoneticFamilyName.isEmpty ? nil : cnContact.phoneticFamilyName
        )
        
        // Contact info
        contact.emails = cnContact.emailAddresses.map { email in
            LabeledValue(
                label: ContactLabel.from(cnLabel: email.label),
                value: email.value as String
            )
        }
        
        contact.phones = cnContact.phoneNumbers.map { phone in
            LabeledValue(
                label: ContactLabel.from(cnLabel: phone.label),
                value: phone.value.stringValue
            )
        }
        
        contact.addresses = cnContact.postalAddresses.map { address in
            LabeledAddress(
                label: ContactLabel.from(cnLabel: address.label),
                street: address.value.street.isEmpty ? nil : address.value.street,
                city: address.value.city.isEmpty ? nil : address.value.city,
                state: address.value.state.isEmpty ? nil : address.value.state,
                postalCode: address.value.postalCode.isEmpty ? nil : address.value.postalCode,
                country: address.value.country.isEmpty ? nil : address.value.country
            )
        }
        
        contact.urls = cnContact.urlAddresses.map { url in
            LabeledValue(
                label: ContactLabel.from(cnLabel: url.label),
                value: url.value as String
            )
        }
        
        contact.socialProfiles = cnContact.socialProfiles.map { profile in
            SocialProfile(
                label: ContactLabel.from(cnLabel: profile.label),
                service: profile.value.service,
                username: profile.value.username
            )
        }
        
        contact.instantMessages = cnContact.instantMessageAddresses.map { im in
            InstantMessage(
                label: ContactLabel.from(cnLabel: im.label),
                service: im.value.service,
                username: im.value.username
            )
        }
        
        // Organization
        contact.organizationName = cnContact.organizationName.isEmpty ? nil : cnContact.organizationName
        contact.jobTitle = cnContact.jobTitle.isEmpty ? nil : cnContact.jobTitle
        
        // Other fields
        contact.birthday = cnContact.birthday
        contact.note = cnContact.note.isEmpty ? nil : cnContact.note
        contact.imageData = cnContact.imageData
        contact.contactType = cnContact.contactType == .organization ? .organization : .person
        
        // Dates
        contact.dates = cnContact.dates.map { date in
            LabeledDate(
                label: date.label,
                date: date.value as! DateComponents
            )
        }
        
        return contact
    }
    
    private func convertToCNContact(_ contact: Contact) -> CNMutableContact {
        let cnContact = CNMutableContact()
        
        updateCNContact(cnContact, with: contact)
        
        return cnContact
    }
    
    private func updateCNContact(_ cnContact: CNMutableContact, with contact: Contact) {
        // Name components
        cnContact.namePrefix = contact.nameComponents.prefix ?? ""
        cnContact.givenName = contact.nameComponents.given ?? ""
        cnContact.middleName = contact.nameComponents.middle ?? ""
        cnContact.familyName = contact.nameComponents.family ?? ""
        cnContact.nameSuffix = contact.nameComponents.suffix ?? ""
        cnContact.nickname = contact.nameComponents.nickname ?? ""
        cnContact.phoneticGivenName = contact.nameComponents.phoneticGiven ?? ""
        cnContact.phoneticMiddleName = contact.nameComponents.phoneticMiddle ?? ""
        cnContact.phoneticFamilyName = contact.nameComponents.phoneticFamily ?? ""
        
        // Contact type
        cnContact.contactType = contact.contactType == .organization ? .organization : .person
        
        // Emails
        cnContact.emailAddresses = contact.emails.map { email in
            CNLabeledValue(
                label: email.label?.cnLabel,
                value: email.value as NSString
            )
        }
        
        // Phone numbers
        cnContact.phoneNumbers = contact.phones.map { phone in
            CNLabeledValue(
                label: phone.label?.cnLabel,
                value: CNPhoneNumber(stringValue: phone.value)
            )
        }
        
        // Addresses
        cnContact.postalAddresses = contact.addresses.map { address in
            let postalAddress = CNMutablePostalAddress()
            postalAddress.street = address.street ?? ""
            postalAddress.city = address.city ?? ""
            postalAddress.state = address.state ?? ""
            postalAddress.postalCode = address.postalCode ?? ""
            postalAddress.country = address.country ?? ""
            
            return CNLabeledValue(
                label: address.label?.cnLabel,
                value: postalAddress
            )
        }
        
        // URLs
        cnContact.urlAddresses = contact.urls.map { url in
            CNLabeledValue(
                label: url.label?.cnLabel,
                value: url.value as NSString
            )
        }
        
        // Social profiles
        cnContact.socialProfiles = contact.socialProfiles.map { profile in
            let socialProfile = CNSocialProfile(
                urlString: nil,
                username: profile.username,
                userIdentifier: nil,
                service: profile.service
            )
            return CNLabeledValue(
                label: profile.label?.cnLabel,
                value: socialProfile
            )
        }
        
        // Instant messages
        cnContact.instantMessageAddresses = contact.instantMessages.map { im in
            let imAddress = CNInstantMessageAddress(
                username: im.username,
                service: im.service
            )
            return CNLabeledValue(
                label: im.label?.cnLabel,
                value: imAddress
            )
        }
        
        // Organization
        cnContact.organizationName = contact.organizationName ?? ""
        cnContact.jobTitle = contact.jobTitle ?? ""
        
        // Other fields
        cnContact.birthday = contact.birthday
        cnContact.note = contact.note ?? ""
        cnContact.imageData = contact.imageData
        
        // Dates
        cnContact.dates = contact.dates.map { date in
            CNLabeledValue(
                label: date.label,
                value: date.date as NSDateComponents
            )
        }
    }
}

// MARK: - Configuration Extension

extension ContactConfiguration {
    static let `default` = ContactConfiguration(
        batchSize: 100,
        timeout: 30.0,
        enableCaching: true
    )
}