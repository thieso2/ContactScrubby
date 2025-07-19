import Foundation
import Contacts

// MARK: - Core Types

/// Strong typing for contact identifiers
struct ContactID: Hashable, ExpressibleByStringLiteral, Sendable {
    let value: String
    
    init(stringLiteral value: String) {
        self.value = value
    }
    
    init(_ value: String) {
        self.value = value
    }
}

/// Type-safe contact labels
enum ContactLabel: String, CaseIterable, Sendable {
    case home = "home"
    case work = "work" 
    case mobile = "mobile"
    case main = "main"
    case other = "other"
    
    var localizedDescription: String {
        switch self {
        case .home: return "Home"
        case .work: return "Work"
        case .mobile: return "Mobile"
        case .main: return "Main"
        case .other: return "Other"
        }
    }
    
    /// Convert from CNLabel constants
    static func from(cnLabel: String?) -> ContactLabel? {
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
    var cnLabel: String {
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
enum ExportFormat: String, CaseIterable, Sendable {
    case json = "json"
    case xml = "xml"
    case vcf = "vcf"
    
    var fileExtension: String { rawValue }
    
    static func from(fileExtension: String) -> ExportFormat? {
        ExportFormat(rawValue: fileExtension.lowercased())
    }
}

/// Image handling strategies
enum ImageExportStrategy: String, CaseIterable, Sendable {
    case none = "none"
    case inline = "inline"
    case folder = "folder"
    
    var description: String {
        switch self {
        case .none: return "Don't include images"
        case .inline: return "Include images as Base64 data"
        case .folder: return "Save images to separate folder"
        }
    }
}

// MARK: - Property Wrappers

/// Validates and sanitizes string input
@propertyWrapper
struct Sanitized: Sendable {
    enum Strategy: Sendable {
        case filename
        case email
        case phoneNumber
    }
    
    private let strategy: Strategy
    private var value: String
    
    init(wrappedValue: String, _ strategy: Strategy) {
        self.strategy = strategy
        self.value = Self.sanitize(wrappedValue, using: strategy)
    }
    
    var wrappedValue: String {
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
struct Validated<T>: Sendable where T: Sendable {
    enum ValidationRule: Sendable {
        case notEmpty
        case maxCount(Int)
        case email
    }
    
    private let rules: [ValidationRule]
    private var value: [T]
    
    init(wrappedValue: [T], _ rules: ValidationRule...) {
        self.rules = rules
        self.value = wrappedValue
        // Note: In a real implementation, we'd validate here
    }
    
    var wrappedValue: [T] {
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
    func sanitizedForFilename() -> String {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "unnamed" }
        
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return trimmed.components(separatedBy: invalidChars).joined(separator: "_")
    }
}

// MARK: - Result Types

/// Success result with metadata
struct OperationResult<T: Sendable>: Sendable {
    let value: T
    let metadata: OperationMetadata
    
    init(_ value: T, metadata: OperationMetadata = .empty) {
        self.value = value
        self.metadata = metadata
    }
}

/// Operation metadata for reporting
struct OperationMetadata: Sendable {
    let duration: TimeInterval
    let itemsProcessed: Int
    let warnings: [String]
    
    static let empty = OperationMetadata(duration: 0, itemsProcessed: 0, warnings: [])
    
    init(duration: TimeInterval = 0, itemsProcessed: Int = 0, warnings: [String] = []) {
        self.duration = duration
        self.itemsProcessed = itemsProcessed
        self.warnings = warnings
    }
}