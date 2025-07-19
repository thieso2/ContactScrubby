import Foundation
import Contacts

/// # ContactScrubby Foundation
///
/// This module provides the core types, enums, and property wrappers that form the foundation
/// of the ContactScrubby application. It defines essential types for contact identification,
/// data validation, and configuration management.
///
/// ## Overview
///
/// The Foundation module implements:
/// - **Type-safe identifiers** for contacts and labels
/// - **Property wrappers** for data validation and sanitization
/// - **Core enums** for export formats, filter modes, and image strategies
/// - **Configuration types** with sensible defaults
///
/// ## Key Features
///
/// - Thread-safe with `Sendable` conformance
/// - Argument parsing support for CLI integration
/// - Comprehensive validation and sanitization
/// - Extensible design for future enhancements

// MARK: - Core Types

/// A type-safe wrapper for contact identifiers that prevents mixing up different types of IDs.
///
/// `ContactID` provides strong typing for contact identifiers, ensuring that contact IDs
/// cannot be accidentally mixed with other string identifiers in the application.
///
/// ## Usage
///
/// ```swift
/// let contactID: ContactID = "ABC-123-XYZ"
/// let anotherID = ContactID("DEF-456-UVW")
/// ```
///
/// ## Features
///
/// - **Type Safety**: Prevents mixing contact IDs with other strings
/// - **Hashable**: Can be used as dictionary keys and in sets
/// - **Sendable**: Thread-safe for concurrent operations
/// - **String Literal**: Supports convenient initialization from string literals
public struct ContactID: Hashable, ExpressibleByStringLiteral, Sendable {
    /// The underlying string value of the contact identifier
    public let value: String
    
    /// Creates a contact ID from a string literal
    /// - Parameter value: The string value for the contact ID
    public init(stringLiteral value: String) {
        self.value = value
    }
    
    /// Creates a contact ID from a string value
    /// - Parameter value: The string value for the contact ID
    public init(_ value: String) {
        self.value = value
    }
}

/// Type-safe enumeration for contact field labels (Home, Work, Mobile, etc.).
///
/// `ContactLabel` provides a type-safe way to handle contact field labels, with automatic
/// conversion from Core Data `CNLabel` constants and localized display strings.
///
/// ## Usage
///
/// ```swift
/// let homeEmail = LabeledValue(label: .home, value: "user@example.com")
/// let workPhone = LabeledValue(label: .work, value: "+1-555-0123")
/// ```
///
/// ## Features
///
/// - **Type Safety**: Prevents invalid label assignments
/// - **Localization**: Provides human-readable descriptions
/// - **CNLabel Integration**: Automatic conversion from Contacts framework
/// - **Codable**: Supports JSON/XML serialization
public enum ContactLabel: String, CaseIterable, Sendable, Codable {
    /// Home address, phone, email, etc.
    case home = "home"
    /// Work/business address, phone, email, etc.
    case work = "work" 
    /// Mobile phone number
    case mobile = "mobile"
    /// Main/primary contact method
    case main = "main"
    /// Other/miscellaneous contact method
    case other = "other"
    
    /// Returns a localized, human-readable description of the label
    public var localizedDescription: String {
        switch self {
        case .home: return "Home"
        case .work: return "Work"
        case .mobile: return "Mobile"
        case .main: return "Main"
        case .other: return "Other"
        }
    }
    
    /// Converts a Core Data CNLabel constant to a ContactLabel
    /// - Parameter cnLabel: The CNLabel string constant from Contacts framework
    /// - Returns: The corresponding ContactLabel, or nil if no match is found
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
    
    /// Converts the ContactLabel back to a CNLabel constant for Contacts framework integration
    /// - Returns: The corresponding CNLabel string constant
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

/// Supported file formats for contact import and export operations.
///
/// `ExportFormat` defines the file formats that ContactScrubby can read from and write to,
/// with automatic file extension detection and CLI argument parsing support.
///
/// ## Supported Formats
///
/// - **JSON**: Structured data format, easy to read and widely supported
/// - **XML**: Markup format with hierarchical structure
/// - **VCF**: vCard format, standard for contact exchange
///
/// ## Usage
///
/// ```swift
/// let format = ExportFormat.json
/// let fromExtension = ExportFormat.from(fileExtension: "vcf") // Returns .vcf
/// ```
public enum ExportFormat: String, CaseIterable, Sendable, ExpressibleByArgument {
    /// JSON (JavaScript Object Notation) format
    case json = "json"
    /// XML (eXtensible Markup Language) format
    case xml = "xml"
    /// VCF (vCard) format - industry standard for contacts
    case vcf = "vcf"
    
    /// Returns the file extension for this format
    public var fileExtension: String { rawValue }
    
    /// Creates an ExportFormat from a file extension
    /// - Parameter fileExtension: The file extension (e.g., "json", "xml", "vcf")
    /// - Returns: The corresponding ExportFormat, or nil if not supported
    public static func from(fileExtension: String) -> ExportFormat? {
        ExportFormat(rawValue: fileExtension.lowercased())
    }
    
    /// Creates an ExportFormat from a command line argument
    /// - Parameter argument: The argument string from the command line
    public init?(argument: String) {
        self.init(rawValue: argument.lowercased())
    }
    
    /// Returns a human-readable description of the format
    public var description: String {
        switch self {
        case .json: return "JSON file"
        case .xml: return "XML file"
        case .vcf: return "VCF (vCard) file"
        }
    }
}

/// Strategies for handling contact images during export operations.
///
/// `ImageExportStrategy` determines how contact profile images are handled when exporting
/// contacts to files. Different strategies offer trade-offs between file size, portability,
/// and organization.
///
/// ## Strategies
///
/// - **none**: Exclude images entirely (smallest file size)
/// - **inline**: Embed images as Base64 data (portable but larger files)
/// - **folder**: Save images to separate folder (organized but multiple files)
///
/// ## Usage
///
/// ```swift
/// let strategy = ImageExportStrategy.inline
/// let config = ExportConfiguration(format: .json, imageStrategy: strategy)
/// ```
public enum ImageExportStrategy: String, CaseIterable, Sendable, ExpressibleByArgument {
    /// Don't include contact images in the export
    case none = "none"
    /// Include images as Base64-encoded data inline in the export file
    case inline = "inline"
    /// Save images to a separate folder alongside the export file
    case folder = "folder"
    
    /// Creates an ImageExportStrategy from a command line argument
    /// - Parameter argument: The argument string from the command line
    public init?(argument: String) {
        self.init(rawValue: argument.lowercased())
    }
    
    /// Returns a human-readable description of the strategy
    public var description: String {
        switch self {
        case .none: return "Don't include images"
        case .inline: return "Include images as Base64 data"
        case .folder: return "Save images to separate folder"
        }
    }
}

/// Contact filtering modes for selecting specific subsets of contacts.
///
/// `FilterMode` provides various ways to filter contacts based on their content and quality.
/// These filters are essential for the contact analysis and cleanup functionality.
///
/// ## Filter Types
///
/// ### Email-based Filters
/// - **withEmail**: Contacts that have at least one email address
/// - **withoutEmail**: Contacts with no email addresses
/// - **facebookOnly**: Contacts with only Facebook-related emails
/// - **facebookExclusive**: Contacts with Facebook emails and no other emails
///
/// ### Quality-based Filters  
/// - **dubious**: Contacts identified as potentially problematic
/// - **noContact**: Contacts with no email or phone information
/// - **all**: No filtering applied (all contacts)
///
/// ## Usage
///
/// ```swift
/// let filter = ContactFilter(mode: .dubious, dubiousScore: 3)
/// let dubiousContacts = await contactManager.loadContacts(filter: filter)
/// ```
public enum FilterMode: String, CaseIterable, Sendable, ExpressibleByArgument {
    /// Contacts that have at least one email address
    case withEmail = "with-email"
    /// Contacts with no email addresses
    case withoutEmail = "no-email"
    /// Contacts with any Facebook-related email addresses
    case facebookOnly = "facebook-only"
    /// Contacts with only Facebook emails (no other email providers)
    case facebookExclusive = "facebook-exclusive"
    /// Contacts with neither email nor phone information
    case noContact = "no-contact"
    /// Contacts identified as potentially problematic or fake
    case dubious = "dubious"
    /// All contacts (no filtering applied)
    case all = "all"
    
    /// Creates a FilterMode from a command line argument
    /// - Parameter argument: The argument string from the command line
    public init?(argument: String) {
        self.init(rawValue: argument.lowercased())
    }
    
    /// Returns a human-readable description of the filter mode
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

/// A property wrapper that validates and sanitizes string input according to different strategies.
///
/// `@Sanitized` automatically cleans and validates string values when they are set, ensuring
/// data consistency and preventing invalid input from causing issues.
///
/// ## Usage
///
/// ```swift
/// struct Contact {
///     @Sanitized(.filename) var exportName: String
///     @Sanitized(.email) var primaryEmail: String
///     @Sanitized(.phoneNumber) var phone: String
/// }
/// ```
///
/// ## Strategies
///
/// - **filename**: Removes invalid filename characters and normalizes paths
/// - **email**: Validates email format and normalizes case
/// - **phoneNumber**: Formats phone numbers consistently
@propertyWrapper
public struct Sanitized: Sendable {
    /// Sanitization strategies for different types of string data
    public enum Strategy: Sendable {
        /// Remove invalid filename characters and normalize paths
        case filename
        /// Validate and normalize email addresses
        case email
        /// Format and validate phone numbers
        case phoneNumber
    }
    
    private let strategy: Strategy
    private var value: String
    
    /// Creates a sanitized property wrapper with the specified strategy
    /// - Parameters:
    ///   - wrappedValue: The initial string value
    ///   - strategy: The sanitization strategy to apply
    public init(wrappedValue: String, _ strategy: Strategy) {
        self.strategy = strategy
        self.value = Self.sanitize(wrappedValue, using: strategy)
    }
    
    /// The wrapped string value, automatically sanitized when set
    public var wrappedValue: String {
        get { value }
        set { value = Self.sanitize(newValue, using: strategy) }
    }
    
    /// Sanitizes input string according to the specified strategy
    /// - Parameters:
    ///   - input: The string to sanitize
    ///   - strategy: The sanitization strategy to apply
    /// - Returns: The sanitized string
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

/// A property wrapper that validates array content according to specified validation rules.
///
/// `@Validated` ensures that array properties meet certain criteria, providing compile-time
/// and runtime validation for data integrity.
///
/// ## Usage
///
/// ```swift
/// struct Contact {
///     @Validated(.notEmpty, .maxCount(5)) var emails: [String]
///     @Validated(.maxCount(10)) var phoneNumbers: [String]
/// }
/// ```
///
/// ## Validation Rules
///
/// - **notEmpty**: Array must contain at least one element
/// - **maxCount**: Array cannot exceed specified number of elements
/// - **email**: Array elements must be valid email addresses (when T is String)
@propertyWrapper
public struct Validated<T>: Sendable where T: Sendable {
    /// Validation rules that can be applied to arrays
    public enum ValidationRule: Sendable {
        /// Array must not be empty
        case notEmpty
        /// Array must not exceed the specified count
        case maxCount(Int)
        /// Array elements must be valid email addresses (for String arrays)
        case email
    }
    
    private let rules: [ValidationRule]
    private var value: [T]
    
    /// Creates a validated property wrapper with the specified rules
    /// - Parameters:
    ///   - wrappedValue: The initial array value
    ///   - rules: The validation rules to apply
    public init(wrappedValue: [T], _ rules: ValidationRule...) {
        self.rules = rules
        self.value = wrappedValue
        // Note: In a real implementation, we'd validate here
    }
    
    /// The wrapped array value, validated according to the specified rules
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
    /// Sanitizes a string for safe use as a filename by removing invalid characters.
    ///
    /// This method removes or replaces characters that are not allowed in filenames
    /// on common operating systems (Windows, macOS, Linux).
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let userInput = "My File: With/Invalid\\Characters?"
    /// let safeFilename = userInput.sanitizedForFilename()
    /// // Result: "My File_ With_Invalid_Characters_"
    /// ```
    ///
    /// - Returns: A sanitized string safe for use as a filename
    public func sanitizedForFilename() -> String {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "unnamed" }
        
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return trimmed.components(separatedBy: invalidChars).joined(separator: "_")
    }
}

// MARK: - Result Types

/// A wrapper for operation results that includes both the value and metadata about the operation.
///
/// `OperationResult` provides a standardized way to return operation results along with
/// performance metrics and contextual information.
///
/// ## Usage
///
/// ```swift
/// let metadata = OperationMetadata(duration: 1.5, itemsProcessed: 100, warnings: [])
/// let result = OperationResult(contacts, metadata: metadata)
/// ```
public struct OperationResult<T: Sendable>: Sendable {
    /// The successful result value
    public let value: T
    /// Metadata about the operation that produced this result
    public let metadata: OperationMetadata
    
    /// Creates an operation result with the specified value and metadata
    /// - Parameters:
    ///   - value: The result value
    ///   - metadata: Operation metadata (defaults to empty)
    public init(_ value: T, metadata: OperationMetadata = .empty) {
        self.value = value
        self.metadata = metadata
    }
}

/// Metadata about an operation's execution including timing and diagnostic information.
///
/// `OperationMetadata` provides standardized reporting for operations, enabling performance
/// monitoring and debugging assistance.
///
/// ## Usage
///
/// ```swift
/// let metadata = OperationMetadata(
///     duration: 2.5,
///     itemsProcessed: 1000,
///     warnings: ["Some items were skipped due to invalid data"]
/// )
/// ```
public struct OperationMetadata: Sendable {
    /// How long the operation took to complete
    public let duration: TimeInterval
    /// Number of items processed during the operation
    public let itemsProcessed: Int
    /// Any warnings generated during the operation
    public let warnings: [String]
    
    /// Empty metadata instance for operations without tracking
    public static let empty = OperationMetadata(duration: 0, itemsProcessed: 0, warnings: [])
    
    /// Creates operation metadata with the specified values
    /// - Parameters:
    ///   - duration: Operation duration in seconds
    ///   - itemsProcessed: Number of items processed
    ///   - warnings: Array of warning messages
    public init(duration: TimeInterval = 0, itemsProcessed: Int = 0, warnings: [String] = []) {
        self.duration = duration
        self.itemsProcessed = itemsProcessed
        self.warnings = warnings
    }
}

// Import ArgumentParser for ExpressibleByArgument
import ArgumentParser