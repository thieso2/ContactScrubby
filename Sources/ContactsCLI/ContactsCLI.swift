import Foundation
import Contacts

@main
struct ContactsCLI {
    static func main() async {
        let manager = ContactsManager()
        let args = CommandLine.arguments
        
        var filterMode: ContactsManager.FilterMode = .withEmail
        var dumpAllFields = false
        var backupMode = false
        var backupFilename: String?
        var dubiousMinScore = 3
        var addToGroup: String?
        var imageMode: ImageMode = .none
        
        // Parse arguments
        var argIndex = 1
        while argIndex < args.count {
            let arg = args[argIndex]
            
            if arg.hasPrefix("--add_to_group=") {
                let groupName = String(arg.dropFirst("--add_to_group=".count))
                if groupName.isEmpty {
                    print("Error: --add_to_group requires a group name")
                    exit(1)
                }
                addToGroup = groupName
                argIndex += 1
                continue
            }
            
            if arg.hasPrefix("--include-images=") {
                let modeString = String(arg.dropFirst("--include-images=".count))
                switch modeString.lowercased() {
                case "inline":
                    imageMode = .inline
                case "folder":
                    imageMode = .folder
                default:
                    print("Error: --include-images mode must be 'inline' or 'folder', got '\(modeString)'")
                    exit(1)
                }
                argIndex += 1
                continue
            }
            
            switch arg {
            case "--no-email":
                filterMode = .withoutEmail
            case "--facebook":
                filterMode = .facebookOnly
            case "--facebook-exclusive":
                filterMode = .facebookExclusive
            case "--dubious":
                filterMode = .dubious
                // Check if there's an optional score parameter
                if argIndex + 1 < args.count && !args[argIndex + 1].hasPrefix("--") {
                    if let score = Int(args[argIndex + 1]), score >= 0 {
                        dubiousMinScore = score
                        argIndex += 1  // Skip the score argument
                    } else {
                        print("Error: Invalid dubious score '\\(args[argIndex + 1])'. Must be a non-negative integer.")
                        exit(1)
                    }
                }
            case "--all":
                filterMode = .all
            case "--dump":
                dumpAllFields = true
            case "--include-images":
                imageMode = .inline
            case "--backup":
                backupMode = true
                if argIndex + 1 < args.count && !args[argIndex + 1].hasPrefix("--") {
                    backupFilename = args[argIndex + 1]
                    argIndex += 1  // Skip the filename argument
                } else {
                    print("Error: --backup requires a filename")
                    printHelp()
                    exit(1)
                }
            case "--help", "-h":
                printHelp()
                exit(0)
            default:
                print("Unknown option: \(arg)")
                printHelp()
                exit(1)
            }
            
            argIndex += 1
        }
        
        do {
            let granted = try await manager.requestAccess()
            
            if !granted {
                print("Access to contacts was denied. Please grant permission in System Preferences.")
                exit(1)
            }
            
            // Handle group addition if requested
            if let groupName = addToGroup {
                let contacts: [CNContact]
                
                if filterMode == .dubious {
                    let analyses = try manager.getDubiousContacts(minimumScore: dubiousMinScore)
                    contacts = analyses.map { $0.contact }
                } else {
                    contacts = try manager.listContactsWithAllFields().filter { contact in
                        let emails = contact.emailAddresses.map { $0.value as String }
                        let phones = contact.phoneNumbers.map { $0.value.stringValue }
                        
                        switch filterMode {
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
                }
                
                if contacts.isEmpty {
                    print("No contacts found matching the specified criteria.")
                    exit(0)
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
                
                print("\\nGroup operation completed.")
                exit(0)
            }
            
            if backupMode, let filename = backupFilename {
                let contacts = try manager.getContactsForExport(filterMode: filterMode, dubiousMinScore: dubiousMinScore, imageMode: imageMode)
                
                if contacts.isEmpty {
                    print(getEmptyMessage(for: filterMode))
                    exit(0)
                }
                
                let fileURL = URL(fileURLWithPath: filename)
                let fileExtension = fileURL.pathExtension.lowercased()
                
                switch fileExtension {
                case "json":
                    if imageMode == .folder {
                        let (exportedContacts, imageFolder) = try exportWithFolderImages(contacts: contacts, baseFilename: filename)
                        try exportAsJSON(contacts: exportedContacts, to: fileURL)
                        print("Successfully exported \(contacts.count) contact(s) to \(filename)")
                        if let folder = imageFolder {
                            print("Images saved to folder: \(folder)")
                        }
                    } else {
                        try exportAsJSON(contacts: contacts, to: fileURL)
                        print("Successfully exported \(contacts.count) contact(s) to \(filename)")
                    }
                case "xml":
                    if imageMode == .folder {
                        let (exportedContacts, imageFolder) = try exportWithFolderImages(contacts: contacts, baseFilename: filename)
                        try exportAsXML(contacts: exportedContacts, to: fileURL)
                        print("Successfully exported \(contacts.count) contact(s) to \(filename)")
                        if let folder = imageFolder {
                            print("Images saved to folder: \(folder)")
                        }
                    } else {
                        try exportAsXML(contacts: contacts, to: fileURL)
                        print("Successfully exported \(contacts.count) contact(s) to \(filename)")
                    }
                default:
                    print("Error: Unsupported file format. Please use .json or .xml extension")
                    exit(1)
                }
                
            } else if dumpAllFields {
                let fullContacts = try manager.listContactsWithAllFields()
                
                if fullContacts.isEmpty {
                    print("No contacts found.")
                } else {
                    print("All contacts with full details:\n")
                    
                    for contact in fullContacts {
                        printFullContactDetails(contact)
                        print(String(repeating: "-", count: 50))
                        print()
                    }
                    
                    print("Total: \(fullContacts.count) contact(s)")
                }
            } else if filterMode == .dubious {
                // Special handling for dubious contacts to show analysis
                let dubiousAnalyses = try manager.getDubiousContacts(minimumScore: dubiousMinScore)
                
                if dubiousAnalyses.isEmpty {
                    print(getEmptyMessage(for: filterMode))
                } else {
                    var headerMessage = getHeaderMessage(for: filterMode)
                    if dubiousMinScore != 3 {
                        headerMessage += " (minimum score: \(dubiousMinScore))"
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
                let contacts = try manager.listAllContacts(filterMode: filterMode, dubiousMinScore: dubiousMinScore)
                
                if contacts.isEmpty {
                    print(getEmptyMessage(for: filterMode))
                } else {
                    print(getHeaderMessage(for: filterMode) + "\n")
                    
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
            
        } catch {
            print("Error: \(error.localizedDescription)")
            exit(1)
        }
    }
    
    static func printHelp() {
        print("""
        Usage: ContactsCLI [option]
        
        Options:
          --no-email           List contacts that have no email addresses
          --facebook           List only contacts with @facebook.com email addresses
          --facebook-exclusive List contacts with ONLY @facebook.com emails and no phones
          --dubious [score]    List dubious/incomplete contacts (likely auto-imports)
                              Optional score: minimum dubiousness score (default: 3)
          --all                List all contacts
          --dump               Dump all available contact fields
          --backup <filename>  Export contacts to JSON or XML file
                              Can be followed by filter options (e.g., --backup file.json --facebook)
          --include-images[=mode] Include contact images in export (use with --backup)
                              Modes: inline (default), folder
          --add_to_group="name" Add filtered contacts to specified group (creates group if needed)
          --help, -h           Show this help message
          
        Default: Lists contacts with email addresses
        
        Examples:
          ContactsCLI --backup contacts.json
          ContactsCLI --backup contacts.xml --facebook
          ContactsCLI --backup backup.json --no-email
          ContactsCLI --dubious
          ContactsCLI --dubious 5
          ContactsCLI --backup suspicious.json --dubious 1
          ContactsCLI --add_to_group="Cleanup Needed" --dubious
          ContactsCLI --add_to_group="Facebook Contacts" --facebook
          ContactsCLI --add_to_group="No Phone Numbers" --no-email
          ContactsCLI --backup contacts-with-images.json --include-images
          ContactsCLI --backup facebook-with-images.xml --facebook --include-images=inline
          ContactsCLI --backup contacts.json --include-images=folder --dubious
        """)
    }
    
    static func getEmptyMessage(for mode: ContactsManager.FilterMode) -> String {
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
    
    static func getHeaderMessage(for mode: ContactsManager.FilterMode) -> String {
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
                let label = formatLabel(email.label)
                print("  \(label.isEmpty ? "Email" : label): \(email.value)")
            }
        }
        
        if contact.isKeyAvailable(CNContactPhoneNumbersKey) && !contact.phoneNumbers.isEmpty {
            print("Phone Numbers:")
            for phone in contact.phoneNumbers {
                let label = formatLabel(phone.label)
                print("  \(label.isEmpty ? "Phone" : label): \(phone.value.stringValue)")
            }
        }
        
        if contact.isKeyAvailable(CNContactPostalAddressesKey) && !contact.postalAddresses.isEmpty {
            print("Postal Addresses:")
            for address in contact.postalAddresses {
                let label = formatLabel(address.label)
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
                let label = formatLabel(url.label)
                print("  \(label.isEmpty ? "URL" : label): \(url.value)")
            }
        }
        
        if contact.isKeyAvailable(CNContactSocialProfilesKey) && !contact.socialProfiles.isEmpty {
            print("Social Profiles:")
            for profile in contact.socialProfiles {
                let value = profile.value
                let label = formatLabel(profile.label)
                print("  \(label.isEmpty ? value.service : label): \(value.service) - \(value.username)")
            }
        }
        
        if contact.isKeyAvailable(CNContactInstantMessageAddressesKey) && !contact.instantMessageAddresses.isEmpty {
            print("Instant Message:")
            for im in contact.instantMessageAddresses {
                let value = im.value
                let label = formatLabel(im.label)
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
                let label = formatLabel(date.label)
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
    
    static func exportWithFolderImages(contacts: [SerializableContact], baseFilename: String) throws -> ([SerializableContact], String?) {
        // Create folder name by adding "-images" to the base filename (without extension)
        let baseURL = URL(fileURLWithPath: baseFilename)
        let baseName = baseURL.deletingPathExtension().lastPathComponent
        let folderName = "\(baseName)-images"
        let folderURL = baseURL.deletingLastPathComponent().appendingPathComponent(folderName)
        
        var hasAnyImages = false
        var modifiedContacts: [SerializableContact] = []
        
        // Check if any contacts have images
        for contact in contacts {
            if contact.hasImage && (contact.imageData != nil || contact.thumbnailImageData != nil) {
                hasAnyImages = true
                break
            }
        }
        
        // Only create folder if there are images to save
        if hasAnyImages {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Process each contact
        for contact in contacts {
            var modifiedContact = contact
            
            if contact.hasImage {
                var imageFilename: String? = nil
                var thumbnailFilename: String? = nil
                
                // Save full-size image if available
                if let imageDataString = contact.imageData,
                   let imageData = Data(base64Encoded: imageDataString) {
                    let safeName = sanitizeFilename(contact.name)
                    imageFilename = "\(safeName)-image.jpg"
                    let imageFileURL = folderURL.appendingPathComponent(imageFilename!)
                    try imageData.write(to: imageFileURL)
                }
                
                // Save thumbnail image if available
                if let thumbnailDataString = contact.thumbnailImageData,
                   let thumbnailData = Data(base64Encoded: thumbnailDataString) {
                    let safeName = sanitizeFilename(contact.name)
                    thumbnailFilename = "\(safeName)-thumbnail.jpg"
                    let thumbnailFileURL = folderURL.appendingPathComponent(thumbnailFilename!)
                    try thumbnailData.write(to: thumbnailFileURL)
                }
                
                // Create modified contact with file references instead of base64 data
                modifiedContact = SerializableContact(
                    name: contact.name,
                    namePrefix: contact.namePrefix,
                    givenName: contact.givenName,
                    middleName: contact.middleName,
                    familyName: contact.familyName,
                    nameSuffix: contact.nameSuffix,
                    nickname: contact.nickname,
                    phoneticGivenName: contact.phoneticGivenName,
                    phoneticMiddleName: contact.phoneticMiddleName,
                    phoneticFamilyName: contact.phoneticFamilyName,
                    organizationName: contact.organizationName,
                    departmentName: contact.departmentName,
                    jobTitle: contact.jobTitle,
                    emails: contact.emails,
                    phones: contact.phones,
                    postalAddresses: contact.postalAddresses,
                    urls: contact.urls,
                    socialProfiles: contact.socialProfiles,
                    instantMessageAddresses: contact.instantMessageAddresses,
                    birthday: contact.birthday,
                    dates: contact.dates,
                    contactType: contact.contactType,
                    hasImage: contact.hasImage,
                    imageData: imageFilename != nil ? "\(folderName)/\(imageFilename!)" : nil,
                    thumbnailImageData: thumbnailFilename != nil ? "\(folderName)/\(thumbnailFilename!)" : nil,
                    note: contact.note
                )
            }
            
            modifiedContacts.append(modifiedContact)
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
            xml += "    <name>\(escapeXML(contact.name))</name>\n"
            
            if let value = contact.namePrefix { xml += "    <namePrefix>\(escapeXML(value))</namePrefix>\n" }
            if let value = contact.givenName { xml += "    <givenName>\(escapeXML(value))</givenName>\n" }
            if let value = contact.middleName { xml += "    <middleName>\(escapeXML(value))</middleName>\n" }
            if let value = contact.familyName { xml += "    <familyName>\(escapeXML(value))</familyName>\n" }
            if let value = contact.nameSuffix { xml += "    <nameSuffix>\(escapeXML(value))</nameSuffix>\n" }
            if let value = contact.nickname { xml += "    <nickname>\(escapeXML(value))</nickname>\n" }
            if let value = contact.phoneticGivenName { xml += "    <phoneticGivenName>\(escapeXML(value))</phoneticGivenName>\n" }
            if let value = contact.phoneticMiddleName { xml += "    <phoneticMiddleName>\(escapeXML(value))</phoneticMiddleName>\n" }
            if let value = contact.phoneticFamilyName { xml += "    <phoneticFamilyName>\(escapeXML(value))</phoneticFamilyName>\n" }
            if let value = contact.organizationName { xml += "    <organizationName>\(escapeXML(value))</organizationName>\n" }
            if let value = contact.departmentName { xml += "    <departmentName>\(escapeXML(value))</departmentName>\n" }
            if let value = contact.jobTitle { xml += "    <jobTitle>\(escapeXML(value))</jobTitle>\n" }
            
            if !contact.emails.isEmpty {
                xml += "    <emails>\n"
                for email in contact.emails {
                    xml += "      <email"
                    if let label = email.label { xml += " label=\"\(escapeXML(label))\"" }
                    xml += ">\(escapeXML(email.value))</email>\n"
                }
                xml += "    </emails>\n"
            }
            
            if !contact.phones.isEmpty {
                xml += "    <phones>\n"
                for phone in contact.phones {
                    xml += "      <phone"
                    if let label = phone.label { xml += " label=\"\(escapeXML(label))\"" }
                    xml += ">\(escapeXML(phone.value))</phone>\n"
                }
                xml += "    </phones>\n"
            }
            
            if !contact.postalAddresses.isEmpty {
                xml += "    <postalAddresses>\n"
                for address in contact.postalAddresses {
                    xml += "      <address"
                    if let label = address.label { xml += " label=\"\(escapeXML(label))\"" }
                    xml += ">\n"
                    if let street = address.street { xml += "        <street>\(escapeXML(street))</street>\n" }
                    if let city = address.city { xml += "        <city>\(escapeXML(city))</city>\n" }
                    if let state = address.state { xml += "        <state>\(escapeXML(state))</state>\n" }
                    if let postalCode = address.postalCode { xml += "        <postalCode>\(escapeXML(postalCode))</postalCode>\n" }
                    if let country = address.country { xml += "        <country>\(escapeXML(country))</country>\n" }
                    xml += "      </address>\n"
                }
                xml += "    </postalAddresses>\n"
            }
            
            if !contact.urls.isEmpty {
                xml += "    <urls>\n"
                for url in contact.urls {
                    xml += "      <url"
                    if let label = url.label { xml += " label=\"\(escapeXML(label))\"" }
                    xml += ">\(escapeXML(url.value))</url>\n"
                }
                xml += "    </urls>\n"
            }
            
            if !contact.socialProfiles.isEmpty {
                xml += "    <socialProfiles>\n"
                for profile in contact.socialProfiles {
                    xml += "      <profile"
                    if let label = profile.label { xml += " label=\"\(escapeXML(label))\"" }
                    xml += " service=\"\(escapeXML(profile.service))\">\(escapeXML(profile.username))</profile>\n"
                }
                xml += "    </socialProfiles>\n"
            }
            
            if !contact.instantMessageAddresses.isEmpty {
                xml += "    <instantMessages>\n"
                for im in contact.instantMessageAddresses {
                    xml += "      <im"
                    if let label = im.label { xml += " label=\"\(escapeXML(label))\"" }
                    xml += " service=\"\(escapeXML(im.service))\">\(escapeXML(im.username))</im>\n"
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
                    if let label = date.label { xml += " label=\"\(escapeXML(label))\"" }
                    if let day = date.date.day { xml += " day=\"\(day)\"" }
                    if let month = date.date.month { xml += " month=\"\(month)\"" }
                    if let year = date.date.year { xml += " year=\"\(year)\"" }
                    xml += "/>\n"
                }
                xml += "    </importantDates>\n"
            }
            
            xml += "    <contactType>\(escapeXML(contact.contactType))</contactType>\n"
            xml += "    <hasImage>\(contact.hasImage)</hasImage>\n"
            
            if let imageData = contact.imageData {
                xml += "    <imageData>\(imageData)</imageData>\n"
            }
            
            if let thumbnailImageData = contact.thumbnailImageData {
                xml += "    <thumbnailImageData>\(thumbnailImageData)</thumbnailImageData>\n"
            }
            
            if let note = contact.note {
                xml += "    <note>\(escapeXML(note))</note>\n"
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
