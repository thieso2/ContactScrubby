import Foundation
import ArgumentParser
import Contacts

enum FilterMode: String, ExpressibleByArgument, CaseIterable {
    case withEmail = "with-email"
    case withoutEmail = "no-email"
    case facebookOnly = "facebook"
    case facebookExclusive = "facebook-exclusive"
    case dubious = "dubious"
    case all = "all"

    var help: String {
        switch self {
        case .withEmail:
            return "List contacts that have email addresses"
        case .withoutEmail:
            return "List contacts that have no email addresses"
        case .facebookOnly:
            return "List only contacts with @facebook.com email addresses"
        case .facebookExclusive:
            return "List contacts with ONLY @facebook.com emails and no phones"
        case .dubious:
            return "List dubious/incomplete contacts (likely auto-imports)"
        case .all:
            return "List all contacts (default)"
        }
    }
}

enum ImageMode: String, ExpressibleByArgument, CaseIterable {
    case none
    case inline
    case folder

    var help: String {
        switch self {
        case .none:
            return "Don't include images in export (default)"
        case .inline:
            return "Include images as Base64 data in export"
        case .folder:
            return "Save images to separate folder and reference by path"
        }
    }
}

struct ExportOptions {
    let filename: String
    let imageMode: ImageMode
    let filterMode: FilterMode
    let dubiousMinScore: Int

    var fileURL: URL {
        URL(fileURLWithPath: filename)
    }

    var fileExtension: String {
        fileURL.pathExtension.lowercased()
    }

    var isValidFormat: Bool {
        ["json", "xml"].contains(fileExtension)
    }
}

struct GroupOptions {
    let groupName: String
    let filterMode: FilterMode
    let dubiousMinScore: Int
}

struct DisplayOptions {
    let filterMode: FilterMode
    let dubiousMinScore: Int
    let showAllFields: Bool
}

// MARK: - Duplicate Detection and Merging

enum DuplicateMatchType {
    case exact           // Identical names and shared contact info
    case fuzzy           // Similar names with shared contact info
    case contactInfo     // Different names but same email/phone
    case phonetic        // Similar sounding names with some overlap
}

struct DuplicateMatch {
    let contact1: CNContact
    let contact2: CNContact
    let matchType: DuplicateMatchType
    let confidence: Double // 0.0 to 1.0
    let matchingFields: [String]
    let conflictingFields: [String]
}

struct DuplicateGroup {
    let contacts: [CNContact]
    let primaryContact: CNContact // The one to keep
    let duplicates: [CNContact]   // The ones to merge into primary
    let confidence: Double
    let totalFields: Int
}

enum MergeStrategy {
    case mostComplete    // Prefer contact with more fields
    case mostRecent      // Use modification dates when available
    case interactive     // Ask user for each conflict
    case conservative    // Only merge when highly confident
}

struct MergeResult {
    let mergedContact: CNContact
    let originalContacts: [CNContact]
    let conflictsResolved: [String]
    let fieldsMerged: Int
    let success: Bool
    let error: String?
}
