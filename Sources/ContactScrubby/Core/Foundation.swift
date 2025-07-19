import Foundation
import Contacts

// MARK: - Core Types

/// Strong typing for contact identifiers
public struct ContactID: Hashable, ExpressibleByStringLiteral, Sendable {
    public let value: String
    
    public init(stringLiteral value: String) {
        self.value = value
    }
    
    public init(_ value: String) {
        self.value = value
    }
}

/// Type-safe contact labels
public enum ContactLabel: String, CaseIterable, Sendable, Codable {
    case home = "home"
    case work = "work" 
    case mobile = "mobile"
    case main = "main"
    case other = "other"
    
    public var localizedDescription: String {
        switch self {
        case .home: return "Home"
        case .work: return "Work"
        case .mobile: return "Mobile"
        case .main: return "Main"
        case .other: return "Other"
        }
    }
    
    /// Convert from CNLabel constants
    public static func from(cnLabel: String?) -> ContactLabel? {
        guard let label = cnLabel else { return nil }
        
        switch label {
        case CNLabelHome: return .home
        case CNLabelWork: return .work
        case CNLabelPhoneNumberMobile: return .mobile
        case CNLabelPhoneNumberMain: return .main
        case CNLabelOther: return .other
        default: return ContactLabel(rawValue: label.lowercased())
        }
    }
    
    /// Convert to CNLabel constant
    public var cnLabel: String {
        switch self {
        case .home: return CNLabelHome
        case .work: return CNLabelWork
        case .mobile: return CNLabelPhoneNumberMobile
        case .main: return CNLabelPhoneNumberMain
        case .other: return CNLabelOther
        }
    }
}

/// Export format types
public enum ExportFormat: String, CaseIterable, Sendable, ExpressibleByArgument {
    case json = "json"
    case xml = "xml"
    case vcf = "vcf"
    
    public var fileExtension: String { rawValue }
    
    public static func from(fileExtension: String) -> ExportFormat? {
        ExportFormat(rawValue: fileExtension.lowercased())
    }
    
    public init?(argument: String) {
        self.init(rawValue: argument.lowercased())
    }
    
    public var description: String {
        switch self {
        case .json: return "JSON file"
        case .xml: return "XML file"
        case .vcf: return "VCF (vCard) file"
        }
    }
}

/// Image handling strategies
public enum ImageExportStrategy: String, CaseIterable, Sendable, ExpressibleByArgument {
    case none = "none"
    case inline = "inline"
    case folder = "folder"
    
    public init?(argument: String) {
        self.init(rawValue: argument.lowercased())
    }
    
    public var description: String {
        switch self {
        case .none: return "Don't include images"
        case .inline: return "Include images as Base64 data"
        case .folder: return "Save images to separate folder"
        }
    }
}

/// Filter modes for contacts
public enum FilterMode: String, CaseIterable, Sendable, ExpressibleByArgument {
    case withEmail = "with-email"
    case withoutEmail = "no-email"
    case facebookOnly = "facebook-only"
    case facebookExclusive = "facebook-exclusive"
    case noContact = "no-contact"
    case dubious = "dubious"
    case all = "all"
    
    public init?(argument: String) {
        self.init(rawValue: argument.lowercased())
    }
    
    public var description: String {
        switch self {
        case .withEmail: return "Contacts with email addresses"
        case .withoutEmail: return "Contacts without email addresses"
        case .facebookOnly: return "Contacts with Facebook-only emails"
        case .facebookExclusive: return "Contacts with only Facebook emails"
        case .noContact: return "Contacts with no contact information"
        case .dubious: return "Dubious contacts"
        case .all: return "All contacts"
        }
    }
}

// MARK: - Property Wrappers

/// Validates and sanitizes string input
@propertyWrapper
public struct Sanitized: Sendable {
    public enum Strategy: Sendable {
        case filename
        case email
        case phoneNumber
    }
    
    private let strategy: Strategy
    private var value: String
    
    public init(wrappedValue: String, _ strategy: Strategy) {
        self.strategy = strategy
        self.value = Self.sanitize(wrappedValue, using: strategy)
    }
    
    public var wrappedValue: String {
        get { value }
        set { value = Self.sanitize(newValue, using: strategy) }
    }
    
    private static func sanitize(_ input: String, using strategy: Strategy) -> String {
        switch strategy {
        case .filename:
            return input.sanitizedForFilename()
        case .email:
            return input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        case .phoneNumber:
            return input.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        }
    }
}

/// Validates array content
@propertyWrapper
public struct Validated<T>: Sendable where T: Sendable {
    public enum ValidationRule: Sendable {
        case notEmpty
        case maxCount(Int)
        case email
    }
    
    private let rules: [ValidationRule]
    private var value: [T]
    
    public init(wrappedValue: [T], _ rules: ValidationRule...) {
        self.rules = rules
        self.value = wrappedValue
        // Note: In a real implementation, we'd validate here
    }
    
    public var wrappedValue: [T] {
        get { value }
        set { 
            // In a real implementation, we'd validate against rules
            value = newValue 
        }
    }
}

// MARK: - Extensions

extension String {
    /// Sanitize string for use as filename
    public func sanitizedForFilename() -> String {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "unnamed" }
        
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return trimmed.components(separatedBy: invalidChars).joined(separator: "_")
    }
}

// MARK: - Result Types

/// Success result with metadata
public struct OperationResult<T: Sendable>: Sendable {
    public let value: T
    public let metadata: OperationMetadata
    
    public init(_ value: T, metadata: OperationMetadata = .empty) {
        self.value = value
        self.metadata = metadata
    }
}

/// Operation metadata for reporting
public struct OperationMetadata: Sendable {
    public let duration: TimeInterval
    public let itemsProcessed: Int
    public let warnings: [String]
    
    public static let empty = OperationMetadata(duration: 0, itemsProcessed: 0, warnings: [])
    
    public init(duration: TimeInterval = 0, itemsProcessed: Int = 0, warnings: [String] = []) {
        self.duration = duration
        self.itemsProcessed = itemsProcessed
        self.warnings = warnings
    }
}

// Import ArgumentParser for ExpressibleByArgument
import ArgumentParser