import Foundation

// MARK: - Structured Error Hierarchy

/// Root error type for all ContactScrubby operations
enum ContactError: LocalizedError, Equatable, Sendable {
    case analysis(AnalysisError)
    case export(ExportError)
    case import(ImportError)
    case permission(PermissionError)
    case configuration(ConfigurationError)
    case system(SystemError)
    
    var errorDescription: String? {
        switch self {
        case .analysis(let error): return error.errorDescription
        case .export(let error): return error.errorDescription
        case .import(let error): return error.errorDescription
        case .permission(let error): return error.errorDescription
        case .configuration(let error): return error.errorDescription
        case .system(let error): return error.errorDescription
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .analysis(let error): return error.recoverySuggestion
        case .export(let error): return error.recoverySuggestion
        case .import(let error): return error.recoverySuggestion
        case .permission(let error): return error.recoverySuggestion
        case .configuration(let error): return error.recoverySuggestion
        case .system(let error): return error.recoverySuggestion
        }
    }
}

// MARK: - Analysis Errors

enum AnalysisError: LocalizedError, Equatable, Sendable {
    case contactLoadFailed(reason: String)
    case analysisTimeout
    case invalidContact(ContactID)
    case scoringFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .contactLoadFailed(let reason):
            return "Failed to load contact: \(reason)"
        case .analysisTimeout:
            return "Contact analysis timed out"
        case .invalidContact(let id):
            return "Invalid contact: \(id.value)"
        case .scoringFailed(let reason):
            return "Scoring failed: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .contactLoadFailed:
            return "Check contact permissions and try again"
        case .analysisTimeout:
            return "Reduce the number of contacts or increase timeout"
        case .invalidContact:
            return "Verify the contact exists and is accessible"
        case .scoringFailed:
            return "Check scoring configuration and contact data"
        }
    }
}

// MARK: - Export Errors

enum ExportError: LocalizedError, Equatable, Sendable {
    case unsupportedFormat(ExportFormat)
    case fileWriteFailed(path: String, underlying: String)
    case invalidDestination(String)
    case serializationFailed(reason: String)
    case imageExportFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "Unsupported export format: \(format.rawValue)"
        case .fileWriteFailed(let path, let underlying):
            return "Failed to write file \(path): \(underlying)"
        case .invalidDestination(let dest):
            return "Invalid destination: \(dest)"
        case .serializationFailed(let reason):
            return "Serialization failed: \(reason)"
        case .imageExportFailed(let reason):
            return "Image export failed: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .unsupportedFormat:
            return "Use json, xml, or vcf format"
        case .fileWriteFailed:
            return "Check file permissions and available disk space"
        case .invalidDestination:
            return "Provide a valid file path or 'contacts'"
        case .serializationFailed:
            return "Verify contact data integrity"
        case .imageExportFailed:
            return "Check image data and destination folder permissions"
        }
    }
}

// MARK: - Import Errors

enum ImportError: LocalizedError, Equatable, Sendable {
    case fileNotFound(String)
    case unsupportedFormat(String)
    case parseError(line: Int?, reason: String)
    case invalidData(field: String, value: String)
    case contactCreationFailed(name: String, reason: String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .unsupportedFormat(let format):
            return "Unsupported format: \(format)"
        case .parseError(let line, let reason):
            if let line = line {
                return "Parse error at line \(line): \(reason)"
            } else {
                return "Parse error: \(reason)"
            }
        case .invalidData(let field, let value):
            return "Invalid \(field): \(value)"
        case .contactCreationFailed(let name, let reason):
            return "Failed to create contact '\(name)': \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "Check the file path and ensure the file exists"
        case .unsupportedFormat:
            return "Use json, xml, or vcf format"
        case .parseError:
            return "Verify the file format and fix any syntax errors"
        case .invalidData:
            return "Check the data format and ensure all required fields are present"
        case .contactCreationFailed:
            return "Verify contact data and check system permissions"
        }
    }
}

// MARK: - Permission Errors

enum PermissionError: LocalizedError, Equatable, Sendable {
    case contactsAccessDenied
    case fileSystemAccessDenied(path: String)
    case networkAccessDenied
    
    var errorDescription: String? {
        switch self {
        case .contactsAccessDenied:
            return "Access to Contacts was denied"
        case .fileSystemAccessDenied(let path):
            return "File system access denied for: \(path)"
        case .networkAccessDenied:
            return "Network access denied"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .contactsAccessDenied:
            return "Grant permission in System Preferences > Security & Privacy > Privacy > Contacts"
        case .fileSystemAccessDenied:
            return "Check file permissions and ensure the application has access to the specified path"
        case .networkAccessDenied:
            return "Check network permissions and firewall settings"
        }
    }
}

// MARK: - Configuration Errors

enum ConfigurationError: LocalizedError, Equatable, Sendable {
    case invalidFilterMode(String)
    case invalidDubiousScore(Int)
    case invalidImageMode(String)
    case missingRequiredOption(String)
    case conflictingOptions([String])
    
    var errorDescription: String? {
        switch self {
        case .invalidFilterMode(let mode):
            return "Invalid filter mode: \(mode)"
        case .invalidDubiousScore(let score):
            return "Invalid dubious score: \(score)"
        case .invalidImageMode(let mode):
            return "Invalid image mode: \(mode)"
        case .missingRequiredOption(let option):
            return "Missing required option: \(option)"
        case .conflictingOptions(let options):
            return "Conflicting options: \(options.joined(separator: ", "))"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidFilterMode:
            return "Use one of: with-email, no-email, facebook, facebook-exclusive, dubious, all, no-contact"
        case .invalidDubiousScore:
            return "Use a score between 1 and 10"
        case .invalidImageMode:
            return "Use one of: none, inline, folder"
        case .missingRequiredOption:
            return "Provide the required option"
        case .conflictingOptions:
            return "Choose only one of the conflicting options"
        }
    }
}

// MARK: - System Errors

enum SystemError: LocalizedError, Equatable, Sendable {
    case memoryExhausted
    case operationTimeout
    case internalError(String)
    case dependencyUnavailable(String)
    
    var errorDescription: String? {
        switch self {
        case .memoryExhausted:
            return "Operation failed due to insufficient memory"
        case .operationTimeout:
            return "Operation timed out"
        case .internalError(let message):
            return "Internal error: \(message)"
        case .dependencyUnavailable(let dependency):
            return "Required dependency unavailable: \(dependency)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .memoryExhausted:
            return "Try processing fewer contacts at once or close other applications"
        case .operationTimeout:
            return "Increase timeout or reduce operation scope"
        case .internalError:
            return "Please report this error to the developers"
        case .dependencyUnavailable:
            return "Ensure all required system components are available"
        }
    }
}

// MARK: - Result Type Extensions

extension Result where Failure == ContactError {
    /// Convert to OperationResult with metadata
    func withMetadata(_ metadata: OperationMetadata) -> Result<OperationResult<Success>, ContactError> {
        map { OperationResult($0, metadata: metadata) }
    }
    
    /// Add context to error
    func mapError(context: String) -> Result<Success, ContactError> {
        mapError { error in
            switch error {
            case .system(let systemError):
                return .system(.internalError("\(context): \(systemError.localizedDescription)"))
            default:
                return error
            }
        }
    }
}