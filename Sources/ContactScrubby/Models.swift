import Foundation
import ArgumentParser

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
            return "List contacts that have email addresses (default)"
        case .withoutEmail:
            return "List contacts that have no email addresses"
        case .facebookOnly:
            return "List only contacts with @facebook.com email addresses"
        case .facebookExclusive:
            return "List contacts with ONLY @facebook.com emails and no phones"
        case .dubious:
            return "List dubious/incomplete contacts (likely auto-imports)"
        case .all:
            return "List all contacts"
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
