import Foundation
import Contacts

struct FilterUtilities {
    
    // MARK: - Contact Filtering Logic
    
    static func shouldIncludeContact(_ contact: CNContact, filter: FilterMode) -> Bool {
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
            return true // Already handled in command handlers
        }
    }
}