import Foundation

struct MessageUtilities {

    // MARK: - User Messages

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
}
