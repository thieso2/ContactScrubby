import Foundation
import Contacts

struct SerializableContact: Codable {
    let name: String
    let namePrefix: String?
    let givenName: String?
    let middleName: String?
    let familyName: String?
    let nameSuffix: String?
    let nickname: String?
    let phoneticGivenName: String?
    let phoneticMiddleName: String?
    let phoneticFamilyName: String?
    let organizationName: String?
    let departmentName: String?
    let jobTitle: String?
    let emails: [LabeledValue]
    let phones: [LabeledValue]
    let postalAddresses: [LabeledAddress]
    let urls: [LabeledValue]
    let socialProfiles: [SocialProfile]
    let instantMessageAddresses: [InstantMessage]
    let birthday: DateInfo?
    let dates: [LabeledDate]
    let contactType: String
    let hasImage: Bool
    let imageData: String? // Base64 encoded image data
    let thumbnailImageData: String? // Base64 encoded thumbnail image data
    let note: String?

    struct LabeledValue: Codable {
        let label: String?
        let value: String
    }

    struct LabeledAddress: Codable {
        let label: String?
        let street: String?
        let city: String?
        let state: String?
        let postalCode: String?
        let country: String?
    }

    struct SocialProfile: Codable {
        let label: String?
        let service: String
        let username: String
    }

    struct InstantMessage: Codable {
        let label: String?
        let service: String
        let username: String
    }

    struct DateInfo: Codable {
        let day: Int?
        let month: Int?
        let year: Int?
    }

    struct LabeledDate: Codable {
        let label: String?
        let date: DateInfo
    }
}

class ContactsManager {
    private let store = CNContactStore()

    func requestAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            store.requestAccess(for: .contacts) { granted, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func listAllContacts(filterMode: FilterMode = .withEmail, dubiousMinScore: Int = 3) throws
        -> [(name: String, emails: [String], phones: [String])] {
        let keysToFetch = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactEmailAddressesKey,
            CNContactPhoneNumbersKey
        ] as [CNKeyDescriptor]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        var contacts: [(name: String, emails: [String], phones: [String])] = []

        try store.enumerateContacts(with: request) { contact, _ in
            let emails = contact.emailAddresses.map { $0.value as String }
            let phones = contact.phoneNumbers.map { $0.value.stringValue }

            let fullName = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            let displayName = fullName.isEmpty ? "No Name" : fullName

            switch filterMode {
            case .withEmail:
                if !emails.isEmpty {
                    contacts.append((name: displayName, emails: emails, phones: phones))
                }
            case .withoutEmail:
                if emails.isEmpty {
                    contacts.append((name: displayName, emails: emails, phones: phones))
                }
            case .facebookOnly:
                let facebookEmails = emails.filter { $0.lowercased().hasSuffix("@facebook.com") }
                if !facebookEmails.isEmpty {
                    contacts.append((name: displayName, emails: facebookEmails, phones: phones))
                }
            case .facebookExclusive:
                let facebookEmails = emails.filter { $0.lowercased().hasSuffix("@facebook.com") }
                let hasOnlyFacebookEmails = !facebookEmails.isEmpty && facebookEmails.count == emails.count
                let hasNoPhones = phones.isEmpty

                if hasOnlyFacebookEmails && hasNoPhones {
                    contacts.append((name: displayName, emails: facebookEmails, phones: phones))
                }
            case .dubious:
                // For dubious analysis, we need full contact data, so we'll handle this differently
                break
            case .all:
                contacts.append((name: displayName, emails: emails, phones: phones))
            }
        }

        // Special handling for dubious contacts - requires full contact data
        if filterMode == .dubious {
            let fullContacts = try listContactsWithAllFields()
            for contact in fullContacts {
                let analysis = analyzeContact(contact)
                if analysis.isDubious(minimumScore: dubiousMinScore) {
                    let emails = contact.emailAddresses.map { $0.value as String }
                    let phones = contact.phoneNumbers.map { $0.value.stringValue }
                    let fullName = [contact.givenName, contact.familyName]
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    let displayName = fullName.isEmpty ? "No Name" : fullName
                    contacts.append((name: displayName, emails: emails, phones: phones))
                }
            }
        }

        return contacts.sorted { $0.name < $1.name }
    }

    func listContactsWithAllFields() throws -> [CNContact] {
        let keysToFetch = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactMiddleNameKey,
            CNContactNamePrefixKey,
            CNContactNameSuffixKey,
            CNContactNicknameKey,
            CNContactPhoneticGivenNameKey,
            CNContactPhoneticMiddleNameKey,
            CNContactPhoneticFamilyNameKey,
            CNContactOrganizationNameKey,
            CNContactDepartmentNameKey,
            CNContactJobTitleKey,
            CNContactEmailAddressesKey,
            CNContactPhoneNumbersKey,
            CNContactPostalAddressesKey,
            CNContactUrlAddressesKey,
            CNContactRelationsKey,
            CNContactSocialProfilesKey,
            CNContactInstantMessageAddressesKey,
            CNContactBirthdayKey,
            CNContactNonGregorianBirthdayKey,
            CNContactDatesKey,
            CNContactTypeKey,
            CNContactImageDataKey,
            CNContactThumbnailImageDataKey,
            CNContactImageDataAvailableKey,
            CNContactNoteKey
        ] as [CNKeyDescriptor]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        var contacts: [CNContact] = []

        try store.enumerateContacts(with: request) { contact, _ in
            contacts.append(contact)
        }

        return contacts.sorted {
            let name1 = [$0.givenName, $0.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            let name2 = [$1.givenName, $1.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            return name1 < name2
        }
    }

    struct ContactAnalysis {
        let contact: CNContact
        let dubiousScore: Int
        let reasons: [String]
        let isIncomplete: Bool
        let isSuspicious: Bool

        func isDubious(minimumScore: Int = 3) -> Bool {
            dubiousScore >= minimumScore
        }
    }

    public func analyzeContact(_ contact: CNContact) -> ContactAnalysis {
        var score = 0
        var reasons: [String] = []
        var isIncomplete = false
        var isSuspicious = false

        let emails = contact.emailAddresses.map { $0.value as String }
        let phones = contact.phoneNumbers.map { $0.value.stringValue }
        let hasName = !contact.givenName.isEmpty || !contact.familyName.isEmpty

        // Heuristic 1: No name or generic name
        if !hasName {
            score += 2
            reasons.append("No name provided")
            isIncomplete = true
        } else {
            let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)

            // Check for generic/suspicious names
            let suspiciousNames = ["facebook user", "unknown", "user", "contact", "friend", "no name", "temp", "test"]
            if suspiciousNames.contains(where: { fullName.lowercased().contains($0) }) {
                score += 3
                reasons.append("Generic or suspicious name pattern")
                isSuspicious = true
            }

            // Single character names
            if fullName.replacingOccurrences(of: " ", with: "").count <= 2 {
                score += 2
                reasons.append("Very short name")
                isSuspicious = true
            }

            // All caps or all lowercase (typical of auto-imports)
            if fullName == fullName.uppercased() || fullName == fullName.lowercased() {
                score += 1
                reasons.append("Unusual capitalization")
            }
        }

        // Heuristic 2: Only Facebook email and no other contact info
        let facebookEmails = emails.filter { $0.lowercased().contains("facebook") || $0.lowercased().contains("fb.com") }
        if !facebookEmails.isEmpty && emails.count == facebookEmails.count && phones.isEmpty {
            score += 3
            reasons.append("Only Facebook email, no other contact info")
            isSuspicious = true
        }

        // Heuristic 3: Email patterns that suggest auto-import
        for email in emails {
            let emailLower = email.lowercased()

            // Numeric usernames (often auto-generated)
            let username = emailLower.split(separator: "@").first ?? ""
            if username.allSatisfy({ $0.isNumber }) {
                score += 2
                reasons.append("Numeric email username")
                isSuspicious = true
            }

            // Very long random-looking usernames
            if username.count > 20 && username.contains(where: { $0.isNumber }) {
                score += 1
                reasons.append("Long complex email username")
            }

            // Auto-generated patterns
            if emailLower.contains("noreply") || emailLower.contains("no-reply") || emailLower.contains("donotreply") {
                score += 3
                reasons.append("No-reply email address")
                isSuspicious = true
            }
        }

        // Heuristic 4: Missing basic contact information
        let missingInfo = [
            emails.isEmpty ? "email" : nil,
            phones.isEmpty ? "phone" : nil,
            contact.organizationName.isEmpty ? "organization" : nil
        ].compactMap { $0 }

        if missingInfo.count >= 2 {
            score += 1
            reasons.append("Missing multiple basic fields: \(missingInfo.joined(separator: ", "))")
            isIncomplete = true
        }

        // Heuristic 5: Only has minimal fields (name + email, nothing else)
        let hasAddress = !contact.postalAddresses.isEmpty
        let hasOrganization = !contact.organizationName.isEmpty
        let hasNotes = contact.isKeyAvailable(CNContactNoteKey) && !contact.note.isEmpty
        let hasBirthday = contact.birthday != nil
        let hasUrls = !contact.urlAddresses.isEmpty

        let richDataCount = [hasAddress, hasOrganization, hasNotes, hasBirthday, hasUrls, !phones.isEmpty].filter { $0 }.count

        if richDataCount == 0 && !emails.isEmpty {
            score += 2
            reasons.append("Only basic info (name + email)")
            isIncomplete = true
        }

        // Heuristic 6: Phone number patterns
        for phone in phones {
            let cleanPhone = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)

            // Fake/test numbers
            if cleanPhone.hasPrefix("555") || cleanPhone == "1234567890" || cleanPhone.allSatisfy({ $0 == cleanPhone.first! }) {
                score += 2
                reasons.append("Suspicious phone number pattern")
                isSuspicious = true
            }
        }

        return ContactAnalysis(
            contact: contact,
            dubiousScore: score,
            reasons: reasons,
            isIncomplete: isIncomplete,
            isSuspicious: isSuspicious
        )
    }

    func getDubiousContacts(minimumScore: Int = 3) throws -> [ContactAnalysis] {
        let contacts = try listContactsWithAllFields()
        var dubiousAnalyses: [ContactAnalysis] = []

        for contact in contacts {
            let analysis = analyzeContact(contact)
            if analysis.isDubious(minimumScore: minimumScore) {
                dubiousAnalyses.append(analysis)
            }
        }

        return dubiousAnalyses.sorted { $0.dubiousScore > $1.dubiousScore }
    }

    func getContactsForExport(filterMode: FilterMode = .all, dubiousMinScore: Int = 3, imageMode: ImageMode = .none) throws -> [SerializableContact] {
        let contacts = try listContactsWithAllFields()
        var serializableContacts: [SerializableContact] = []

        for contact in contacts {
            let emails = contact.emailAddresses.map { $0.value as String }
            let phones = contact.phoneNumbers.map { $0.value.stringValue }

            // Apply filter
            switch filterMode {
            case .withEmail:
                if emails.isEmpty { continue }
            case .withoutEmail:
                if !emails.isEmpty { continue }
            case .facebookOnly:
                let facebookEmails = emails.filter { $0.lowercased().hasSuffix("@facebook.com") }
                if facebookEmails.isEmpty { continue }
            case .facebookExclusive:
                let facebookEmails = emails.filter { $0.lowercased().hasSuffix("@facebook.com") }
                let hasOnlyFacebookEmails = !facebookEmails.isEmpty && facebookEmails.count == emails.count
                let hasNoPhones = phones.isEmpty
                if !(hasOnlyFacebookEmails && hasNoPhones) { continue }
            case .dubious:
                let analysis = analyzeContact(contact)
                if !analysis.isDubious(minimumScore: dubiousMinScore) { continue }
            case .all:
                break
            }

            let includeImages = imageMode == .inline || imageMode == .folder
            let serializable = convertToSerializable(contact, includeImages: includeImages)
            serializableContacts.append(serializable)
        }

        return serializableContacts
    }

    func getContactsForFolderExport(filterMode: FilterMode = .all, dubiousMinScore: Int = 3) throws -> [CNContact] {
        let contacts = try listContactsWithAllFields()
        var filteredContacts: [CNContact] = []

        for contact in contacts {
            let emails = contact.emailAddresses.map { $0.value as String }
            let phones = contact.phoneNumbers.map { $0.value.stringValue }

            // Apply filter
            switch filterMode {
            case .withEmail:
                if emails.isEmpty { continue }
            case .withoutEmail:
                if !emails.isEmpty { continue }
            case .facebookOnly:
                let facebookEmails = emails.filter { $0.lowercased().hasSuffix("@facebook.com") }
                if facebookEmails.isEmpty { continue }
            case .facebookExclusive:
                let facebookEmails = emails.filter { $0.lowercased().hasSuffix("@facebook.com") }
                let hasOnlyFacebookEmails = !facebookEmails.isEmpty && facebookEmails.count == emails.count
                let hasNoPhones = phones.isEmpty
                if !(hasOnlyFacebookEmails && hasNoPhones) { continue }
            case .dubious:
                let analysis = analyzeContact(contact)
                if !analysis.isDubious(minimumScore: dubiousMinScore) { continue }
            case .all:
                break
            }

            filteredContacts.append(contact)
        }

        return filteredContacts
    }

    private func cleanLabel(_ label: String?) -> String? {
        guard let label = label else { return nil }

        let localizedLabel = CNLabeledValue<NSString>.localizedString(forLabel: label)

        // If it's still in the internal format, clean it up
        if localizedLabel.hasPrefix("_$!<") && localizedLabel.hasSuffix(">!$_") {
            let cleaned = localizedLabel
                .replacingOccurrences(of: "_$!<", with: "")
                .replacingOccurrences(of: ">!$_", with: "")
            return cleaned
        }

        return localizedLabel
    }

    func findOrCreateGroup(named groupName: String) throws -> CNMutableGroup {
        // First, try to find an existing group
        let request = CNContactFetchRequest(keysToFetch: [])
        request.mutableObjects = true

        // Get all groups
        var existingGroups: [CNGroup] = []
        do {
            try store.enumerateContacts(with: request) { _, _ in }
            existingGroups = try store.groups(matching: nil)
        } catch {
            // Continue even if we can't enumerate groups
        }

        // Check if group already exists
        for group in existingGroups where group.name == groupName {
            return group.mutableCopy() as! CNMutableGroup
        }

        // Create new group if it doesn't exist
        let newGroup = CNMutableGroup()
        newGroup.name = groupName

        let saveRequest = CNSaveRequest()
        saveRequest.add(newGroup, toContainerWithIdentifier: nil)

        try store.execute(saveRequest)

        return newGroup
    }

    func addContactsToGroup(contacts: [CNContact], groupName: String) throws -> (added: Int, skipped: Int, errors: [String]) {
        var addedCount = 0
        var skippedCount = 0
        var errors: [String] = []

        do {
            let group = try findOrCreateGroup(named: groupName)

            for contact in contacts {
                do {
                    let saveRequest = CNSaveRequest()
                    saveRequest.addMember(contact, to: group)
                    try store.execute(saveRequest)
                    addedCount += 1
                } catch {
                    if error.localizedDescription.contains("already exists") {
                        skippedCount += 1
                    } else {
                        let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                        let displayName = name.isEmpty ? "No Name" : name
                        errors.append("Failed to add \(displayName): \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            errors.append("Failed to create or find group '\(groupName)': \(error.localizedDescription)")
        }

        return (added: addedCount, skipped: skippedCount, errors: errors)
    }

    func convertToSerializable(_ contact: CNContact, includeImages: Bool = false) -> SerializableContact {
        let fullName = [contact.namePrefix, contact.givenName, contact.middleName, contact.familyName, contact.nameSuffix]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let name = fullName.isEmpty ? "No Name" : fullName

        let emails = contact.emailAddresses.map {
            SerializableContact.LabeledValue(
                label: cleanLabel($0.label),
                value: $0.value as String
            )
        }

        let phones = contact.phoneNumbers.map {
            SerializableContact.LabeledValue(
                label: cleanLabel($0.label),
                value: $0.value.stringValue
            )
        }

        let addresses = contact.postalAddresses.map { address in
            SerializableContact.LabeledAddress(
                label: cleanLabel(address.label),
                street: address.value.street.isEmpty ? nil : address.value.street,
                city: address.value.city.isEmpty ? nil : address.value.city,
                state: address.value.state.isEmpty ? nil : address.value.state,
                postalCode: address.value.postalCode.isEmpty ? nil : address.value.postalCode,
                country: address.value.country.isEmpty ? nil : address.value.country
            )
        }

        let urls = contact.urlAddresses.map {
            SerializableContact.LabeledValue(
                label: cleanLabel($0.label),
                value: $0.value as String
            )
        }

        let socialProfiles = contact.socialProfiles.map { profile in
            SerializableContact.SocialProfile(
                label: cleanLabel(profile.label),
                service: profile.value.service,
                username: profile.value.username
            )
        }

        let instantMessages = contact.instantMessageAddresses.map { im in
            SerializableContact.InstantMessage(
                label: cleanLabel(im.label),
                service: im.value.service,
                username: im.value.username
            )
        }

        let birthday = contact.birthday.map {
            SerializableContact.DateInfo(day: $0.day, month: $0.month, year: $0.year)
        }

        let dates = contact.dates.map { date in
            let dateComponents = date.value as DateComponents
            return SerializableContact.LabeledDate(
                label: cleanLabel(date.label),
                date: SerializableContact.DateInfo(
                    day: dateComponents.day,
                    month: dateComponents.month,
                    year: dateComponents.year
                )
            )
        }

        return SerializableContact(
            name: name,
            namePrefix: contact.namePrefix.isEmpty ? nil : contact.namePrefix,
            givenName: contact.givenName.isEmpty ? nil : contact.givenName,
            middleName: contact.middleName.isEmpty ? nil : contact.middleName,
            familyName: contact.familyName.isEmpty ? nil : contact.familyName,
            nameSuffix: contact.nameSuffix.isEmpty ? nil : contact.nameSuffix,
            nickname: contact.nickname.isEmpty ? nil : contact.nickname,
            phoneticGivenName: contact.phoneticGivenName.isEmpty ? nil : contact.phoneticGivenName,
            phoneticMiddleName: contact.phoneticMiddleName.isEmpty ? nil : contact.phoneticMiddleName,
            phoneticFamilyName: contact.phoneticFamilyName.isEmpty ? nil : contact.phoneticFamilyName,
            organizationName: contact.organizationName.isEmpty ? nil : contact.organizationName,
            departmentName: contact.departmentName.isEmpty ? nil : contact.departmentName,
            jobTitle: contact.jobTitle.isEmpty ? nil : contact.jobTitle,
            emails: emails,
            phones: phones,
            postalAddresses: addresses,
            urls: urls,
            socialProfiles: socialProfiles,
            instantMessageAddresses: instantMessages,
            birthday: birthday,
            dates: dates,
            contactType: contact.contactType == .organization ? "Organization" : "Person",
            hasImage: contact.imageDataAvailable,
            imageData: includeImages && contact.isKeyAvailable(CNContactImageDataKey) && contact.imageData != nil
                ? contact.imageData?.base64EncodedString() : nil,
            thumbnailImageData: includeImages && contact.isKeyAvailable(CNContactThumbnailImageDataKey) && contact.thumbnailImageData != nil
                ? contact.thumbnailImageData?.base64EncodedString() : nil,
            note: contact.isKeyAvailable(CNContactNoteKey) && !contact.note.isEmpty ? contact.note : nil
        )
    }
}
