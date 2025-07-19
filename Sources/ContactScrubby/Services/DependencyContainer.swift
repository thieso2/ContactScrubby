import Foundation

/// Dependency injection container for managing application services
public final class DependencyContainer: ObservableObject {
    
    // MARK: - Core Services
    
    public lazy var contactAnalyzer: ContactAnalyzing = {
        DefaultContactAnalyzer(configuration: configuration.analysis)
    }()
    
    public lazy var contactFilter: ContactFiltering = {
        DefaultContactFilter()
    }()
    
    public lazy var contactExporter: ContactExporting = {
        DefaultContactExporter()
    }()
    
    public lazy var contactImporter: ContactImporting = {
        DefaultContactImporter()
    }()
    
    // MARK: - Configuration
    
    public lazy var configuration: ApplicationConfiguration = {
        DefaultApplicationConfiguration()
    }()
    
    // MARK: - Utilities
    
    public lazy var logger: Logging? = {
        guard configuration.logging.enableConsole || configuration.logging.enableFile else {
            return nil
        }
        return DefaultLogger(configuration: configuration.logging)
    }()
    
    public lazy var progressReporter: ProgressReporting = {
        ConsoleProgressReporter()
    }()
    
    // MARK: - Initialization
    
    public init() {
        // Dependency injection setup is handled lazily
    }
    
    // MARK: - Factory Methods
    
    @MainActor
    public func makeContactManager() -> ContactManaging {
        ModernContactsManager(
            analyzer: contactAnalyzer,
            filter: contactFilter,
            configuration: configuration.contacts,
            logger: logger
        )
    }
    
    public func makeOperationCoordinator() -> OperationCoordinator {
        OperationCoordinator(
            container: self,
            exporter: contactExporter,
            importer: contactImporter,
            analyzer: contactAnalyzer,
            filter: contactFilter,
            progressReporter: progressReporter,
            logger: logger
        )
    }
    
    public func makeExportConfiguration(format: ExportFormat, imageStrategy: ImageExportStrategy = .none) -> ExportConfiguration {
        ExportConfiguration(
            format: format,
            imageStrategy: imageStrategy,
            includeMetadata: true,
            customFields: []
        )
    }
    
    public func makeContactFilter(mode: FilterMode, dubiousScore: Int = 3) -> ContactFilter {
        ContactFilter(mode: mode, dubiousScore: dubiousScore)
    }
}

// MARK: - Default Application Configuration

public struct DefaultApplicationConfiguration: ApplicationConfiguration {
    public let contacts = ContactConfiguration.default
    public let export = ExportConfiguration.default
    public let analysis = AnalysisConfiguration.default
    public let logging = LoggingConfiguration.default
    
    public init() {}
}

// MARK: - Default Logger

public struct DefaultLogger: Logging {
    private let configuration: LoggingConfiguration
    private nonisolated(unsafe) let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    public init(configuration: LoggingConfiguration) {
        self.configuration = configuration
    }
    
    public func log(level: LogLevel, message: String, context: [String : Any]) {
        guard level >= configuration.level else { return }
        
        let timestamp = dateFormatter.string(from: Date())
        let contextString = formatContext(context)
        let logMessage = "[\(timestamp)] [\(level.rawValue.uppercased())] \(message)\(contextString)"
        
        if configuration.enableConsole {
            print(logMessage)
        }
        
        if configuration.enableFile, let filePath = configuration.filePath {
            writeToFile(logMessage, path: filePath)
        }
    }
    
    private func formatContext(_ context: [String: Any]) -> String {
        guard !context.isEmpty else { return "" }
        
        let contextPairs = context.map { key, value in
            "\(key)=\(value)"
        }.joined(separator: ", ")
        
        return " [\(contextPairs)]"
    }
    
    private func writeToFile(_ message: String, path: String) {
        let url = URL(fileURLWithPath: path)
        
        do {
            let data = (message + "\n").data(using: .utf8) ?? Data()
            
            if FileManager.default.fileExists(atPath: path) {
                let fileHandle = try FileHandle(forWritingTo: url)
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            } else {
                try data.write(to: url)
            }
        } catch {
            // Fallback to console if file writing fails
            if configuration.enableConsole {
                print("Failed to write to log file: \(error)")
            }
        }
    }
}

// MARK: - Console Progress Reporter

public struct ConsoleProgressReporter: ProgressReporting {
    public init() {}
    
    public func reportProgress(_ progress: OperationProgress) {
        let percentage = String(format: "%.1f", progress.percentage)
        let message = progress.message.map { " - \($0)" } ?? ""
        print("[\(progress.phase)] \(progress.current)/\(progress.total) (\(percentage)%)\(message)")
    }
}

// MARK: - Operation Coordinator

/// Coordinates complex operations across multiple services
public final class OperationCoordinator {
    
    // MARK: - Dependencies
    
    private weak var container: DependencyContainer?
    private let exporter: ContactExporting
    private let importer: ContactImporting
    private let analyzer: ContactAnalyzing
    private let filter: ContactFiltering
    private let progressReporter: ProgressReporting
    private let logger: Logging?
    
    // MARK: - Initialization
    
    public init(
        container: DependencyContainer,
        exporter: ContactExporting,
        importer: ContactImporting,
        analyzer: ContactAnalyzing,
        filter: ContactFiltering,
        progressReporter: ProgressReporting,
        logger: Logging?
    ) {
        self.container = container
        self.exporter = exporter
        self.importer = importer
        self.analyzer = analyzer
        self.filter = filter
        self.progressReporter = progressReporter
        self.logger = logger
    }
    
    // MARK: - High-Level Operations
    
    public func executeExportOperation(
        filter: ContactFilter,
        destination: ExportDestination,
        configuration: ExportConfiguration
    ) async -> Result<ExportResult, ContactError> {
        
        logger?.log(level: .info, message: "Starting export operation", context: [
            "filter": filter.mode.rawValue,
            "format": configuration.format.rawValue
        ])
        
        // Step 1: Request access if needed
        progressReporter.reportProgress(OperationProgress(
            current: 1, total: 4, phase: "Setup", message: "Requesting contacts access"
        ))
        
        guard let container = container else {
            return .failure(.system(.internalError("Container not available")))
        }
        
        let contactManager = await container.makeContactManager()
        
        do {
            let accessGranted = try await contactManager.requestAccess()
            guard accessGranted else {
                return .failure(.permission(.contactsAccessDenied))
            }
        } catch {
            return .failure(.permission(.contactsAccessDenied))
        }
        
        // Step 2: Load and filter contacts
        progressReporter.reportProgress(OperationProgress(
            current: 2, total: 4, phase: "Loading", message: "Loading contacts"
        ))
        
        let contactsResult = await contactManager.loadContacts(filter: filter)
        let contacts: [Contact]
        
        switch contactsResult {
        case .success(let loadedContacts):
            contacts = loadedContacts
        case .failure(let error):
            logger?.log(level: .error, message: "Failed to load contacts", context: ["error": error.localizedDescription])
            return .failure(error)
        }
        
        guard !contacts.isEmpty else {
            logger?.log(level: .warning, message: "No contacts found matching filter", context: [:])
            return .success(ExportResult(itemsExported: 0, warnings: ["No contacts found"], duration: 0, outputPath: nil))
        }
        
        // Step 3: Validate export configuration
        progressReporter.reportProgress(OperationProgress(
            current: 3, total: 4, phase: "Validation", message: "Validating export configuration"
        ))
        
        let validationResult = exporter.validateConfiguration(configuration)
        guard case .success = validationResult else {
            if case .failure(let error) = validationResult {
                return .failure(error)
            }
            return .failure(.export(.serializationFailed("Configuration validation failed")))
        }
        
        // Step 4: Export contacts
        progressReporter.reportProgress(OperationProgress(
            current: 4, total: 4, phase: "Export", message: "Exporting \(contacts.count) contacts"
        ))
        
        let exportResult = await exporter.export(contacts, to: destination, configuration: configuration)
        
        switch exportResult {
        case .success(let result):
            logger?.log(level: .info, message: "Export completed successfully", context: [
                "itemsExported": result.itemsExported,
                "duration": result.duration
            ])
            return .success(result)
        case .failure(let error):
            logger?.log(level: .error, message: "Export failed", context: ["error": error.localizedDescription])
            return .failure(error)
        }
    }
    
    public func executeImportOperation(
        source: ImportSource,
        createInContacts: Bool = false
    ) async -> Result<ImportResult, ContactError> {
        
        logger?.log(level: .info, message: "Starting import operation", context: [
            "createInContacts": createInContacts
        ])
        
        // Step 1: Validate source
        progressReporter.reportProgress(OperationProgress(
            current: 1, total: 3, phase: "Validation", message: "Validating import source"
        ))
        
        let validationResult = await importer.validateSource(source)
        guard case .success = validationResult else {
            if case .failure(let error) = validationResult {
                return .failure(error)
            }
            return .failure(.importing(.invalidData("Source validation failed")))
        }
        
        // Step 2: Import contacts
        progressReporter.reportProgress(OperationProgress(
            current: 2, total: 3, phase: "Import", message: "Importing contacts"
        ))
        
        let importResult = await importer.importContacts(from: source)
        let contacts: [Contact]
        
        switch importResult {
        case .success(let result):
            contacts = result.contacts
            logger?.log(level: .info, message: "Import completed", context: [
                "itemsImported": result.itemsImported,
                "itemsFailed": result.itemsFailed
            ])
        case .failure(let error):
            logger?.log(level: .error, message: "Import failed", context: ["error": error.localizedDescription])
            return .failure(error)
        }
        
        // Step 3: Create in contacts if requested
        if createInContacts && !contacts.isEmpty {
            progressReporter.reportProgress(OperationProgress(
                current: 3, total: 3, phase: "Create", message: "Creating contacts in database"
            ))
            
            guard let container = container else {
                return .failure(.system(.internalError("Container not available")))
            }
            
            let contactManager = await container.makeContactManager()
            
            do {
                let accessGranted = try await contactManager.requestAccess()
                guard accessGranted else {
                    return .failure(.permission(.contactsAccessDenied))
                }
                
                var successCount = 0
                var errorMessages: [String] = []
                
                for contact in contacts {
                    let createResult = await contactManager.createContact(contact)
                    switch createResult {
                    case .success:
                        successCount += 1
                    case .failure(let error):
                        errorMessages.append("Failed to create \(contact.name): \(error.localizedDescription)")
                    }
                }
                
                logger?.log(level: .info, message: "Created \(successCount) contacts", context: [:])
                
                let finalResult = ImportResult(
                    contacts: contacts,
                    itemsImported: successCount,
                    itemsFailed: contacts.count - successCount,
                    errors: errorMessages,
                    duration: importResult.isSuccess ? importResult.value!.duration : 0
                )
                
                return .success(finalResult)
                
            } catch {
                return .failure(.permission(.contactsAccessDenied))
            }
        } else {
            return importResult
        }
    }
    
    public func executeAnalysisOperation(filter: ContactFilter) async -> Result<[ContactAnalysis], ContactError> {
        logger?.log(level: .info, message: "Starting analysis operation", context: [
            "filter": filter.mode.rawValue,
            "dubiousScore": filter.dubiousScore
        ])
        
        // Step 1: Request access
        progressReporter.reportProgress(OperationProgress(
            current: 1, total: 3, phase: "Setup", message: "Requesting contacts access"
        ))
        
        guard let container = container else {
            return .failure(.system(.internalError("Container not available")))
        }
        
        let contactManager = await container.makeContactManager()
        
        do {
            let accessGranted = try await contactManager.requestAccess()
            guard accessGranted else {
                return .failure(.permission(.contactsAccessDenied))
            }
        } catch {
            return .failure(.permission(.contactsAccessDenied))
        }
        
        // Step 2: Load contacts
        progressReporter.reportProgress(OperationProgress(
            current: 2, total: 3, phase: "Loading", message: "Loading contacts"
        ))
        
        let contactsResult = await contactManager.loadContacts(filter: filter)
        let contacts: [Contact]
        
        switch contactsResult {
        case .success(let loadedContacts):
            contacts = loadedContacts
        case .failure(let error):
            return .failure(error)
        }
        
        // Step 3: Analyze contacts
        progressReporter.reportProgress(OperationProgress(
            current: 3, total: 3, phase: "Analysis", message: "Analyzing \(contacts.count) contacts"
        ))
        
        let analysisResult = await analyzer.analyzeContacts(contacts)
        
        switch analysisResult {
        case .success(let analyses):
            logger?.log(level: .info, message: "Analysis completed", context: [
                "totalContacts": analyses.count,
                "dubiousContacts": analyses.filter { $0.isDubious(minimumScore: filter.dubiousScore) }.count
            ])
            return .success(analyses)
        case .failure(let error):
            logger?.log(level: .error, message: "Analysis failed", context: ["error": error.localizedDescription])
            return .failure(error)
        }
    }
}

// MARK: - Result Extension

extension Result {
    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
    
    var value: Success? {
        switch self {
        case .success(let value): return value
        case .failure: return nil
        }
    }
}