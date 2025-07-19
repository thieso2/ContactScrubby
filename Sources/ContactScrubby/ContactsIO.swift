import Foundation
import Contacts

/// Unified interface for reading and writing contacts from/to various sources
struct ContactsIO {
    
    // MARK: - Reading Contacts
    
    static func readContacts(
        from source: String,
        type: SourceType? = nil,
        filter: FilterMode = .all,
        dubiousScore: Int = 3
    ) throws -> [SerializableContact] {
        
        // Determine source type
        let sourceType: SourceType
        if let explicitType = type {
            sourceType = explicitType
        } else if source.lowercased() == "contacts" {
            sourceType = .contacts
        } else if let fileType = SourceType.fromFilename(source) {
            sourceType = fileType
        } else {
            throw IOError.invalidSource("Cannot determine source type for '\(source)'. Use --source-type to specify.")
        }
        
        switch sourceType {
        case .contacts:
            return try readFromContacts(filter: filter, dubiousScore: dubiousScore)
        case .json, .xml, .vcf:
            guard FileManager.default.fileExists(atPath: source) else {
                throw IOError.fileNotFound("File not found: \(source)")
            }
            let url = URL(fileURLWithPath: source)
            let contacts = try ImportUtilities.importContacts(from: url, type: sourceType)
            return filterContacts(contacts, filter: filter, dubiousScore: dubiousScore)
        }
    }
    
    // MARK: - Writing Contacts
    
    static func writeContacts(
        _ contacts: [SerializableContact],
        to destination: String,
        type: DestinationType? = nil,
        imageMode: ImageMode = .none
    ) throws -> WriteResult {
        
        // Determine destination type
        let destType: DestinationType
        if let explicitType = type {
            destType = explicitType
        } else if destination.lowercased() == "contacts" {
            destType = .contacts
        } else if let fileType = DestinationType.fromFilename(destination) {
            destType = fileType
        } else {
            throw IOError.invalidDestination("Cannot determine destination type for '\(destination)'. Use --dest-type to specify.")
        }
        
        switch destType {
        case .contacts:
            return try writeToContacts(contacts)
        case .json:
            let url = URL(fileURLWithPath: destination)
            try ExportUtilities.exportAsJSON(contacts: contacts, to: url)
            return WriteResult(successCount: contacts.count, failedCount: 0, errors: [], message: "Exported \(contacts.count) contacts to \(destination)")
        case .xml:
            let url = URL(fileURLWithPath: destination)
            try ExportUtilities.exportAsXML(contacts: contacts, to: url)
            return WriteResult(successCount: contacts.count, failedCount: 0, errors: [], message: "Exported \(contacts.count) contacts to \(destination)")
        case .vcf:
            let url = URL(fileURLWithPath: destination)
            try ExportUtilities.exportAsVCF(contacts: contacts, to: url)
            return WriteResult(successCount: contacts.count, failedCount: 0, errors: [], message: "Exported \(contacts.count) contacts to \(destination)")
        }
    }
    
    // MARK: - Private Methods
    
    private static func readFromContacts(filter: FilterMode, dubiousScore: Int) throws -> [SerializableContact] {
        let manager = ContactsManager()
        
        // Get contacts based on filter
        let contacts: [SerializableContact]
        if filter == .dubious {
            let analyses = try manager.getDubiousContacts(minimumScore: dubiousScore)
            contacts = analyses.map { analysis in
                manager.convertToSerializable(analysis.contact, includeImages: true)
            }
        } else {
            let cnContacts = try manager.listContactsWithAllFields()
            let filtered = cnContacts.filter { contact in
                FilterUtilities.shouldIncludeContact(contact, filter: filter)
            }
            contacts = filtered.map { contact in
                manager.convertToSerializable(contact, includeImages: true)
            }
        }
        
        return contacts
    }
    
    private static func writeToContacts(_ contacts: [SerializableContact]) throws -> WriteResult {
        let manager = ContactsManager()
        
        var successCount = 0
        var failedCount = 0
        var errors: [String] = []
        
        for contact in contacts {
            do {
                _ = try manager.createContact(from: contact)
                successCount += 1
            } catch {
                failedCount += 1
                errors.append("\(contact.name): \(error.localizedDescription)")
            }
        }
        
        let message = "Added \(successCount) contacts to macOS Contacts"
        return WriteResult(
            successCount: successCount,
            failedCount: failedCount,
            errors: errors,
            message: message
        )
    }
    
    private static func filterContacts(
        _ contacts: [SerializableContact],
        filter: FilterMode,
        dubiousScore: Int
    ) -> [SerializableContact] {
        
        guard filter != .all else { return contacts }
        
        return contacts.filter { contact in
            let emails = contact.emails.map { $0.value }
            let phones = contact.phones.map { $0.value }
            
            switch filter {
            case .withEmail:
                return !emails.isEmpty
            case .withoutEmail:
                return emails.isEmpty
            case .facebookOnly:
                return emails.contains { $0.lowercased().hasSuffix("@facebook.com") }
            case .facebookExclusive:
                let facebookEmails = emails.filter { $0.lowercased().hasSuffix("@facebook.com") }
                return !facebookEmails.isEmpty && facebookEmails.count == emails.count && phones.isEmpty
            case .dubious:
                // For file-based sources, we can't properly analyze dubiousness
                // This would require converting to CNContact first
                return isDubiousSerializable(contact, minimumScore: dubiousScore)
            case .noContact:
                return emails.isEmpty && phones.isEmpty
            case .all:
                return true
            }
        }
    }
    
    private static func isDubiousSerializable(_ contact: SerializableContact, minimumScore: Int) -> Bool {
        var score = 0
        
        // No name or generic name
        if contact.name == "No Name" || contact.name.isEmpty {
            score += 2
        }
        
        // Check for minimal information
        if contact.emails.isEmpty && contact.phones.isEmpty {
            score += 3
        }
        
        // Facebook-only email
        if contact.emails.count == 1 && contact.emails[0].value.lowercased().hasSuffix("@facebook.com") {
            score += 3
        }
        
        // No organization, job title, or addresses
        if contact.organizationName == nil && contact.jobTitle == nil && contact.postalAddresses.isEmpty {
            score += 1
        }
        
        return score >= minimumScore
    }
    
    // MARK: - Result Types
    
    struct WriteResult {
        let successCount: Int
        let failedCount: Int
        let errors: [String]
        let message: String
    }
    
    enum IOError: LocalizedError {
        case invalidSource(String)
        case invalidDestination(String)
        case fileNotFound(String)
        case accessDenied(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidSource(let message):
                return "Invalid source: \(message)"
            case .invalidDestination(let message):
                return "Invalid destination: \(message)"
            case .fileNotFound(let message):
                return "File not found: \(message)"
            case .accessDenied(let message):
                return "Access denied: \(message)"
            }
        }
    }
}