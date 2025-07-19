import Foundation

// MARK: - Main Error Type

/// Comprehensive error type for the ContactScrubby application
public enum ContactError: LocalizedError, Equatable, Sendable {
    case analysis(AnalysisError)
    case export(ExportError)
    case importing(ImportError)
    case permission(PermissionError)
    case configuration(ConfigurationError)
    case system(SystemError)
    
    public var errorDescription: String? {
        switch self {
        case .analysis(let error): return error.errorDescription
        case .export(let error): return error.errorDescription
        case .importing(let error): return error.errorDescription
        case .permission(let error): return error.errorDescription
        case .configuration(let error): return error.errorDescription
        case .system(let error): return error.errorDescription
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .analysis(let error): return error.recoverySuggestion
        case .export(let error): return error.recoverySuggestion
        case .importing(let error): return error.recoverySuggestion
        case .permission(let error): return error.recoverySuggestion
        case .configuration(let error): return error.recoverySuggestion
        case .system(let error): return error.recoverySuggestion
        }
    }
}

// MARK: - Specific Error Types

public enum AnalysisError: LocalizedError, Equatable, Sendable {
    case contactNotFound(ContactID)
    case analysisTimeout(ContactID)
    case invalidContact(String)
    case scoringFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .contactNotFound(let id):
            return "Contact with ID '\(id.value)' not found"
        case .analysisTimeout(let id):
            return "Analysis timed out for contact '\(id.value)'"
        case .invalidContact(let reason):
            return "Invalid contact: \(reason)"
        case .scoringFailed(let reason):
            return "Contact scoring failed: \(reason)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .contactNotFound:
            return "Verify the contact ID is correct and the contact exists"
        case .analysisTimeout:
            return "Try increasing the analysis timeout in configuration"
        case .invalidContact:
            return "Check the contact data format and required fields"
        case .scoringFailed:
            return "Review scoring configuration and contact data quality"
        }
    }
}

public enum ExportError: LocalizedError, Equatable, Sendable {
    case unsupportedFormat(ExportFormat)
    case fileWriteFailed(path: String, underlying: String)
    case invalidDestination(String)
    case serializationFailed(String)
    case imageProcessingFailed(String)
    case permissionDenied(String)
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "Export format '\(format.rawValue)' is not supported"
        case .fileWriteFailed(let path, let underlying):
            return "Failed to write file at '\(path)': \(underlying)"
        case .invalidDestination(let destination):
            return "Invalid export destination: \(destination)"
        case .serializationFailed(let reason):
            return "Data serialization failed: \(reason)"
        case .imageProcessingFailed(let reason):
            return "Image processing failed: \(reason)"
        case .permissionDenied(let path):
            return "Permission denied for path: \(path)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .unsupportedFormat:
            return "Use a supported format: json, xml, or vcf"
        case .fileWriteFailed:
            return "Check file permissions and available disk space"
        case .invalidDestination:
            return "Provide a valid file path or URL"
        case .serializationFailed:
            return "Verify contact data is complete and valid"
        case .imageProcessingFailed:
            return "Check image data format and try a different strategy"
        case .permissionDenied:
            return "Choose a different location or check file permissions"
        }
    }
}

public enum ImportError: LocalizedError, Equatable, Sendable {
    case fileNotFound(String)
    case unsupportedFormat(ExportFormat)
    case parsingFailed(String)
    case invalidData(String)
    case partialImport(imported: Int, failed: Int, errors: [String])
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .unsupportedFormat(let format):
            return "Import format '\(format.rawValue)' is not supported"
        case .parsingFailed(let reason):
            return "Failed to parse import data: \(reason)"
        case .invalidData(let reason):
            return "Invalid import data: \(reason)"
        case .partialImport(let imported, let failed, _):
            return "Partial import: \(imported) succeeded, \(failed) failed"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "Check the file path and ensure the file exists"
        case .unsupportedFormat:
            return "Use a supported format: json, xml, or vcf"
        case .parsingFailed:
            return "Verify the file format and data structure"
        case .invalidData:
            return "Check the data format and required fields"
        case .partialImport:
            return "Review failed items and fix data issues before retrying"
        }
    }
}

public enum PermissionError: LocalizedError, Equatable, Sendable {
    case contactsAccessDenied
    case contactsAccessRestricted
    case fileSystemPermissionDenied(String)
    
    public var errorDescription: String? {
        switch self {
        case .contactsAccessDenied:
            return "Access to Contacts was denied"
        case .contactsAccessRestricted:
            return "Access to Contacts is restricted"
        case .fileSystemPermissionDenied(let path):
            return "File system permission denied for: \(path)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .contactsAccessDenied:
            return "Grant permission in System Preferences > Security & Privacy > Privacy > Contacts"
        case .contactsAccessRestricted:
            return "Contact your system administrator to remove restrictions"
        case .fileSystemPermissionDenied:
            return "Choose a different location or modify file permissions"
        }
    }
}

public enum ConfigurationError: LocalizedError, Equatable, Sendable {
    case invalidDubiousScore(Int)
    case invalidTimeout(TimeInterval)
    case invalidBatchSize(Int)
    case missingRequiredField(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidDubiousScore(let score):
            return "Invalid dubious score: \(score)"
        case .invalidTimeout(let timeout):
            return "Invalid timeout: \(timeout)"
        case .invalidBatchSize(let size):
            return "Invalid batch size: \(size)"
        case .missingRequiredField(let field):
            return "Missing required configuration field: \(field)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .invalidDubiousScore:
            return "Use a positive integer between 1 and 10"
        case .invalidTimeout:
            return "Use a positive timeout value in seconds"
        case .invalidBatchSize:
            return "Use a positive batch size between 1 and 1000"
        case .missingRequiredField:
            return "Provide the required configuration field"
        }
    }
}

public enum SystemError: LocalizedError, Equatable, Sendable {
    case memoryPressure
    case diskSpaceLow
    case networkUnavailable
    case operationCancelled
    case internalError(String)
    
    public var errorDescription: String? {
        switch self {
        case .memoryPressure:
            return "System is under memory pressure"
        case .diskSpaceLow:
            return "Insufficient disk space"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .operationCancelled:
            return "Operation was cancelled"
        case .internalError(let reason):
            return "Internal error: \(reason)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .memoryPressure:
            return "Close other applications to free up memory"
        case .diskSpaceLow:
            return "Free up disk space and try again"
        case .networkUnavailable:
            return "Check your network connection"
        case .operationCancelled:
            return "Retry the operation if needed"
        case .internalError:
            return "Report this issue with details about what you were doing"
        }
    }
}

// MARK: - Result Extensions

extension Result where Failure == ContactError, Success: Sendable {
    /// Add metadata to successful results
    public func withMetadata(_ metadata: OperationMetadata) -> Result<OperationResult<Success>, ContactError> {
        switch self {
        case .success(let value):
            return .success(OperationResult(value, metadata: metadata))
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// Map error with additional context
    public func mapError(context: String) -> Result<Success, ContactError> {
        switch self {
        case .success(let value):
            return .success(value)
        case .failure(let error):
            // In a real implementation, we could enhance the error with context
            return .failure(error)
        }
    }
}