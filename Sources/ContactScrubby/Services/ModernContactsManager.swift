import Foundation
import Contacts

/// Modern contacts manager using actor pattern for thread safety
@MainActor
public final class ModernContactsManager: ContactManaging {
    
    // MARK: - Dependencies
    
    private let analyzer: ContactAnalyzing
    private let filter: ContactFiltering
    private let configuration: ContactConfiguration
    private let logger: Logging?
    
    // MARK: - State
    
    private var accessGranted: Bool = false
    private var contactCache: [ContactID: Contact] = [:]
    private var lastCacheUpdate: Date?
    
    // MARK: - Core Services
    
    private let contactStore = CNContactStore()
    
    // MARK: - Initialization
    
    public init(
        analyzer: ContactAnalyzing,
        filter: ContactFiltering,
        configuration: ContactConfiguration,
        logger: Logging?
    ) {
        self.analyzer = analyzer
        self.filter = filter
        self.configuration = configuration
        self.logger = logger
    }
    
    // MARK: - ContactManaging Implementation
    
    public func requestAccess() async throws -> Bool {
        logger?.log(level: .info, message: "Requesting contacts access", context: [:])
        
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.contactStore.requestAccess(for: .contacts) { [weak self] granted, error in
                if let error = error {
                    self?.logger?.log(level: .error, message: "Access request failed", context: ["error": error.localizedDescription])
                    continuation.resume(throwing: ContactError.permission(.contactsAccessDenied))
                } else {
                    Task { @MainActor in
                        self?.accessGranted = granted
                        self?.logger?.log(level: .info, message: "Access granted: \(granted)", context: [:])
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }
    
    public func loadContacts(filter: ContactFilter) async -> Result<[Contact], ContactError> {
        logger?.log(level: .info, message: "Loading contacts", context: ["filter": filter.mode.rawValue])
        
        guard accessGranted else {
            logger?.log(level: .error, message: "Access not granted", context: [:])
            return .failure(.permission(.contactsAccessDenied))
        }
        
        do {
            // Configure contact fetch request
            let request = CNContactFetchRequest(keysToFetch: allContactKeys())
            var cnContacts: [CNContact] = []
            
            // Fetch contacts with batch processing
            try contactStore.enumerateContacts(with: request) { cnContact, _ in
                cnContacts.append(cnContact)
            }
            
            logger?.log(level: .info, message: "Fetched \(cnContacts.count) contacts", context: [:])
            
            // Convert to modern Contact model
            let contacts = cnContacts.compactMap { cnContact in
                convertFromCNContact(cnContact)
            }
            
            // Apply filtering
            let filterResult = await self.filter.filter(contacts, using: filter)
            
            switch filterResult {
            case .success(let filteredContacts):
                logger?.log(level: .info, message: "Filtered to \(filteredContacts.count) contacts", context: [:])
                return .success(filteredContacts)
            case .failure(let error):
                logger?.log(level: .error, message: "Filtering failed", context: ["error": error.localizedDescription])
                return .failure(error)
            }
            
        } catch {
            logger?.log(level: .error, message: "Failed to load contacts", context: ["error": error.localizedDescription])
            return .failure(.system(.internalError(error.localizedDescription)))
        }
    }
    
    public func createContact(_ contact: Contact) async -> Result<ContactID, ContactError> {
        logger?.log(level: .info, message: "Creating contact", context: ["name": contact.name])
        
        guard accessGranted else {
            return .failure(.permission(.contactsAccessDenied))
        }
        
        do {
            let cnContact = convertToCNContact(contact)
            let saveRequest = CNSaveRequest()
            saveRequest.add(cnContact, toContainerWithIdentifier: nil)
            
            try contactStore.execute(saveRequest)
            
            let newContactID = ContactID(cnContact.identifier)
            logger?.log(level: .info, message: "Contact created successfully", context: ["id": newContactID.value])
            
            return .success(newContactID)
            
        } catch {
            logger?.log(level: .error, message: "Failed to create contact", context: ["error": error.localizedDescription])
            return .failure(.system(.internalError(error.localizedDescription)))
        }
    }
    
    public func deleteContact(id: ContactID) async -> Result<Void, ContactError> {
        logger?.log(level: .info, message: "Deleting contact", context: ["id": id.value])
        
        guard accessGranted else {
            return .failure(.permission(.contactsAccessDenied))
        }
        
        do {
            let request = CNContactFetchRequest(keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])
            request.predicate = CNContact.predicateForContacts(withIdentifiers: [id.value])
            
            var contactToDelete: CNContact?
            try contactStore.enumerateContacts(with: request) { contact, _ in
                contactToDelete = contact
            }
            
            guard let cnContact = contactToDelete else {
                return .failure(.analysis(.contactNotFound(id)))
            }
            
            let saveRequest = CNSaveRequest()
            saveRequest.delete(cnContact.mutableCopy() as! CNMutableContact)
            
            try contactStore.execute(saveRequest)
            
            logger?.log(level: .info, message: "Contact deleted successfully", context: ["id": id.value])
            return .success(())
            
        } catch {
            logger?.log(level: .error, message: "Failed to delete contact", context: ["error": error.localizedDescription])
            return .failure(.system(.internalError(error.localizedDescription)))
        }
    }
    
    public func updateContact(id: ContactID, with contact: Contact) async -> Result<Void, ContactError> {
        logger?.log(level: .info, message: "Updating contact", context: ["id": id.value])
        
        guard accessGranted else {
            return .failure(.permission(.contactsAccessDenied))
        }
        
        do {
            let request = CNContactFetchRequest(keysToFetch: allContactKeys())
            request.predicate = CNContact.predicateForContacts(withIdentifiers: [id.value])
            
            var existingContact: CNContact?
            try contactStore.enumerateContacts(with: request) { contact, _ in
                existingContact = contact
            }
            
            guard let cnContact = existingContact else {
                return .failure(.analysis(.contactNotFound(id)))
            }
            
            let mutableContact = cnContact.mutableCopy() as! CNMutableContact
            updateCNContact(mutableContact, with: contact)
            
            let saveRequest = CNSaveRequest()
            saveRequest.update(mutableContact)
            
            try contactStore.execute(saveRequest)
            
            logger?.log(level: .info, message: "Contact updated successfully", context: ["id": id.value])
            return .success(())
            
        } catch {
            logger?.log(level: .error, message: "Failed to update contact", context: ["error": error.localizedDescription])
            return .failure(.system(.internalError(error.localizedDescription)))
        }
    }
    
    // MARK: - Helper Methods
    
    private func allContactKeys() -> [CNKeyDescriptor] {
        return [
            CNContactIdentifierKey,
            CNContactNamePrefixKey,
            CNContactGivenNameKey,
            CNContactMiddleNameKey,
            CNContactFamilyNameKey,
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
            CNContactJobTitleKey,
            CNContactNoteKey,
            CNContactImageDataKey,
CNContactTypeKey
        ] as [CNKeyDescriptor]
    }
    
    private func convertFromCNContact(_ cnContact: CNContact) -> Contact? {
        let contactID = ContactID(cnContact.identifier)
        let name = cnContact.givenName.isEmpty && cnContact.familyName.isEmpty 
            ? cnContact.nickname.isEmpty ? "Unknown" : cnContact.nickname
            : "\(cnContact.givenName) \(cnContact.familyName)".trimmingCharacters(in: .whitespaces)
        
        var contact = Contact(id: contactID, name: name)
        
        // Name components
        contact.nameComponents = NameComponents()
        contact.nameComponents.prefix = cnContact.namePrefix.isEmpty ? nil : cnContact.namePrefix
        contact.nameComponents.given = cnContact.givenName.isEmpty ? nil : cnContact.givenName
        contact.nameComponents.middle = cnContact.middleName.isEmpty ? nil : cnContact.middleName
        contact.nameComponents.family = cnContact.familyName.isEmpty ? nil : cnContact.familyName
        contact.nameComponents.suffix = cnContact.nameSuffix.isEmpty ? nil : cnContact.nameSuffix
        contact.nameComponents.nickname = cnContact.nickname.isEmpty ? nil : cnContact.nickname
        contact.nameComponents.phoneticGiven = cnContact.phoneticGivenName.isEmpty ? nil : cnContact.phoneticGivenName
        contact.nameComponents.phoneticMiddle = cnContact.phoneticMiddleName.isEmpty ? nil : cnContact.phoneticMiddleName
        contact.nameComponents.phoneticFamily = cnContact.phoneticFamilyName.isEmpty ? nil : cnContact.phoneticFamilyName
        
        // Email addresses
        contact.emails = cnContact.emailAddresses.map { emailAddress in
            LabeledValue(
                label: ContactLabel.from(cnLabel: emailAddress.label),
                value: emailAddress.value as String
            )
        }
        
        // Phone numbers
        contact.phones = cnContact.phoneNumbers.map { phoneNumber in
            LabeledValue(
                label: ContactLabel.from(cnLabel: phoneNumber.label),
                value: phoneNumber.value.stringValue
            )
        }
        
        // Postal addresses
        contact.addresses = cnContact.postalAddresses.map { postalAddress in
            let address = postalAddress.value
            return LabeledAddress(
                label: ContactLabel.from(cnLabel: postalAddress.label),
                street: address.street.isEmpty ? nil : address.street,
                city: address.city.isEmpty ? nil : address.city,
                state: address.state.isEmpty ? nil : address.state,
                postalCode: address.postalCode.isEmpty ? nil : address.postalCode,
                country: address.country.isEmpty ? nil : address.country
            )
        }
        
        // URLs
        contact.urls = cnContact.urlAddresses.map { urlAddress in
            LabeledValue(
                label: ContactLabel.from(cnLabel: urlAddress.label),
                value: urlAddress.value as String
            )
        }
        
        // Social profiles
        contact.socialProfiles = cnContact.socialProfiles.map { socialProfile in
            SocialProfile(
                label: ContactLabel.from(cnLabel: socialProfile.label),
                service: socialProfile.value.service,
                username: socialProfile.value.username
            )
        }
        
        // Instant messages
        contact.instantMessages = cnContact.instantMessageAddresses.map { imAddress in
            InstantMessage(
                label: ContactLabel.from(cnLabel: imAddress.label),
                service: imAddress.value.service,
                username: imAddress.value.username
            )
        }
        
        // Birthday
        contact.birthday = cnContact.birthday
        
        // Dates
        contact.dates = cnContact.dates.map { date in
            LabeledDate(
                label: date.label,
                date: date.value as DateComponents
            )
        }
        
        // Organization
        contact.organizationName = cnContact.organizationName.isEmpty ? nil : cnContact.organizationName
        contact.jobTitle = cnContact.jobTitle.isEmpty ? nil : cnContact.jobTitle
        
        // Note
        contact.note = cnContact.note.isEmpty ? nil : cnContact.note
        
        // Image
        contact.imageData = cnContact.imageData
        
        // Contact type
        contact.contactType = cnContact.contactType == .organization ? .organization : .person
        
        return contact
    }
    
    private func convertToCNContact(_ contact: Contact) -> CNMutableContact {
        let cnContact = CNMutableContact()
        
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
        
        // Email addresses
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
        
        // Organization
        cnContact.organizationName = contact.organizationName ?? ""
        cnContact.jobTitle = contact.jobTitle ?? ""
        
        // Note
        cnContact.note = contact.note ?? ""
        
        // Image
        cnContact.imageData = contact.imageData
        
        // Contact type
        cnContact.contactType = contact.contactType == .organization ? .organization : .person
        
        return cnContact
    }
    
    private func updateCNContact(_ cnContact: CNMutableContact, with contact: Contact) {
        // Update name components
        cnContact.namePrefix = contact.nameComponents.prefix ?? ""
        cnContact.givenName = contact.nameComponents.given ?? ""
        cnContact.middleName = contact.nameComponents.middle ?? ""
        cnContact.familyName = contact.nameComponents.family ?? ""
        cnContact.nameSuffix = contact.nameComponents.suffix ?? ""
        cnContact.nickname = contact.nameComponents.nickname ?? ""
        cnContact.phoneticGivenName = contact.nameComponents.phoneticGiven ?? ""
        cnContact.phoneticMiddleName = contact.nameComponents.phoneticMiddle ?? ""
        cnContact.phoneticFamilyName = contact.nameComponents.phoneticFamily ?? ""
        
        // Update email addresses
        cnContact.emailAddresses = contact.emails.map { email in
            CNLabeledValue(
                label: email.label?.cnLabel,
                value: email.value as NSString
            )
        }
        
        // Update phone numbers
        cnContact.phoneNumbers = contact.phones.map { phone in
            CNLabeledValue(
                label: phone.label?.cnLabel,
                value: CNPhoneNumber(stringValue: phone.value)
            )
        }
        
        // Update organization
        cnContact.organizationName = contact.organizationName ?? ""
        cnContact.jobTitle = contact.jobTitle ?? ""
        
        // Update note
        cnContact.note = contact.note ?? ""
        
        // Update image
        cnContact.imageData = contact.imageData
        
        // Update contact type
        cnContact.contactType = contact.contactType == .organization ? .organization : .person
    }
}