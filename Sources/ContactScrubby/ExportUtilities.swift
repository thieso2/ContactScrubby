import Foundation
import Contacts

struct ExportUtilities {

    // MARK: - Image Export with Folder

    static func exportWithFolderImages(rawContacts: [CNContact], baseFilename: String) throws
        -> ([SerializableContact], String?) {
        // Create folder name by adding "-images" to the base filename (without extension)
        let baseURL = URL(fileURLWithPath: baseFilename)
        let baseName = baseURL.deletingPathExtension().lastPathComponent
        let folderName = "\(baseName)-images"
        let folderURL = baseURL.deletingLastPathComponent().appendingPathComponent(folderName)

        var hasAnyImages = false
        var modifiedContacts: [SerializableContact] = []

        // Check if any contacts have images
        for contact in rawContacts where contact.imageDataAvailable {
            hasAnyImages = true
            break
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
                var imageFilename: String?
                var thumbnailFilename: String?

                // Save full-size image if available
                if let imageData = contact.imageData {
                    let fullName = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                    let displayName = fullName.isEmpty ? "No Name" : fullName
                    let safeName = sanitizeFilename(displayName)
                    imageFilename = "\(safeName)-image.jpg"
                    let imageFileURL = folderURL.appendingPathComponent(imageFilename!)
                    try imageData.write(to: imageFileURL)
                }

                // Save thumbnail image if available
                if let thumbnailData = contact.thumbnailImageData {
                    let fullName = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                    let displayName = fullName.isEmpty ? "No Name" : fullName
                    let safeName = sanitizeFilename(displayName)
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

    // MARK: - Filename Sanitization

    static func sanitizeFilename(_ name: String) -> String {
        // Handle empty or whitespace-only strings
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "unnamed"
        }
        
        // Replace invalid filename characters with underscores
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return trimmed.components(separatedBy: invalidChars).joined(separator: "_")
    }

    // MARK: - JSON Export

    static func exportAsJSON(contacts: [SerializableContact], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(contacts)
        try data.write(to: url)
    }

    // MARK: - XML Export

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
            if let value = contact.phoneticGivenName {
                xml += "    <phoneticGivenName>\(escapeXML(value))</phoneticGivenName>\n"
            }
            if let value = contact.phoneticMiddleName {
                xml += "    <phoneticMiddleName>\(escapeXML(value))</phoneticMiddleName>\n"
            }
            if let value = contact.phoneticFamilyName {
                xml += "    <phoneticFamilyName>\(escapeXML(value))</phoneticFamilyName>\n"
            }
            if let value = contact.organizationName {
                xml += "    <organizationName>\(escapeXML(value))</organizationName>\n"
            }
            if let value = contact.departmentName {
                xml += "    <departmentName>\(escapeXML(value))</departmentName>\n"
            }
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

    // MARK: - XML Escaping

    static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    // MARK: - VCF Export

    static func exportAsVCF(contacts: [SerializableContact], to url: URL) throws {
        var vcf = ""
        
        for contact in contacts {
            vcf += "BEGIN:VCARD\n"
            vcf += "VERSION:3.0\n"
            
            // Name components
            vcf += "FN:\(escapeVCF(contact.name))\n"
            
            // Structured name: Family;Given;Middle;Prefix;Suffix
            let n = [
                contact.familyName ?? "",
                contact.givenName ?? "",
                contact.middleName ?? "",
                contact.namePrefix ?? "",
                contact.nameSuffix ?? ""
            ].map { escapeVCF($0) }.joined(separator: ";")
            vcf += "N:\(n)\n"
            
            // Nickname
            if let nickname = contact.nickname {
                vcf += "NICKNAME:\(escapeVCF(nickname))\n"
            }
            
            // Organization
            if let org = contact.organizationName {
                var orgLine = escapeVCF(org)
                if let dept = contact.departmentName {
                    orgLine += ";\(escapeVCF(dept))"
                }
                vcf += "ORG:\(orgLine)\n"
            }
            
            // Job title
            if let title = contact.jobTitle {
                vcf += "TITLE:\(escapeVCF(title))\n"
            }
            
            // Emails
            for email in contact.emails {
                var emailLine = "EMAIL"
                if let label = email.label {
                    emailLine += ";TYPE=\(vcfLabelType(label))"
                }
                emailLine += ":\(escapeVCF(email.value))"
                vcf += "\(emailLine)\n"
            }
            
            // Phone numbers
            for phone in contact.phones {
                var phoneLine = "TEL"
                if let label = phone.label {
                    phoneLine += ";TYPE=\(vcfLabelType(label))"
                }
                phoneLine += ":\(escapeVCF(phone.value))"
                vcf += "\(phoneLine)\n"
            }
            
            // Addresses
            for address in contact.postalAddresses {
                var adrLine = "ADR"
                if let label = address.label {
                    adrLine += ";TYPE=\(vcfLabelType(label))"
                }
                // ADR format: PO Box;Extended;Street;City;State;PostalCode;Country
                let adr = [
                    "", // PO Box
                    "", // Extended address
                    address.street ?? "",
                    address.city ?? "",
                    address.state ?? "",
                    address.postalCode ?? "",
                    address.country ?? ""
                ].map { escapeVCF($0) }.joined(separator: ";")
                adrLine += ":\(adr)"
                vcf += "\(adrLine)\n"
            }
            
            // URLs
            for url in contact.urls {
                var urlLine = "URL"
                if let label = url.label {
                    urlLine += ";TYPE=\(vcfLabelType(label))"
                }
                urlLine += ":\(escapeVCF(url.value))"
                vcf += "\(urlLine)\n"
            }
            
            // Social profiles (as X-SOCIALPROFILE)
            for profile in contact.socialProfiles {
                var socialLine = "X-SOCIALPROFILE"
                if let label = profile.label {
                    socialLine += ";TYPE=\(vcfLabelType(label))"
                }
                socialLine += ";x-service=\(escapeVCF(profile.service))"
                socialLine += ":\(escapeVCF(profile.username))"
                vcf += "\(socialLine)\n"
            }
            
            // Instant messaging (as IMPP)
            for im in contact.instantMessageAddresses {
                var imLine = "IMPP"
                if let label = im.label {
                    imLine += ";TYPE=\(vcfLabelType(label))"
                }
                imLine += ":\(escapeVCF(im.service)):\(escapeVCF(im.username))"
                vcf += "\(imLine)\n"
            }
            
            // Birthday
            if let birthday = contact.birthday {
                let bday = formatVCFDate(birthday)
                vcf += "BDAY:\(bday)\n"
            }
            
            // Other dates (as X-ABDATE with label)
            for date in contact.dates {
                var dateLine = "X-ABDATE"
                if let label = date.label {
                    dateLine += ";LABEL=\(escapeVCF(label))"
                }
                dateLine += ":\(formatVCFDate(date.date))"
                vcf += "\(dateLine)\n"
            }
            
            // Note
            if let note = contact.note {
                vcf += "NOTE:\(escapeVCF(note))\n"
            }
            
            // Photo (if base64 data is available)
            if let imageData = contact.imageData, !imageData.contains("/") {
                // Only include if it's base64 data, not a file path
                vcf += "PHOTO;ENCODING=BASE64;TYPE=JPEG:\(imageData)\n"
            }
            
            vcf += "END:VCARD\n\n"
        }
        
        try vcf.write(to: url, atomically: true, encoding: .utf8)
    }
    
    // MARK: - VCF Helpers
    
    static func escapeVCF(_ string: String) -> String {
        // VCF requires escaping backslashes, commas, semicolons, and newlines
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
    
    static func vcfLabelType(_ label: String) -> String {
        // Convert common labels to VCF types
        let lowercased = label.lowercased()
        switch lowercased {
        case "home": return "HOME"
        case "work": return "WORK"
        case "mobile", "cell": return "CELL"
        case "main": return "MAIN"
        case "home fax", "homefax": return "HOME,FAX"
        case "work fax", "workfax": return "WORK,FAX"
        case "pager": return "PAGER"
        case "other": return "OTHER"
        default: return label.uppercased().replacingOccurrences(of: " ", with: "-")
        }
    }
    
    static func formatVCFDate(_ date: SerializableContact.DateInfo) -> String {
        // Format date as YYYY-MM-DD or partial date
        var components: [String] = []
        
        if let year = date.year {
            components.append(String(format: "%04d", year))
        } else {
            components.append("--")
        }
        
        if let month = date.month {
            components.append(String(format: "%02d", month))
        } else {
            components.append("-")
        }
        
        if let day = date.day {
            components.append(String(format: "%02d", day))
        } else {
            components.append("-")
        }
        
        return components.joined(separator: "-")
    }
}
