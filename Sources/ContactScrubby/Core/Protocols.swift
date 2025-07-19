import Foundation
import Contacts

// MARK: - Core Service Protocols

/// Protocol for managing contact operations
@MainActor
public protocol ContactManaging: Sendable {
    /// Request access to contacts
    func requestAccess() async throws -> Bool
    
    /// Load contacts with filtering
    func loadContacts(filter: ContactFilter) async -> Result<[Contact], ContactError>
    
    /// Create a new contact
    func createContact(_ contact: Contact) async -> Result<ContactID, ContactError>
    
    /// Delete a contact
    func deleteContact(id: ContactID) async -> Result<Void, ContactError>
    
    /// Update an existing contact
    func updateContact(id: ContactID, with contact: Contact) async -> Result<Void, ContactError>
}

/// Protocol for contact analysis operations
public protocol ContactAnalyzing: Sendable {
    /// Analyze a single contact
    func analyze(_ contact: Contact) async -> Result<ContactAnalysis, ContactError>
    
    /// Analyze multiple contacts
    func analyzeContacts(_ contacts: [Contact]) async -> Result<[ContactAnalysis], ContactError>
    
    /// Get contacts that match dubious criteria
    func getDubiousContacts(minimumScore: Int, from contacts: [Contact]) async -> Result<[ContactAnalysis], ContactError>
}

/// Protocol for contact export operations
public protocol ContactExporting: Sendable {
    /// Supported export formats
    var supportedFormats: [ExportFormat] { get }
    
    /// Export contacts to a destination
    func export(_ contacts: [Contact], to destination: ExportDestination, configuration: ExportConfiguration) async -> Result<ExportResult, ContactError>
    
    /// Validate export configuration
    func validateConfiguration(_ configuration: ExportConfiguration) -> Result<Void, ContactError>
}

/// Protocol for contact import operations
public protocol ContactImporting: Sendable {
    /// Supported import formats
    var supportedFormats: [ExportFormat] { get }
    
    /// Import contacts from a source
    func importContacts(from source: ImportSource) async -> Result<ImportResult, ContactError>
    
    /// Validate import source
    func validateSource(_ source: ImportSource) async -> Result<Void, ContactError>
}

/// Protocol for contact filtering operations
public protocol ContactFiltering: Sendable {
    /// Apply filter to contacts
    func filter(_ contacts: [Contact], using filter: ContactFilter) async -> Result<[Contact], ContactError>
    
    /// Validate filter configuration
    func validateFilter(_ filter: ContactFilter) -> Result<Void, ContactError>
}

// MARK: - Data Source Protocols

/// Protocol for contact data sources
public protocol ContactDataSource: Sendable {
    /// Load contacts from the source
    func loadContacts() async -> Result<[Contact], ContactError>
    
    /// Check if source is available
    func isAvailable() async -> Bool
}

/// Protocol for contact data destinations
public protocol ContactDataDestination: Sendable {
    /// Save contacts to the destination
    func saveContacts(_ contacts: [Contact]) async -> Result<Void, ContactError>
    
    /// Check if destination is writable
    func isWritable() async -> Bool
}

// MARK: - Configuration Protocols

/// Protocol for application configuration
public protocol ApplicationConfiguration: Sendable {
    var contacts: ContactConfiguration { get }
    var export: ExportConfiguration { get }
    var analysis: AnalysisConfiguration { get }
    var logging: LoggingConfiguration { get }
}

/// Protocol for validation
public protocol Validatable {
    func validate() -> Result<Void, ContactError>
}

// MARK: - Observer Protocols

/// Protocol for operation progress reporting
public protocol ProgressReporting: Sendable {
    func reportProgress(_ progress: OperationProgress)
}

/// Protocol for logging operations
public protocol Logging: Sendable {
    func log(level: LogLevel, message: String, context: [String: Any])
}

// MARK: - Data Models

/// Unified contact model
public struct Contact: Sendable, Identifiable, Equatable, Codable {
    public let id: ContactID
    public var name: String
    public var nameComponents: NameComponents
    public var emails: [LabeledValue<String>]
    public var phones: [LabeledValue<String>]
    public var addresses: [LabeledAddress]
    public var urls: [LabeledValue<String>]
    public var socialProfiles: [SocialProfile]
    public var instantMessages: [InstantMessage]
    public var birthday: DateComponents?
    public var dates: [LabeledDate]
    public var organizationName: String?
    public var jobTitle: String?
    public var note: String?
    public var imageData: Data?
    public var contactType: ContactType
    
    public init(id: ContactID = ContactID(UUID().uuidString), name: String) {
        self.id = id
        self.name = name.sanitizedForFilename()
        self.nameComponents = NameComponents()
        self.emails = []
        self.phones = []
        self.addresses = []
        self.urls = []
        self.socialProfiles = []
        self.instantMessages = []
        self.dates = []
        self.contactType = .person
    }
    
}

/// Contact name components
public struct NameComponents: Sendable, Equatable, Codable {
    public var prefix: String?
    public var given: String?
    public var middle: String?
    public var family: String?
    public var suffix: String?
    public var nickname: String?
    public var phoneticGiven: String?
    public var phoneticMiddle: String?
    public var phoneticFamily: String?
    
    public init() {}
}

/// Labeled value with type safety
public struct LabeledValue<T: Sendable & Equatable & Codable>: Sendable, Equatable, Codable {
    public let label: ContactLabel?
    public let value: T
    
    public init(label: ContactLabel? = nil, value: T) {
        self.label = label
        self.value = value
    }
}

/// Labeled address
public struct LabeledAddress: Sendable, Equatable, Codable {
    public let label: ContactLabel?
    public let street: String?
    public let city: String?
    public let state: String?
    public let postalCode: String?
    public let country: String?
    
    public init(label: ContactLabel? = nil, street: String? = nil, city: String? = nil, 
         state: String? = nil, postalCode: String? = nil, country: String? = nil) {
        self.label = label
        self.street = street
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.country = country
    }
}

/// Social profile
public struct SocialProfile: Sendable, Equatable, Codable {
    public let label: ContactLabel?
    public let service: String
    public let username: String
    
    public init(label: ContactLabel? = nil, service: String, username: String) {
        self.label = label
        self.service = service
        self.username = username
    }
}

/// Instant message
public struct InstantMessage: Sendable, Equatable, Codable {
    public let label: ContactLabel?
    public let service: String
    public let username: String
    
    public init(label: ContactLabel? = nil, service: String, username: String) {
        self.label = label
        self.service = service
        self.username = username
    }
}

/// Labeled date
public struct LabeledDate: Sendable, Equatable, Codable {
    public let label: String?
    public let date: DateComponents
    
    public init(label: String? = nil, date: DateComponents) {
        self.label = label
        self.date = date
    }
}

/// Contact type
public enum ContactType: String, Sendable, CaseIterable, Codable {
    case person = "Person"
    case organization = "Organization"
}

// MARK: - Filter Types

/// Contact filter configuration
public struct ContactFilter: Sendable, Equatable {
    public let mode: FilterMode
    public let dubiousScore: Int
    public let customPredicate: String? // For advanced filtering
    
    public init(mode: FilterMode, dubiousScore: Int = 3, customPredicate: String? = nil) {
        self.mode = mode
        self.dubiousScore = dubiousScore
        self.customPredicate = customPredicate
    }
}

// MARK: - Analysis Types

/// Contact analysis result
public struct ContactAnalysis: Sendable, Identifiable, Equatable {
    public let id: ContactID
    public let contact: Contact
    public let dubiousScore: Int
    public let reasons: [String]
    public let isIncomplete: Bool
    public let isSuspicious: Bool
    public let confidence: Double
    public let metadata: [String: String]
    
    public init(id: ContactID, contact: Contact, dubiousScore: Int, reasons: [String], 
                isIncomplete: Bool, isSuspicious: Bool, confidence: Double = 1.0, metadata: [String: String] = [:]) {
        self.id = id
        self.contact = contact
        self.dubiousScore = dubiousScore
        self.reasons = reasons
        self.isIncomplete = isIncomplete
        self.isSuspicious = isSuspicious
        self.confidence = confidence
        self.metadata = metadata
    }
    
    public func isDubious(minimumScore: Int = 3) -> Bool {
        dubiousScore >= minimumScore
    }
}

// MARK: - Configuration Types

/// Contact management configuration
public struct ContactConfiguration: Sendable, Validatable {
    public let batchSize: Int
    public let timeout: TimeInterval
    public let enableCaching: Bool
    
    public init(batchSize: Int = 100, timeout: TimeInterval = 30.0, enableCaching: Bool = true) {
        self.batchSize = batchSize
        self.timeout = timeout
        self.enableCaching = enableCaching
    }
    
    public func validate() -> Result<Void, ContactError> {
        guard batchSize > 0 else {
            return .failure(.configuration(.invalidBatchSize(batchSize)))
        }
        guard timeout > 0 else {
            return .failure(.configuration(.invalidTimeout(timeout)))
        }
        return .success(())
    }
    
    public static let `default` = ContactConfiguration()
}

/// Export configuration
public struct ExportConfiguration: Sendable, Validatable {
    public let format: ExportFormat
    public let imageStrategy: ImageExportStrategy
    public let includeMetadata: Bool
    public let customFields: [String]
    
    public init(format: ExportFormat, imageStrategy: ImageExportStrategy, includeMetadata: Bool, customFields: [String]) {
        self.format = format
        self.imageStrategy = imageStrategy
        self.includeMetadata = includeMetadata
        self.customFields = customFields
    }
    
    public func validate() -> Result<Void, ContactError> {
        // Validation logic here
        return .success(())
    }
    
    public static let `default` = ExportConfiguration(
        format: ExportFormat.json,
        imageStrategy: ImageExportStrategy.none,
        includeMetadata: true,
        customFields: []
    )
}

/// Analysis configuration
public struct AnalysisConfiguration: Sendable, Validatable {
    public let enableCaching: Bool
    public let scoringWeights: ScoringWeights
    public let timeoutPerContact: TimeInterval
    
    public init(enableCaching: Bool, scoringWeights: ScoringWeights, timeoutPerContact: TimeInterval) {
        self.enableCaching = enableCaching
        self.scoringWeights = scoringWeights
        self.timeoutPerContact = timeoutPerContact
    }
    
    public func validate() -> Result<Void, ContactError> {
        guard timeoutPerContact > 0 else {
            return .failure(.configuration(.invalidTimeout(timeoutPerContact)))
        }
        return .success(())
    }
    
    public static let `default` = AnalysisConfiguration(
        enableCaching: true,
        scoringWeights: .default,
        timeoutPerContact: 1.0
    )
}

/// Scoring weights for contact analysis
public struct ScoringWeights: Sendable {
    public let noName: Int
    public let shortName: Int
    public let genericName: Int
    public let missingInfo: Int
    public let facebookOnly: Int
    public let suspiciousPhone: Int
    
    public init(noName: Int, shortName: Int, genericName: Int, missingInfo: Int, facebookOnly: Int, suspiciousPhone: Int) {
        self.noName = noName
        self.shortName = shortName
        self.genericName = genericName
        self.missingInfo = missingInfo
        self.facebookOnly = facebookOnly
        self.suspiciousPhone = suspiciousPhone
    }
    
    public static let `default` = ScoringWeights(
        noName: 2,
        shortName: 2, 
        genericName: 3,
        missingInfo: 1,
        facebookOnly: 3,
        suspiciousPhone: 2
    )
}

/// Logging configuration
public struct LoggingConfiguration: Sendable {
    public let level: LogLevel
    public let enableConsole: Bool
    public let enableFile: Bool
    public let filePath: String?
    
    public init(level: LogLevel, enableConsole: Bool, enableFile: Bool, filePath: String?) {
        self.level = level
        self.enableConsole = enableConsole
        self.enableFile = enableFile
        self.filePath = filePath
    }
    
    public static let `default` = LoggingConfiguration(
        level: .info,
        enableConsole: true,
        enableFile: false,
        filePath: nil
    )
}

/// Log levels
public enum LogLevel: String, CaseIterable, Sendable, Comparable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        let order: [LogLevel] = [.debug, .info, .warning, .error]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

// MARK: - Operation Types

/// Import/Export source
public enum ImportSource: Sendable, Equatable {
    case contacts
    case file(path: String, format: ExportFormat)
    case url(URL, format: ExportFormat)
}

/// Export destination
public enum ExportDestination: Sendable, Equatable {
    case contacts
    case file(path: String)
    case url(URL)
}

/// Export result
public struct ExportResult: Sendable {
    public let itemsExported: Int
    public let warnings: [String]
    public let duration: TimeInterval
    public let outputPath: String?
    
    public init(itemsExported: Int, warnings: [String], duration: TimeInterval, outputPath: String?) {
        self.itemsExported = itemsExported
        self.warnings = warnings
        self.duration = duration
        self.outputPath = outputPath
    }
}

/// Import result
public struct ImportResult: Sendable {
    public let contacts: [Contact]
    public let itemsImported: Int
    public let itemsFailed: Int
    public let errors: [String]
    public let duration: TimeInterval
    
    public init(contacts: [Contact], itemsImported: Int, itemsFailed: Int, errors: [String], duration: TimeInterval) {
        self.contacts = contacts
        self.itemsImported = itemsImported
        self.itemsFailed = itemsFailed
        self.errors = errors
        self.duration = duration
    }
}

/// Operation progress
public struct OperationProgress: Sendable {
    public let current: Int
    public let total: Int
    public let phase: String
    public let message: String?
    
    public init(current: Int, total: Int, phase: String, message: String? = nil) {
        self.current = current
        self.total = total
        self.phase = phase
        self.message = message
    }
    
    public var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total) * 100
    }
}


// MARK: - ContactID Codable Support

extension ContactID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(String.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}