import Foundation
import Contacts
import ArgumentParser

@main
struct ContactsCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ContactsCLI",
        abstract: "A command-line tool for managing and exporting contacts",
        version: "1.0.0"
    )
    
    @Option(name: .shortAndLong, help: "Filter mode for contacts")
    var filter: FilterMode = .withEmail
    
    @Option(name: .long, help: "Minimum dubiousness score for dubious contacts")
    var dubiousScore: Int = 3
    
    @Flag(name: .long, help: "Show all available contact fields")
    var dump: Bool = false
    
    @Option(name: .long, help: "Export contacts to file (JSON or XML)")
    var backup: String?
    
    @Option(name: .long, help: "Include images in export")
    var includeImages: ImageMode = .none
    
    @Option(name: .long, help: "Add filtered contacts to specified group")
    var addToGroup: String?
    
    func run() async throws {
        let manager = ContactsManager()
        
        let granted = try await manager.requestAccess()
        
        if !granted {
            print("Access to contacts was denied. Please grant permission in System Preferences.")
            throw ExitCode.failure
        }
        
        // Handle group addition if requested
        if let groupName = addToGroup {
            try await handleGroupOperation(manager: manager, groupName: groupName)
            return
        }
        
        // Handle backup/export if requested
        if let filename = backup {
            try await handleExportOperation(manager: manager, filename: filename)
            return
        }
        
        // Handle dump all fields
        if dump {
            try await handleDumpOperation(manager: manager)
            return
        }
        
        // Default: display contacts
        try await handleDisplayOperation(manager: manager)
    }
    
    private func handleGroupOperation(manager: ContactsManager, groupName: String) async throws {
        let contacts: [CNContact]
        
        if filter == .dubious {
            let analyses = try manager.getDubiousContacts(minimumScore: dubiousScore)
            contacts = analyses.map { $0.contact }
        } else {
            contacts = try manager.listContactsWithAllFields().filter { contact in
                return shouldIncludeContact(contact, filter: filter)
            }
        }
        
        if contacts.isEmpty {
            print("No contacts found matching the specified criteria.")
            return
        }
        
        print("Adding \(contacts.count) contact(s) to group '\(groupName)'...")
        
        let result = try manager.addContactsToGroup(contacts: contacts, groupName: groupName)
        
        print("Results:")
        print("  Successfully added: \(result.added)")
        if result.skipped > 0 {
            print("  Skipped (already in group): \(result.skipped)")
        }
        if !result.errors.isEmpty {
            print("  Errors:")
            for error in result.errors {
                print("    - \(error)")
            }
        }
        
        print("\nGroup operation completed.")
    }
    
    private func handleExportOperation(manager: ContactsManager, filename: String) async throws {
        let exportOptions = ExportOptions(
            filename: filename,
            imageMode: includeImages,
            filterMode: filter,
            dubiousMinScore: dubiousScore
        )
        
        guard exportOptions.isValidFormat else {
            print("Error: Unsupported file format. Please use .json or .xml extension")
            throw ExitCode.failure
        }
        
        let contacts = try manager.getContactsForExport(
            filterMode: filter,
            dubiousMinScore: dubiousScore,
            imageMode: includeImages
        )
        
        if contacts.isEmpty {
            print(Self.getEmptyMessage(for: filter))
            return
        }
        
        switch exportOptions.fileExtension {
        case "json":
            if includeImages == .folder {
                let rawContacts = try manager.getContactsForFolderExport(
                    filterMode: filter,
                    dubiousMinScore: dubiousScore
                )
                let (exportedContacts, imageFolder) = try Self.exportWithFolderImages(
                    rawContacts: rawContacts,
                    baseFilename: filename
                )
                try Self.exportAsJSON(contacts: exportedContacts, to: exportOptions.fileURL)
                print("Successfully exported \(exportedContacts.count) contact(s) to \(filename)")
                if let folder = imageFolder {
                    print("Images saved to folder: \(folder)")
                }
            } else {
                try Self.exportAsJSON(contacts: contacts, to: exportOptions.fileURL)
                print("Successfully exported \(contacts.count) contact(s) to \(filename)")
            }
        case "xml":
            if includeImages == .folder {
                let rawContacts = try manager.getContactsForFolderExport(
                    filterMode: filter,
                    dubiousMinScore: dubiousScore
                )
                let (exportedContacts, imageFolder) = try Self.exportWithFolderImages(
                    rawContacts: rawContacts,
                    baseFilename: filename
                )
                try Self.exportAsXML(contacts: exportedContacts, to: exportOptions.fileURL)
                print("Successfully exported \(exportedContacts.count) contact(s) to \(filename)")
                if let folder = imageFolder {
                    print("Images saved to folder: \(folder)")
                }
            } else {
                try Self.exportAsXML(contacts: contacts, to: exportOptions.fileURL)
                print("Successfully exported \(contacts.count) contact(s) to \(filename)")
            }
        default:
            print("Error: Unsupported file format. Please use .json or .xml extension")
            throw ExitCode.failure
        }
    }
    
    private func handleDumpOperation(manager: ContactsManager) async throws {
        let fullContacts = try manager.listContactsWithAllFields()
        
        if fullContacts.isEmpty {
            print("No contacts found.")
        } else {
            print("All contacts with full details:\n")
            
            for contact in fullContacts {
                Self.printFullContactDetails(contact)
                print(String(repeating: "-", count: 50))
                print()
            }
            
            print("Total: \(fullContacts.count) contact(s)")
        }
    }
    
    private func handleDisplayOperation(manager: ContactsManager) async throws {
        if filter == .dubious {
            let dubiousAnalyses = try manager.getDubiousContacts(minimumScore: dubiousScore)
            
            if dubiousAnalyses.isEmpty {
                print(Self.getEmptyMessage(for: filter))
            } else {
                var headerMessage = Self.getHeaderMessage(for: filter)
                if dubiousScore != 3 {
                    headerMessage += " (minimum score: \(dubiousScore))"
                }
                print(headerMessage + "\n")
                
                for analysis in dubiousAnalyses {
                    let contact = analysis.contact
                    let emails = contact.emailAddresses.map { $0.value as String }
                    let phones = contact.phoneNumbers.map { $0.value.stringValue }
                    let fullName = [contact.givenName, contact.familyName]
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    let displayName = fullName.isEmpty ? "No Name" : fullName
                    
                    print("Name: \(displayName) [Score: \(analysis.dubiousScore)]")
                    
                    if !emails.isEmpty {
                        for email in emails {
                            print("  Email: \(email)")
                        }
                    }
                    
                    if !phones.isEmpty {
                        for phone in phones {
                            print("  Phone: \(phone)")
                        }
                    }
                    
                    print("  Issues: \(analysis.reasons.joined(separator: ", "))")
                    
                    if analysis.isIncomplete {
                        print("  Status: Incomplete")
                    }
                    if analysis.isSuspicious {
                        print("  Status: Suspicious")
                    }
                    
                    print()
                }
                
                print("Total: \(dubiousAnalyses.count) dubious contact(s)")
            }
        } else {
            let contacts = try manager.listAllContacts(filterMode: filter, dubiousMinScore: dubiousScore)
            
            if contacts.isEmpty {
                print(Self.getEmptyMessage(for: filter))
            } else {
                print(Self.getHeaderMessage(for: filter) + "\n")
                
                for contact in contacts {
                    print("Name: \(contact.name)")
                    
                    if !contact.emails.isEmpty {
                        for email in contact.emails {
                            print("  Email: \(email)")
                        }
                    }
                    
                    if !contact.phones.isEmpty {
                        for phone in contact.phones {
                            print("  Phone: \(phone)")
                        }
                    }
                    
                    print()
                }
                
                print("Total: \(contacts.count) contact(s)")
            }
        }
    }
    
    private func shouldIncludeContact(_ contact: CNContact, filter: FilterMode) -> Bool {
        let emails = contact.emailAddresses.map { $0.value as String }
        let phones = contact.phoneNumbers.map { $0.value.stringValue }
        
        switch filter {
        case .withEmail:
            return !emails.isEmpty
        case .withoutEmail:
            return emails.isEmpty
        case .facebookOnly:
            let facebookEmails = emails.filter { $0.lowercased().hasSuffix("@facebook.com") }
            return !facebookEmails.isEmpty
        case .facebookExclusive:
            let facebookEmails = emails.filter { $0.lowercased().hasSuffix("@facebook.com") }
            let hasOnlyFacebookEmails = !facebookEmails.isEmpty && facebookEmails.count == emails.count
            let hasNoPhones = phones.isEmpty
            return hasOnlyFacebookEmails && hasNoPhones
        case .all:
            return true
        case .dubious:
            return true // Already handled above
        }
    }
    
    static func getEmptyMessage(for mode: FilterMode) -> String {
        switch mode {
        case .withEmail:
            return "No contacts with email addresses found."
        case .withoutEmail:
            return "No contacts without email addresses found."
        case .facebookOnly:
            return "No contacts with @facebook.com email addresses found."
        case .facebookExclusive:
            return "No contacts with only @facebook.com email addresses and no phone numbers found."
        case .dubious:
            return "No dubious or incomplete contacts found."
        case .all:
            return "No contacts found."
        }
    }
    
    static func getHeaderMessage(for mode: FilterMode) -> String {
        switch mode {
        case .withEmail:
            return "Contacts with email addresses:"
        case .withoutEmail:
            return "Contacts without email addresses:"
        case .facebookOnly:
            return "Contacts with @facebook.com email addresses:"
        case .facebookExclusive:
            return "Contacts with ONLY @facebook.com email addresses and no phone numbers:"
        case .dubious:
            return "Dubious or incomplete contacts:"
        case .all:
            return "All contacts:"
        }
    }
    
    static func formatLabel(_ label: String?) -> String {
        guard let label = label else { return "" }
        
        // Use the Contacts framework's built-in localization
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
    
    static func printFullContactDetails(_ contact: CNContact) {
        var nameComponents: [String] = []
        if contact.isKeyAvailable(CNContactNamePrefixKey) && !contact.namePrefix.isEmpty {
            nameComponents.append(contact.namePrefix)
        }
        if contact.isKeyAvailable(CNContactGivenNameKey) && !contact.givenName.isEmpty {
            nameComponents.append(contact.givenName)
        }
        if contact.isKeyAvailable(CNContactMiddleNameKey) && !contact.middleName.isEmpty {
            nameComponents.append(contact.middleName)
        }
        if contact.isKeyAvailable(CNContactFamilyNameKey) && !contact.familyName.isEmpty {
            nameComponents.append(contact.familyName)
        }
        if contact.isKeyAvailable(CNContactNameSuffixKey) && !contact.nameSuffix.isEmpty {
            nameComponents.append(contact.nameSuffix)
        }
        
        let fullName = nameComponents.joined(separator: " ")
        print("Full Name: \(fullName.isEmpty ? "No Name" : fullName)")
        
        if contact.isKeyAvailable(CNContactNicknameKey) && !contact.nickname.isEmpty {
            print("Nickname: \(contact.nickname)")
        }
        
        var phoneticComponents: [String] = []
        if contact.isKeyAvailable(CNContactPhoneticGivenNameKey) && !contact.phoneticGivenName.isEmpty {
            phoneticComponents.append(contact.phoneticGivenName)
        }
        if contact.isKeyAvailable(CNContactPhoneticMiddleNameKey) && !contact.phoneticMiddleName.isEmpty {
            phoneticComponents.append(contact.phoneticMiddleName)
        }
        if contact.isKeyAvailable(CNContactPhoneticFamilyNameKey) && !contact.phoneticFamilyName.isEmpty {
            phoneticComponents.append(contact.phoneticFamilyName)
        }
        if !phoneticComponents.isEmpty {
            print("Phonetic Name: \(phoneticComponents.joined(separator: " "))")
        }
        
        if contact.isKeyAvailable(CNContactOrganizationNameKey) && !contact.organizationName.isEmpty {
            print("Organization: \(contact.organizationName)")
        }
        
        if contact.isKeyAvailable(CNContactDepartmentNameKey) && !contact.departmentName.isEmpty {
            print("Department: \(contact.departmentName)")
        }
        
        if contact.isKeyAvailable(CNContactJobTitleKey) && !contact.jobTitle.isEmpty {
            print("Job Title: \(contact.jobTitle)")
        }
        
        if contact.isKeyAvailable(CNContactEmailAddressesKey) && !contact.emailAddresses.isEmpty {
            print("Email Addresses:")
            for email in contact.emailAddresses {
                let label = Self.formatLabel(email.label)
                print("  \(label.isEmpty ? "Email" : label): \(email.value)")
            }
        }
        
        if contact.isKeyAvailable(CNContactPhoneNumbersKey) && !contact.phoneNumbers.isEmpty {
            print("Phone Numbers:")
            for phone in contact.phoneNumbers {
                let label = Self.formatLabel(phone.label)
                print("  \(label.isEmpty ? "Phone" : label): \(phone.value.stringValue)")
            }
        }
        
        if contact.isKeyAvailable(CNContactPostalAddressesKey) && !contact.postalAddresses.isEmpty {
            print("Postal Addresses:")
            for address in contact.postalAddresses {
                let label = Self.formatLabel(address.label)
                print("  \(label.isEmpty ? "Address" : label):")
                let value = address.value
                if !value.street.isEmpty { print("    Street: \(value.street)") }
                if !value.city.isEmpty { print("    City: \(value.city)") }
                if !value.state.isEmpty { print("    State: \(value.state)") }
                if !value.postalCode.isEmpty { print("    Postal Code: \(value.postalCode)") }
                if !value.country.isEmpty { print("    Country: \(value.country)") }
            }
        }
        
        if contact.isKeyAvailable(CNContactUrlAddressesKey) && !contact.urlAddresses.isEmpty {
            print("URLs:")
            for url in contact.urlAddresses {
                let label = Self.formatLabel(url.label)
                print("  \(label.isEmpty ? "URL" : label): \(url.value)")
            }
        }
        
        if contact.isKeyAvailable(CNContactSocialProfilesKey) && !contact.socialProfiles.isEmpty {
            print("Social Profiles:")
            for profile in contact.socialProfiles {
                let value = profile.value
                let label = Self.formatLabel(profile.label)
                print("  \(label.isEmpty ? value.service : label): \(value.service) - \(value.username)")
            }
        }
        
        if contact.isKeyAvailable(CNContactInstantMessageAddressesKey) && !contact.instantMessageAddresses.isEmpty {
            print("Instant Message:")
            for im in contact.instantMessageAddresses {
                let value = im.value
                let label = Self.formatLabel(im.label)
                print("  \(label.isEmpty ? value.service : label): \(value.service) - \(value.username)")
            }
        }
        
        if contact.isKeyAvailable(CNContactBirthdayKey), let birthday = contact.birthday {
            print("Birthday: \(birthday.month ?? 0)/\(birthday.day ?? 0)/\(birthday.year ?? 0)")
        }
        
        if contact.isKeyAvailable(CNContactDatesKey) && !contact.dates.isEmpty {
            print("Important Dates:")
            for date in contact.dates {
                let dateComponents = date.value as DateComponents
                let label = Self.formatLabel(date.label)
                print("  \(label.isEmpty ? "Date" : label): \(dateComponents.month ?? 0)/\(dateComponents.day ?? 0)/\(dateComponents.year ?? 0)")
            }
        }
        
        if contact.isKeyAvailable(CNContactTypeKey) && contact.contactType == .organization {
            print("Contact Type: Organization")
        } else {
            print("Contact Type: Person")
        }
        
        if contact.isKeyAvailable(CNContactImageDataAvailableKey) && contact.imageDataAvailable {
            print("Has Profile Image: Yes")
        }
        
        if contact.isKeyAvailable(CNContactNoteKey) && !contact.note.isEmpty {
            print("Notes: \(contact.note)")
        }
    }
    
    static func exportWithFolderImages(rawContacts: [CNContact], baseFilename: String) throws -> ([SerializableContact], String?) {
        // Create folder name by adding "-images" to the base filename (without extension)
        let baseURL = URL(fileURLWithPath: baseFilename)
        let baseName = baseURL.deletingPathExtension().lastPathComponent
        let folderName = "\(baseName)-images"
        let folderURL = baseURL.deletingLastPathComponent().appendingPathComponent(folderName)
        
        var hasAnyImages = false
        var modifiedContacts: [SerializableContact] = []
        
        // Check if any contacts have images
        for contact in rawContacts {
            if contact.imageDataAvailable {
                hasAnyImages = true
                break
            }
        }
        
        // Only create folder if there are images to save
        if hasAnyImages {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Process each contact
        for contact in rawContacts {
            let manager = ContactsManager()
            var serializableContact = manager.convertToSerializable(contact, includeImages: false)
            
            if contact.imageDataAvailable {
                var imageFilename: String? = nil
                var thumbnailFilename: String? = nil
                
                // Save full-size image if available
                if let imageData = contact.imageData {
                    let fullName = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                    let displayName = fullName.isEmpty ? "No Name" : fullName
                    let safeName = Self.sanitizeFilename(displayName)
                    imageFilename = "\(safeName)-image.jpg"
                    let imageFileURL = folderURL.appendingPathComponent(imageFilename!)
                    try imageData.write(to: imageFileURL)
                }
                
                // Save thumbnail image if available
                if let thumbnailData = contact.thumbnailImageData {
                    let fullName = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                    let displayName = fullName.isEmpty ? "No Name" : fullName
                    let safeName = Self.sanitizeFilename(displayName)
                    thumbnailFilename = "\(safeName)-thumbnail.jpg"
                    let thumbnailFileURL = folderURL.appendingPathComponent(thumbnailFilename!)
                    try thumbnailData.write(to: thumbnailFileURL)
                }
                
                // Update the serializable contact with file references instead of base64 data
                serializableContact = SerializableContact(
                    name: serializableContact.name,
                    namePrefix: serializableContact.namePrefix,
                    givenName: serializableContact.givenName,
                    middleName: serializableContact.middleName,
                    familyName: serializableContact.familyName,
                    nameSuffix: serializableContact.nameSuffix,
                    nickname: serializableContact.nickname,
                    phoneticGivenName: serializableContact.phoneticGivenName,
                    phoneticMiddleName: serializableContact.phoneticMiddleName,
                    phoneticFamilyName: serializableContact.phoneticFamilyName,
                    organizationName: serializableContact.organizationName,
                    departmentName: serializableContact.departmentName,
                    jobTitle: serializableContact.jobTitle,
                    emails: serializableContact.emails,
                    phones: serializableContact.phones,
                    postalAddresses: serializableContact.postalAddresses,
                    urls: serializableContact.urls,
                    socialProfiles: serializableContact.socialProfiles,
                    instantMessageAddresses: serializableContact.instantMessageAddresses,
                    birthday: serializableContact.birthday,
                    dates: serializableContact.dates,
                    contactType: serializableContact.contactType,
                    hasImage: serializableContact.hasImage,
                    imageData: imageFilename != nil ? "\(folderName)/\(imageFilename!)" : nil,
                    thumbnailImageData: thumbnailFilename != nil ? "\(folderName)/\(thumbnailFilename!)" : nil,
                    note: serializableContact.note
                )
            }
            
            modifiedContacts.append(serializableContact)
        }
        
        return (modifiedContacts, hasAnyImages ? folderName : nil)
    }
    
    static func sanitizeFilename(_ name: String) -> String {
        // Replace invalid filename characters with underscores
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalidChars).joined(separator: "_")
    }
    
    static func exportAsJSON(contacts: [SerializableContact], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(contacts)
        try data.write(to: url)
    }
    
    static func exportAsXML(contacts: [SerializableContact], to url: URL) throws {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<contacts>\n"
        
        for contact in contacts {
            xml += "  <contact>\n"
            xml += "    <name>\(Self.escapeXML(contact.name))</name>\n"
            
            if let value = contact.namePrefix { xml += "    <namePrefix>\(Self.escapeXML(value))</namePrefix>\n" }
            if let value = contact.givenName { xml += "    <givenName>\(Self.escapeXML(value))</givenName>\n" }
            if let value = contact.middleName { xml += "    <middleName>\(Self.escapeXML(value))</middleName>\n" }
            if let value = contact.familyName { xml += "    <familyName>\(Self.escapeXML(value))</familyName>\n" }
            if let value = contact.nameSuffix { xml += "    <nameSuffix>\(Self.escapeXML(value))</nameSuffix>\n" }
            if let value = contact.nickname { xml += "    <nickname>\(Self.escapeXML(value))</nickname>\n" }
            if let value = contact.phoneticGivenName { xml += "    <phoneticGivenName>\(Self.escapeXML(value))</phoneticGivenName>\n" }
            if let value = contact.phoneticMiddleName { xml += "    <phoneticMiddleName>\(Self.escapeXML(value))</phoneticMiddleName>\n" }
            if let value = contact.phoneticFamilyName { xml += "    <phoneticFamilyName>\(Self.escapeXML(value))</phoneticFamilyName>\n" }
            if let value = contact.organizationName { xml += "    <organizationName>\(Self.escapeXML(value))</organizationName>\n" }
            if let value = contact.departmentName { xml += "    <departmentName>\(Self.escapeXML(value))</departmentName>\n" }
            if let value = contact.jobTitle { xml += "    <jobTitle>\(Self.escapeXML(value))</jobTitle>\n" }
            
            if !contact.emails.isEmpty {
                xml += "    <emails>\n"
                for email in contact.emails {
                    xml += "      <email"
                    if let label = email.label { xml += " label=\"\(Self.escapeXML(label))\"" }
                    xml += ">\(Self.escapeXML(email.value))</email>\n"
                }
                xml += "    </emails>\n"
            }
            
            if !contact.phones.isEmpty {
                xml += "    <phones>\n"
                for phone in contact.phones {
                    xml += "      <phone"
                    if let label = phone.label { xml += " label=\"\(Self.escapeXML(label))\"" }
                    xml += ">\(Self.escapeXML(phone.value))</phone>\n"
                }
                xml += "    </phones>\n"
            }
            
            if !contact.postalAddresses.isEmpty {
                xml += "    <postalAddresses>\n"
                for address in contact.postalAddresses {
                    xml += "      <address"
                    if let label = address.label { xml += " label=\"\(Self.escapeXML(label))\"" }
                    xml += ">\n"
                    if let street = address.street { xml += "        <street>\(Self.escapeXML(street))</street>\n" }
                    if let city = address.city { xml += "        <city>\(Self.escapeXML(city))</city>\n" }
                    if let state = address.state { xml += "        <state>\(Self.escapeXML(state))</state>\n" }
                    if let postalCode = address.postalCode { xml += "        <postalCode>\(Self.escapeXML(postalCode))</postalCode>\n" }
                    if let country = address.country { xml += "        <country>\(Self.escapeXML(country))</country>\n" }
                    xml += "      </address>\n"
                }
                xml += "    </postalAddresses>\n"
            }
            
            if !contact.urls.isEmpty {
                xml += "    <urls>\n"
                for url in contact.urls {
                    xml += "      <url"
                    if let label = url.label { xml += " label=\"\(Self.escapeXML(label))\"" }
                    xml += ">\(Self.escapeXML(url.value))</url>\n"
                }
                xml += "    </urls>\n"
            }
            
            if !contact.socialProfiles.isEmpty {
                xml += "    <socialProfiles>\n"
                for profile in contact.socialProfiles {
                    xml += "      <profile"
                    if let label = profile.label { xml += " label=\"\(Self.escapeXML(label))\"" }
                    xml += " service=\"\(Self.escapeXML(profile.service))\">\(Self.escapeXML(profile.username))</profile>\n"
                }
                xml += "    </socialProfiles>\n"
            }
            
            if !contact.instantMessageAddresses.isEmpty {
                xml += "    <instantMessages>\n"
                for im in contact.instantMessageAddresses {
                    xml += "      <im"
                    if let label = im.label { xml += " label=\"\(Self.escapeXML(label))\"" }
                    xml += " service=\"\(Self.escapeXML(im.service))\">\(Self.escapeXML(im.username))</im>\n"
                }
                xml += "    </instantMessages>\n"
            }
            
            if let birthday = contact.birthday {
                xml += "    <birthday"
                if let day = birthday.day { xml += " day=\"\(day)\"" }
                if let month = birthday.month { xml += " month=\"\(month)\"" }
                if let year = birthday.year { xml += " year=\"\(year)\"" }
                xml += "/>\n"
            }
            
            if !contact.dates.isEmpty {
                xml += "    <importantDates>\n"
                for date in contact.dates {
                    xml += "      <date"
                    if let label = date.label { xml += " label=\"\(Self.escapeXML(label))\"" }
                    if let day = date.date.day { xml += " day=\"\(day)\"" }
                    if let month = date.date.month { xml += " month=\"\(month)\"" }
                    if let year = date.date.year { xml += " year=\"\(year)\"" }
                    xml += "/>\n"
                }
                xml += "    </importantDates>\n"
            }
            
            xml += "    <contactType>\(Self.escapeXML(contact.contactType))</contactType>\n"
            xml += "    <hasImage>\(contact.hasImage)</hasImage>\n"
            
            if let imageData = contact.imageData {
                xml += "    <imageData>\(imageData)</imageData>\n"
            }
            
            if let thumbnailImageData = contact.thumbnailImageData {
                xml += "    <thumbnailImageData>\(thumbnailImageData)</thumbnailImageData>\n"
            }
            
            if let note = contact.note {
                xml += "    <note>\(Self.escapeXML(note))</note>\n"
            }
            
            xml += "  </contact>\n"
        }
        
        xml += "</contacts>\n"
        
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }
    
    static func escapeXML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}