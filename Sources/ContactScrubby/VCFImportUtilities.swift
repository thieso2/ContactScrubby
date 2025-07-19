import Foundation
import Contacts

struct VCFImportUtilities {
    
    // MARK: - VCF Import
    
    static func importFromVCF(at url: URL) throws -> [SerializableContact] {
        let content = try String(contentsOf: url, encoding: .utf8)
        return parseVCF(content)
    }
    
    static func parseVCF(_ content: String) -> [SerializableContact] {
        var contacts: [SerializableContact] = []
        var currentVCard: VCardData?
        
        let lines = content.components(separatedBy: .newlines)
        var i = 0
        
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            
            // Handle line continuations (lines starting with space or tab)
            var fullLine = line
            while i + 1 < lines.count && (lines[i + 1].hasPrefix(" ") || lines[i + 1].hasPrefix("\t")) {
                i += 1
                fullLine += lines[i].trimmingCharacters(in: .whitespaces)
            }
            
            if fullLine.uppercased() == "BEGIN:VCARD" {
                currentVCard = VCardData()
            } else if fullLine.uppercased() == "END:VCARD" {
                if let vcard = currentVCard {
                    if let contact = vcard.toSerializableContact() {
                        contacts.append(contact)
                    }
                }
                currentVCard = nil
            } else if let vcard = currentVCard {
                parseVCardLine(fullLine, into: vcard)
            }
            
            i += 1
        }
        
        return contacts
    }
    
    // MARK: - VCard Data Model
    
    class VCardData {
        var version: String?
        var formattedName: String?
        var nameComponents: NameComponents?
        var nickname: String?
        var organization: [String] = []
        var title: String?
        var emails: [LabeledValue] = []
        var phones: [LabeledValue] = []
        var addresses: [LabeledAddress] = []
        var urls: [LabeledValue] = []
        var socialProfiles: [SocialProfile] = []
        var instantMessages: [InstantMessage] = []
        var birthday: DateComponents?
        var dates: [LabeledDate] = []
        var note: String?
        var photo: String?
        
        struct NameComponents {
            var family: String?
            var given: String?
            var middle: String?
            var prefix: String?
            var suffix: String?
        }
        
        struct LabeledValue {
            let label: String?
            let value: String
        }
        
        struct LabeledAddress {
            let label: String?
            let poBox: String?
            let extended: String?
            let street: String?
            let city: String?
            let state: String?
            let postalCode: String?
            let country: String?
        }
        
        struct SocialProfile {
            let label: String?
            let service: String
            let username: String
        }
        
        struct InstantMessage {
            let label: String?
            let service: String
            let username: String
        }
        
        struct LabeledDate {
            let label: String?
            let date: DateComponents
        }
        
        func toSerializableContact() -> SerializableContact? {
            // Use formatted name or construct from components
            let name = formattedName ?? {
                let components = [
                    nameComponents?.prefix,
                    nameComponents?.given,
                    nameComponents?.middle,
                    nameComponents?.family,
                    nameComponents?.suffix
                ].compactMap { $0 }.filter { !$0.isEmpty }
                return components.isEmpty ? "No Name" : components.joined(separator: " ")
            }()
            
            // Convert internal structures to SerializableContact structures
            let serializableEmails = emails.map {
                SerializableContact.LabeledValue(label: $0.label, value: $0.value)
            }
            
            let serializablePhones = phones.map {
                SerializableContact.LabeledValue(label: $0.label, value: $0.value)
            }
            
            let serializableAddresses = addresses.map {
                SerializableContact.LabeledAddress(
                    label: $0.label,
                    street: $0.street,
                    city: $0.city,
                    state: $0.state,
                    postalCode: $0.postalCode,
                    country: $0.country
                )
            }
            
            let serializableUrls = urls.map {
                SerializableContact.LabeledValue(label: $0.label, value: $0.value)
            }
            
            let serializableSocialProfiles = socialProfiles.map {
                SerializableContact.SocialProfile(
                    label: $0.label,
                    service: $0.service,
                    username: $0.username
                )
            }
            
            let serializableIMs = instantMessages.map {
                SerializableContact.InstantMessage(
                    label: $0.label,
                    service: $0.service,
                    username: $0.username
                )
            }
            
            let serializableBirthday: SerializableContact.DateInfo? = birthday.flatMap { bday in
                SerializableContact.DateInfo(
                    day: bday.day,
                    month: bday.month,
                    year: bday.year
                )
            }
            
            let serializableDates = dates.map {
                SerializableContact.LabeledDate(
                    label: $0.label,
                    date: SerializableContact.DateInfo(
                        day: $0.date.day,
                        month: $0.date.month,
                        year: $0.date.year
                    )
                )
            }
            
            return SerializableContact(
                name: name,
                namePrefix: nameComponents?.prefix,
                givenName: nameComponents?.given,
                middleName: nameComponents?.middle,
                familyName: nameComponents?.family,
                nameSuffix: nameComponents?.suffix,
                nickname: nickname,
                phoneticGivenName: nil,
                phoneticMiddleName: nil,
                phoneticFamilyName: nil,
                organizationName: organization.first,
                departmentName: organization.count > 1 ? organization[1] : nil,
                jobTitle: title,
                emails: serializableEmails,
                phones: serializablePhones,
                postalAddresses: serializableAddresses,
                urls: serializableUrls,
                socialProfiles: serializableSocialProfiles,
                instantMessageAddresses: serializableIMs,
                birthday: serializableBirthday,
                dates: serializableDates,
                contactType: "Person",
                hasImage: photo != nil,
                imageData: photo,
                thumbnailImageData: nil,
                note: note
            )
        }
    }
    
    // MARK: - VCard Line Parsing
    
    static func parseVCardLine(_ line: String, into vcard: VCardData) {
        // Split property from value
        guard let colonIndex = line.firstIndex(of: ":") else { return }
        let propertyPart = String(line[..<colonIndex])
        let valuePart = String(line[line.index(after: colonIndex)...])
        
        // Parse property name and parameters
        let propertyComponents = propertyPart.split(separator: ";", omittingEmptySubsequences: false)
        let propertyName = String(propertyComponents[0]).uppercased()
        var parameters: [String: String] = [:]
        
        for i in 1..<propertyComponents.count {
            let param = String(propertyComponents[i])
            if let equalIndex = param.firstIndex(of: "=") {
                let key = String(param[..<equalIndex]).uppercased()
                let value = String(param[param.index(after: equalIndex)...])
                parameters[key] = value
            }
        }
        
        // Unescape value
        let unescapedValue = unescapeVCF(valuePart)
        
        // Process based on property name
        switch propertyName {
        case "VERSION":
            vcard.version = unescapedValue
            
        case "FN":
            vcard.formattedName = unescapedValue
            
        case "N":
            let components = unescapedValue.split(separator: ";", omittingEmptySubsequences: false).map { String($0) }
            vcard.nameComponents = VCardData.NameComponents(
                family: components.count > 0 && !components[0].isEmpty ? components[0] : nil,
                given: components.count > 1 && !components[1].isEmpty ? components[1] : nil,
                middle: components.count > 2 && !components[2].isEmpty ? components[2] : nil,
                prefix: components.count > 3 && !components[3].isEmpty ? components[3] : nil,
                suffix: components.count > 4 && !components[4].isEmpty ? components[4] : nil
            )
            
        case "NICKNAME":
            vcard.nickname = unescapedValue
            
        case "ORG":
            vcard.organization = unescapedValue.split(separator: ";").map { String($0) }
            
        case "TITLE":
            vcard.title = unescapedValue
            
        case "EMAIL":
            let label = parseLabel(from: parameters)
            vcard.emails.append(VCardData.LabeledValue(label: label, value: unescapedValue))
            
        case "TEL":
            let label = parseLabel(from: parameters)
            vcard.phones.append(VCardData.LabeledValue(label: label, value: unescapedValue))
            
        case "ADR":
            let label = parseLabel(from: parameters)
            let components = unescapedValue.split(separator: ";", omittingEmptySubsequences: false).map { String($0) }
            vcard.addresses.append(VCardData.LabeledAddress(
                label: label,
                poBox: components.count > 0 && !components[0].isEmpty ? components[0] : nil,
                extended: components.count > 1 && !components[1].isEmpty ? components[1] : nil,
                street: components.count > 2 && !components[2].isEmpty ? components[2] : nil,
                city: components.count > 3 && !components[3].isEmpty ? components[3] : nil,
                state: components.count > 4 && !components[4].isEmpty ? components[4] : nil,
                postalCode: components.count > 5 && !components[5].isEmpty ? components[5] : nil,
                country: components.count > 6 && !components[6].isEmpty ? components[6] : nil
            ))
            
        case "URL":
            let label = parseLabel(from: parameters)
            vcard.urls.append(VCardData.LabeledValue(label: label, value: unescapedValue))
            
        case "X-SOCIALPROFILE":
            let label = parseLabel(from: parameters)
            let service = parameters["X-SERVICE"] ?? "Unknown"
            vcard.socialProfiles.append(VCardData.SocialProfile(
                label: label,
                service: service,
                username: unescapedValue
            ))
            
        case "IMPP":
            let label = parseLabel(from: parameters)
            // Parse service:username format
            if let colonIndex = unescapedValue.firstIndex(of: ":") {
                let service = String(unescapedValue[..<colonIndex])
                let username = String(unescapedValue[unescapedValue.index(after: colonIndex)...])
                vcard.instantMessages.append(VCardData.InstantMessage(
                    label: label,
                    service: service,
                    username: username
                ))
            }
            
        case "BDAY":
            vcard.birthday = parseDateComponents(from: unescapedValue)
            
        case "X-ABDATE":
            if let date = parseDateComponents(from: unescapedValue) {
                let label = parameters["LABEL"]
                vcard.dates.append(VCardData.LabeledDate(label: label, date: date))
            }
            
        case "NOTE":
            vcard.note = unescapedValue
            
        case "PHOTO":
            if parameters["ENCODING"]?.uppercased() == "BASE64" {
                vcard.photo = unescapedValue.replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "\n", with: "")
                    .replacingOccurrences(of: "\r", with: "")
            }
            
        default:
            // Ignore unrecognized properties
            break
        }
    }
    
    // MARK: - Helper Functions
    
    static func unescapeVCF(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\r", with: "\r")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
    
    static func parseLabel(from parameters: [String: String]) -> String? {
        if let type = parameters["TYPE"] {
            // Convert VCF types back to readable labels
            let types = type.split(separator: ",").map { $0.uppercased() }
            if types.contains("HOME") {
                return "Home"
            } else if types.contains("WORK") {
                return "Work"
            } else if types.contains("CELL") {
                return "Mobile"
            } else if types.contains("MAIN") {
                return "Main"
            } else if types.contains("HOME") && types.contains("FAX") {
                return "Home Fax"
            } else if types.contains("WORK") && types.contains("FAX") {
                return "Work Fax"
            } else if types.contains("PAGER") {
                return "Pager"
            } else if types.contains("OTHER") {
                return "Other"
            } else {
                return type.replacingOccurrences(of: "-", with: " ")
            }
        }
        return nil
    }
    
    static func parseDateComponents(from string: String) -> DateComponents? {
        var components = DateComponents()
        
        // Handle different date formats
        let parts = string.split(separator: "-")
        
        if parts.count >= 3 {
            // Full date: YYYY-MM-DD
            if let year = Int(parts[0]), parts[0] != "--" {
                components.year = year
            }
            if let month = Int(parts[1]) {
                components.month = month
            }
            if let day = Int(parts[2]) {
                components.day = day
            }
        } else if string.count == 8 && string.allSatisfy({ $0.isNumber }) {
            // Alternative format: YYYYMMDD
            let year = String(string.prefix(4))
            let month = String(string.dropFirst(4).prefix(2))
            let day = String(string.dropFirst(6))
            
            if let y = Int(year) { components.year = y }
            if let m = Int(month) { components.month = m }
            if let d = Int(day) { components.day = d }
        }
        
        return (components.year != nil || components.month != nil || components.day != nil) ? components : nil
    }
}