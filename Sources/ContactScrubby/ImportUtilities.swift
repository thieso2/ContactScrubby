import Foundation
import Contacts

struct ImportUtilities {
    
    // MARK: - Generic Import
    
    static func importContacts(from url: URL, type: SourceType) throws -> [SerializableContact] {
        switch type {
        case .json:
            return try importFromJSON(at: url)
        case .xml:
            return try importFromXML(at: url)
        case .vcf:
            return try VCFImportUtilities.importFromVCF(at: url)
        case .contacts:
            throw ImportError.unsupportedSource("Cannot import from Contacts as source")
        }
    }
    
    // MARK: - JSON Import
    
    static func importFromJSON(at url: URL) throws -> [SerializableContact] {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // Try to decode as array first
        if let contacts = try? decoder.decode([SerializableContact].self, from: data) {
            return contacts
        }
        
        // Try to decode as single contact
        if let contact = try? decoder.decode(SerializableContact.self, from: data) {
            return [contact]
        }
        
        throw ImportError.invalidFormat("Invalid JSON format - expected array of contacts or single contact")
    }
    
    // MARK: - XML Import
    
    static func importFromXML(at url: URL) throws -> [SerializableContact] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let parser = XMLContactParser()
        return try parser.parse(content)
    }
    
    // MARK: - Error Types
    
    enum ImportError: LocalizedError {
        case unsupportedSource(String)
        case invalidFormat(String)
        case parsingError(String)
        
        var errorDescription: String? {
            switch self {
            case .unsupportedSource(let message):
                return "Unsupported source: \(message)"
            case .invalidFormat(let message):
                return "Invalid format: \(message)"
            case .parsingError(let message):
                return "Parsing error: \(message)"
            }
        }
    }
}

// MARK: - XML Parser

class XMLContactParser: NSObject, XMLParserDelegate {
    private var contacts: [SerializableContact] = []
    private var currentContact: ContactBuilder?
    private var currentElement: String = ""
    private var currentValue: String = ""
    private var currentLabel: String?
    
    // Nested data builders
    private var currentEmail: (label: String?, value: String)?
    private var currentPhone: (label: String?, value: String)?
    private var currentAddress: AddressBuilder?
    private var currentURL: (label: String?, value: String)?
    private var currentSocialProfile: SocialProfileBuilder?
    private var currentIM: IMBuilder?
    private var currentDate: DateBuilder?
    
    func parse(_ xml: String) throws -> [SerializableContact] {
        guard let data = xml.data(using: .utf8) else {
            throw ImportUtilities.ImportError.invalidFormat("Cannot convert XML to data")
        }
        
        let parser = XMLParser(data: data)
        parser.delegate = self
        
        if parser.parse() {
            return contacts
        } else if let error = parser.parserError {
            throw ImportUtilities.ImportError.parsingError(error.localizedDescription)
        } else {
            throw ImportUtilities.ImportError.parsingError("Unknown XML parsing error")
        }
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentValue = ""
        
        switch elementName {
        case "contact":
            currentContact = ContactBuilder()
        case "email", "phone", "url":
            currentLabel = attributeDict["label"]
        case "address":
            currentAddress = AddressBuilder()
            currentAddress?.label = attributeDict["label"]
        case "profile":
            currentSocialProfile = SocialProfileBuilder()
            currentSocialProfile?.label = attributeDict["label"]
            currentSocialProfile?.service = attributeDict["service"] ?? ""
        case "im":
            currentIM = IMBuilder()
            currentIM?.label = attributeDict["label"]
            currentIM?.service = attributeDict["service"] ?? ""
        case "birthday":
            if let day = attributeDict["day"], let dayInt = Int(day) {
                currentContact?.birthday = SerializableContact.DateInfo(
                    day: dayInt,
                    month: attributeDict["month"].flatMap { Int($0) },
                    year: attributeDict["year"].flatMap { Int($0) }
                )
            }
        case "date":
            currentDate = DateBuilder()
            currentDate?.label = attributeDict["label"]
            currentDate?.day = attributeDict["day"].flatMap { Int($0) }
            currentDate?.month = attributeDict["month"].flatMap { Int($0) }
            currentDate?.year = attributeDict["year"].flatMap { Int($0) }
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmedValue = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch elementName {
        case "contact":
            if let contact = currentContact?.build() {
                contacts.append(contact)
            }
            currentContact = nil
            
        case "name":
            currentContact?.name = trimmedValue
        case "namePrefix":
            currentContact?.namePrefix = trimmedValue
        case "givenName":
            currentContact?.givenName = trimmedValue
        case "middleName":
            currentContact?.middleName = trimmedValue
        case "familyName":
            currentContact?.familyName = trimmedValue
        case "nameSuffix":
            currentContact?.nameSuffix = trimmedValue
        case "nickname":
            currentContact?.nickname = trimmedValue
        case "phoneticGivenName":
            currentContact?.phoneticGivenName = trimmedValue
        case "phoneticMiddleName":
            currentContact?.phoneticMiddleName = trimmedValue
        case "phoneticFamilyName":
            currentContact?.phoneticFamilyName = trimmedValue
        case "organizationName":
            currentContact?.organizationName = trimmedValue
        case "departmentName":
            currentContact?.departmentName = trimmedValue
        case "jobTitle":
            currentContact?.jobTitle = trimmedValue
        case "contactType":
            currentContact?.contactType = trimmedValue
        case "hasImage":
            currentContact?.hasImage = trimmedValue.lowercased() == "true"
        case "imageData":
            currentContact?.imageData = trimmedValue
        case "thumbnailImageData":
            currentContact?.thumbnailImageData = trimmedValue
        case "note":
            currentContact?.note = trimmedValue
            
        case "email":
            if !trimmedValue.isEmpty {
                currentContact?.emails.append(SerializableContact.LabeledValue(
                    label: currentLabel,
                    value: trimmedValue
                ))
            }
            currentLabel = nil
            
        case "phone":
            if !trimmedValue.isEmpty {
                currentContact?.phones.append(SerializableContact.LabeledValue(
                    label: currentLabel,
                    value: trimmedValue
                ))
            }
            currentLabel = nil
            
        case "url":
            if !trimmedValue.isEmpty {
                currentContact?.urls.append(SerializableContact.LabeledValue(
                    label: currentLabel,
                    value: trimmedValue
                ))
            }
            currentLabel = nil
            
        case "street":
            currentAddress?.street = trimmedValue
        case "city":
            currentAddress?.city = trimmedValue
        case "state":
            currentAddress?.state = trimmedValue
        case "postalCode":
            currentAddress?.postalCode = trimmedValue
        case "country":
            currentAddress?.country = trimmedValue
        case "address":
            if let address = currentAddress {
                currentContact?.addresses.append(SerializableContact.LabeledAddress(
                    label: address.label,
                    street: address.street,
                    city: address.city,
                    state: address.state,
                    postalCode: address.postalCode,
                    country: address.country
                ))
            }
            currentAddress = nil
            
        case "profile":
            if let profile = currentSocialProfile {
                currentContact?.socialProfiles.append(SerializableContact.SocialProfile(
                    label: profile.label,
                    service: profile.service,
                    username: trimmedValue
                ))
            }
            currentSocialProfile = nil
            
        case "im":
            if let im = currentIM {
                currentContact?.instantMessages.append(SerializableContact.InstantMessage(
                    label: im.label,
                    service: im.service,
                    username: trimmedValue
                ))
            }
            currentIM = nil
            
        case "date":
            if let date = currentDate, let day = date.day {
                currentContact?.dates.append(SerializableContact.LabeledDate(
                    label: date.label,
                    date: SerializableContact.DateInfo(
                        day: day,
                        month: date.month,
                        year: date.year
                    )
                ))
            }
            currentDate = nil
            
        default:
            break
        }
        
        currentElement = ""
    }
    
    // MARK: - Builder Classes
    
    private class ContactBuilder {
        var name: String = ""
        var namePrefix: String?
        var givenName: String?
        var middleName: String?
        var familyName: String?
        var nameSuffix: String?
        var nickname: String?
        var phoneticGivenName: String?
        var phoneticMiddleName: String?
        var phoneticFamilyName: String?
        var organizationName: String?
        var departmentName: String?
        var jobTitle: String?
        var emails: [SerializableContact.LabeledValue] = []
        var phones: [SerializableContact.LabeledValue] = []
        var addresses: [SerializableContact.LabeledAddress] = []
        var urls: [SerializableContact.LabeledValue] = []
        var socialProfiles: [SerializableContact.SocialProfile] = []
        var instantMessages: [SerializableContact.InstantMessage] = []
        var birthday: SerializableContact.DateInfo?
        var dates: [SerializableContact.LabeledDate] = []
        var contactType: String = "Person"
        var hasImage: Bool = false
        var imageData: String?
        var thumbnailImageData: String?
        var note: String?
        
        func build() -> SerializableContact {
            SerializableContact(
                name: name.isEmpty ? "No Name" : name,
                namePrefix: namePrefix,
                givenName: givenName,
                middleName: middleName,
                familyName: familyName,
                nameSuffix: nameSuffix,
                nickname: nickname,
                phoneticGivenName: phoneticGivenName,
                phoneticMiddleName: phoneticMiddleName,
                phoneticFamilyName: phoneticFamilyName,
                organizationName: organizationName,
                departmentName: departmentName,
                jobTitle: jobTitle,
                emails: emails,
                phones: phones,
                postalAddresses: addresses,
                urls: urls,
                socialProfiles: socialProfiles,
                instantMessageAddresses: instantMessages,
                birthday: birthday,
                dates: dates,
                contactType: contactType,
                hasImage: hasImage,
                imageData: imageData,
                thumbnailImageData: thumbnailImageData,
                note: note
            )
        }
    }
    
    private class AddressBuilder {
        var label: String?
        var street: String?
        var city: String?
        var state: String?
        var postalCode: String?
        var country: String?
    }
    
    private class SocialProfileBuilder {
        var label: String?
        var service: String = ""
    }
    
    private class IMBuilder {
        var label: String?
        var service: String = ""
    }
    
    private class DateBuilder {
        var label: String?
        var day: Int?
        var month: Int?
        var year: Int?
    }
}