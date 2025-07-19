import Foundation
import Contacts

// MARK: - Core Service Protocols

/// Protocol for managing contact operations
@MainActor
protocol ContactManaging: Sendable {
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
protocol ContactAnalyzing: Sendable {
    /// Analyze a single contact
    func analyze(_ contact: Contact) async -> Result<ContactAnalysis, ContactError>
    
    /// Analyze multiple contacts
    func analyzeContacts(_ contacts: [Contact]) async -> Result<[ContactAnalysis], ContactError>
    
    /// Get contacts that match dubious criteria
    func getDubiousContacts(minimumScore: Int, from contacts: [Contact]) async -> Result<[ContactAnalysis], ContactError>
}

/// Protocol for contact export operations
protocol ContactExporting: Sendable {
    /// Supported export formats
    var supportedFormats: [ExportFormat] { get }
    
    /// Export contacts to a destination
    func export(_ contacts: [Contact], to destination: ExportDestination, configuration: ExportConfiguration) async -> Result<ExportResult, ContactError>
    
    /// Validate export configuration
    func validateConfiguration(_ configuration: ExportConfiguration) -> Result<Void, ContactError>
}

/// Protocol for contact import operations
protocol ContactImporting: Sendable {
    /// Supported import formats
    var supportedFormats: [ExportFormat] { get }
    
    /// Import contacts from a source
    func importContacts(from source: ImportSource) async -> Result<ImportResult, ContactError>
    
    /// Validate import source
    func validateSource(_ source: ImportSource) async -> Result<Void, ContactError>
}

/// Protocol for contact filtering operations
protocol ContactFiltering: Sendable {
    /// Apply filter to contacts
    func filter(_ contacts: [Contact], using filter: ContactFilter) async -> Result<[Contact], ContactError>
    
    /// Validate filter configuration
    func validateFilter(_ filter: ContactFilter) -> Result<Void, ContactError>
}

// MARK: - Data Source Protocols

/// Protocol for contact data sources
protocol ContactDataSource: Sendable {
    /// Load contacts from the source
    func loadContacts() async -> Result<[Contact], ContactError>
    
    /// Check if source is available
    func isAvailable() async -> Bool
}

/// Protocol for contact data destinations
protocol ContactDataDestination: Sendable {
    /// Save contacts to the destination
    func saveContacts(_ contacts: [Contact]) async -> Result<Void, ContactError>
    
    /// Check if destination is writable
    func isWritable() async -> Bool
}

// MARK: - Configuration Protocols

/// Protocol for application configuration
protocol ApplicationConfiguration: Sendable {
    var contacts: ContactConfiguration { get }
    var export: ExportConfiguration { get }
    var analysis: AnalysisConfiguration { get }
    var logging: LoggingConfiguration { get }
}

/// Protocol for validation
protocol Validatable {
    func validate() -> Result<Void, ContactError>
}

// MARK: - Observer Protocols

/// Protocol for operation progress reporting
protocol ProgressReporting: Sendable {
    func reportProgress(_ progress: OperationProgress)
}

/// Protocol for logging operations
protocol Logging: Sendable {
    func log(level: LogLevel, message: String, context: [String: Any])
}

// MARK: - Data Models

/// Unified contact model
struct Contact: Sendable, Identifiable, Equatable {
    let id: ContactID
    @Sanitized(.filename) var name: String
    var nameComponents: NameComponents
    @Validated(.email) var emails: [LabeledValue<String>]
    @Validated(.notEmpty) var phones: [LabeledValue<String>]
    var addresses: [LabeledAddress]
    var urls: [LabeledValue<String>]
    var socialProfiles: [SocialProfile]
    var instantMessages: [InstantMessage]
    var birthday: DateComponents?
    var dates: [LabeledDate]
    var organizationName: String?
    var jobTitle: String?
    var note: String?
    var imageData: Data?
    var contactType: ContactType
    
    init(id: ContactID = ContactID(UUID().uuidString), name: String) {
        self.id = id
        self._name = Sanitized(wrappedValue: name, .filename)
        self.nameComponents = NameComponents()
        self._emails = Validated(wrappedValue: [], .email)
        self._phones = Validated(wrappedValue: [], .notEmpty)
        self.addresses = []
        self.urls = []
        self.socialProfiles = []
        self.instantMessages = []
        self.dates = []
        self.contactType = .person
    }
}

/// Contact name components
struct NameComponents: Sendable, Equatable {
    var prefix: String?
    var given: String?
    var middle: String?
    var family: String?
    var suffix: String?
    var nickname: String?
    var phoneticGiven: String?
    var phoneticMiddle: String?
    var phoneticFamily: String?
}

/// Labeled value with type safety
struct LabeledValue<T: Sendable & Equatable>: Sendable, Equatable {
    let label: ContactLabel?
    let value: T
    
    init(label: ContactLabel? = nil, value: T) {
        self.label = label
        self.value = value
    }
}

/// Labeled address
struct LabeledAddress: Sendable, Equatable {
    let label: ContactLabel?
    let street: String?
    let city: String?
    let state: String?
    let postalCode: String?
    let country: String?
    
    init(label: ContactLabel? = nil, street: String? = nil, city: String? = nil, 
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
struct SocialProfile: Sendable, Equatable {
    let label: ContactLabel?
    let service: String
    let username: String
}

/// Instant message
struct InstantMessage: Sendable, Equatable {
    let label: ContactLabel?
    let service: String
    let username: String
}

/// Labeled date
struct LabeledDate: Sendable, Equatable {
    let label: String?
    let date: DateComponents
}

/// Contact type
enum ContactType: String, Sendable, CaseIterable {
    case person = "Person"
    case organization = "Organization"
}

// MARK: - Filter Types

/// Contact filter configuration
struct ContactFilter: Sendable, Equatable {
    let mode: FilterMode
    let dubiousScore: Int
    let customPredicate: String? // For advanced filtering
    
    init(mode: FilterMode, dubiousScore: Int = 3, customPredicate: String? = nil) {
        self.mode = mode
        self.dubiousScore = dubiousScore
        self.customPredicate = customPredicate
    }
}

/// Filter modes
enum FilterMode: String, CaseIterable, Sendable {
    case all = "all"
    case withEmail = "with-email"
    case withoutEmail = "no-email"
    case facebookOnly = "facebook"
    case facebookExclusive = "facebook-exclusive"
    case dubious = "dubious"
    case noContact = "no-contact"
    
    var description: String {
        switch self {
        case .all: return "All contacts"
        case .withEmail: return "Contacts with email addresses"
        case .withoutEmail: return "Contacts without email addresses"
        case .facebookOnly: return "Contacts with @facebook.com email addresses"
        case .facebookExclusive: return "Contacts with ONLY @facebook.com emails and no phones"
        case .dubious: return "Dubious/incomplete contacts (likely auto-imports)"
        case .noContact: return "Contacts with no email AND no phone"
        }
    }
}

// MARK: - Analysis Types

/// Contact analysis result
struct ContactAnalysis: Sendable, Identifiable, Equatable {
    let id: ContactID
    let contact: Contact
    let dubiousScore: Int
    let reasons: [String]
    let isIncomplete: Bool
    let isSuspicious: Bool
    let confidence: Double
    let metadata: [String: String]
    
    func isDubious(minimumScore: Int = 3) -> Bool {
        dubiousScore >= minimumScore
    }
}

// MARK: - Configuration Types

/// Contact management configuration
struct ContactConfiguration: Sendable, Validatable {
    let batchSize: Int
    let timeout: TimeInterval
    let enableCaching: Bool
    
    func validate() -> Result<Void, ContactError> {
        guard batchSize > 0 else {
            return .failure(.configuration(.invalidDubiousScore(batchSize)))
        }
        guard timeout > 0 else {
            return .failure(.configuration(.invalidDubiousScore(Int(timeout))))
        }
        return .success(())
    }
}

/// Export configuration
struct ExportConfiguration: Sendable, Validatable {
    let format: ExportFormat
    let imageStrategy: ImageExportStrategy
    let includeMetadata: Bool
    let customFields: [String]
    
    func validate() -> Result<Void, ContactError> {
        // Validation logic here
        return .success(())
    }
}

/// Analysis configuration
struct AnalysisConfiguration: Sendable, Validatable {
    let enableCaching: Bool
    let scoringWeights: ScoringWeights
    let timeoutPerContact: TimeInterval
    
    func validate() -> Result<Void, ContactError> {
        guard timeoutPerContact > 0 else {
            return .failure(.configuration(.invalidDubiousScore(Int(timeoutPerContact))))
        }
        return .success(())
    }
}

/// Scoring weights for contact analysis
struct ScoringWeights: Sendable {
    let noName: Int
    let shortName: Int
    let genericName: Int
    let missingInfo: Int
    let facebookOnly: Int
    let suspiciousPhone: Int
    
    static let `default` = ScoringWeights(
        noName: 2,
        shortName: 2, 
        genericName: 3,
        missingInfo: 1,
        facebookOnly: 3,
        suspiciousPhone: 2
    )
}

/// Logging configuration
struct LoggingConfiguration: Sendable {
    let level: LogLevel
    let enableConsole: Bool
    let enableFile: Bool
    let filePath: String?
}

/// Log levels
enum LogLevel: String, CaseIterable, Sendable, Comparable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
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
enum ImportSource: Sendable, Equatable {
    case contacts
    case file(path: String, format: ExportFormat)
    case url(URL, format: ExportFormat)
}

/// Export destination
enum ExportDestination: Sendable, Equatable {
    case contacts
    case file(path: String)
    case url(URL)
}

/// Export result
struct ExportResult: Sendable {
    let itemsExported: Int
    let warnings: [String]
    let duration: TimeInterval
    let outputPath: String?
}

/// Import result
struct ImportResult: Sendable {
    let contacts: [Contact]
    let itemsImported: Int
    let itemsFailed: Int
    let errors: [String]
    let duration: TimeInterval
}

/// Operation progress
struct OperationProgress: Sendable {
    let current: Int
    let total: Int
    let phase: String
    let message: String?
    
    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total) * 100
    }
}