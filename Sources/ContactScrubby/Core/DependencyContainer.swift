import Foundation

/// Dependency injection container for managing application services
@MainActor
final class DependencyContainer: ObservableObject {
    
    // MARK: - Core Services
    
    lazy var contactManager: ContactManaging = {
        ModernContactsManager(
            analyzer: contactAnalyzer,
            filter: contactFilter,
            configuration: configuration.contacts,
            logger: logger
        )
    }()
    
    lazy var contactAnalyzer: ContactAnalyzing = {
        DefaultContactAnalyzer(configuration: configuration.analysis)
    }()
    
    lazy var contactFilter: ContactFiltering = {
        DefaultContactFilter()
    }()
    
    lazy var contactExporter: ContactExporting = {
        DefaultContactExporter()
    }()
    
    lazy var contactImporter: ContactImporting = {
        DefaultContactImporter()
    }()
    
    // MARK: - Configuration
    
    lazy var configuration: ApplicationConfiguration = {
        DefaultApplicationConfiguration()
    }()
    
    // MARK: - Utilities
    
    lazy var logger: Logging? = {
        guard configuration.logging.enableConsole || configuration.logging.enableFile else {
            return nil
        }
        return DefaultLogger(configuration: configuration.logging)
    }()
    
    lazy var progressReporter: ProgressReporting = {
        ConsoleProgressReporter()
    }()
    
    // MARK: - Initialization
    
    init() {
        // Dependency injection setup is handled lazily
    }
    
    // MARK: - Factory Methods
    
    func makeOperationCoordinator() -> OperationCoordinator {
        OperationCoordinator(
            contactManager: contactManager,
            exporter: contactExporter,
            importer: contactImporter,
            analyzer: contactAnalyzer,
            filter: contactFilter,
            progressReporter: progressReporter,
            logger: logger
        )
    }
    
    func makeExportConfiguration(format: ExportFormat, imageStrategy: ImageExportStrategy = .none) -> ExportConfiguration {
        ExportConfiguration(
            format: format,
            imageStrategy: imageStrategy,
            includeMetadata: true,
            customFields: []
        )
    }
    
    func makeContactFilter(mode: FilterMode, dubiousScore: Int = 3) -> ContactFilter {
        ContactFilter(mode: mode, dubiousScore: dubiousScore)
    }
}

// MARK: - Default Application Configuration

struct DefaultApplicationConfiguration: ApplicationConfiguration {
    let contacts = ContactConfiguration.default
    let export = ExportConfiguration.default
    let analysis = AnalysisConfiguration.default
    let logging = LoggingConfiguration.default
}

// MARK: - Default Logger

struct DefaultLogger: Logging {
    private let configuration: LoggingConfiguration
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    init(configuration: LoggingConfiguration) {
        self.configuration = configuration
    }
    
    func log(level: LogLevel, message: String, context: [String : Any]) {
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

struct ConsoleProgressReporter: ProgressReporting {
    func reportProgress(_ progress: OperationProgress) {
        let percentage = String(format: "%.1f", progress.percentage)
        let message = progress.message.map { " - \($0)" } ?? ""
        print("[\(progress.phase)] \(progress.current)/\(progress.total) (\(percentage)%)\(message)")
    }
}

// MARK: - Operation Coordinator

/// Coordinates complex operations across multiple services
@MainActor
final class OperationCoordinator {
    
    // MARK: - Dependencies
    
    private let contactManager: ContactManaging
    private let exporter: ContactExporting
    private let importer: ContactImporter
    private let analyzer: ContactAnalyzing
    private let filter: ContactFiltering
    private let progressReporter: ProgressReporting
    private let logger: Logging?
    
    // MARK: - Initialization
    
    init(
        contactManager: ContactManaging,
        exporter: ContactExporting,
        importer: ContactImporting,
        analyzer: ContactAnalyzing,
        filter: ContactFiltering,
        progressReporter: ProgressReporting,
        logger: Logging?
    ) {
        self.contactManager = contactManager
        self.exporter = exporter
        self.importer = importer
        self.analyzer = analyzer
        self.filter = filter
        self.progressReporter = progressReporter
        self.logger = logger
    }
    
    // MARK: - High-Level Operations
    
    func executeExportOperation(
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
            return .failure(.configuration(.missingRequiredOption("configuration")))
        }
        
        // Step 4: Export contacts
        progressReporter.reportProgress(OperationProgress(
            current: 4, total: 4, phase: "Export", message: "Exporting \(contacts.count) contacts"
        ))
        
        let exportResult = await exporter.export(contacts, to: destination, configuration: configuration)
        
        switch exportResult {
        case .success(let result):
            logger?.log(level: .info, message: "Export completed successfully", context: [
                "items_exported": result.itemsExported,
                "duration": result.duration
            ])
            return .success(result)
            
        case .failure(let error):
            logger?.log(level: .error, message: "Export failed", context: ["error": error.localizedDescription])
            return .failure(error)
        }
    }
    
    func executeImportOperation(
        source: ImportSource,
        createInContacts: Bool = false
    ) async -> Result<ImportResult, ContactError> {
        
        logger?.log(level: .info, message: "Starting import operation", context: [
            "create_in_contacts": createInContacts
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
            return .failure(.import(.invalidData(field: "source", value: "unknown")))
        }
        
        // Step 2: Import contacts
        progressReporter.reportProgress(OperationProgress(
            current: 2, total: 3, phase: "Import", message: "Importing contacts"
        ))
        
        let importResult = await importer.importContacts(from: source)
        let result: ImportResult
        
        switch importResult {
        case .success(let importedResult):
            result = importedResult
        case .failure(let error):
            logger?.log(level: .error, message: "Import failed", context: ["error": error.localizedDescription])
            return .failure(error)
        }
        
        // Step 3: Create in contacts if requested
        if createInContacts {
            progressReporter.reportProgress(OperationProgress(
                current: 3, total: 3, phase: "Creating", message: "Creating contacts in database"
            ))
            
            do {
                let accessGranted = try await contactManager.requestAccess()
                guard accessGranted else {
                    return .failure(.permission(.contactsAccessDenied))
                }
                
                var successCount = 0
                var failedCount = 0
                var errors: [String] = []
                
                for contact in result.contacts {
                    let createResult = await contactManager.createContact(contact)
                    switch createResult {
                    case .success:
                        successCount += 1
                    case .failure(let error):
                        failedCount += 1
                        errors.append("\(contact.name): \(error.localizedDescription)")
                    }
                }
                
                let finalResult = ImportResult(
                    contacts: result.contacts,
                    itemsImported: successCount,
                    itemsFailed: failedCount,
                    errors: errors,
                    duration: result.duration
                )
                
                logger?.log(level: .info, message: "Import completed", context: [
                    "items_imported": successCount,
                    "items_failed": failedCount
                ])
                
                return .success(finalResult)
                
            } catch {
                return .failure(.permission(.contactsAccessDenied))
            }
        }
        
        logger?.log(level: .info, message: "Import completed successfully", context: [
            "items_imported": result.itemsImported
        ])
        
        return .success(result)
    }
    
    func executeAnalysisOperation(filter: ContactFilter) async -> Result<[ContactAnalysis], ContactError> {
        logger?.log(level: .info, message: "Starting analysis operation", context: [
            "filter": filter.mode.rawValue
        ])
        
        // Load contacts
        let contactsResult = await contactManager.loadContacts(filter: filter)
        let contacts: [Contact]
        
        switch contactsResult {
        case .success(let loadedContacts):
            contacts = loadedContacts
        case .failure(let error):
            return .failure(error)
        }
        
        // Analyze contacts
        let analysisResult = await analyzer.analyzeContacts(contacts)
        
        switch analysisResult {
        case .success(let analyses):
            logger?.log(level: .info, message: "Analysis completed", context: [
                "contacts_analyzed": analyses.count
            ])
            return .success(analyses)
            
        case .failure(let error):
            logger?.log(level: .error, message: "Analysis failed", context: ["error": error.localizedDescription])
            return .failure(error)
        }
    }
}

// MARK: - Configuration Extensions

extension LoggingConfiguration {
    static let `default` = LoggingConfiguration(
        level: .info,
        enableConsole: true,
        enableFile: false,
        filePath: nil
    )
}