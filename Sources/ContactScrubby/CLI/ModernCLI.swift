import Foundation
import ArgumentParser

/// Modern CLI interface with full backward compatibility
@main
public struct ContactScrubby: AsyncParsableCommand {
    
    public init() {}
    
    public static let configuration = CommandConfiguration(
        commandName: "contactscrub",
        abstract: "A modern, powerful contact management and analysis tool",
        discussion: """
        ContactScrubby v0.2 - Modern Swift architecture with protocol-oriented design
        
        FEATURES:
        • Protocol-based architecture with dependency injection
        • Modern Swift concurrency with actors and structured concurrency
        • Type-safe configuration and error handling
        • Comprehensive logging and progress reporting
        • Full backward compatibility with v2.x CLI syntax
        
        SOURCES & DESTINATIONS:
        • contacts: macOS Contacts database
        • JSON files: .json extension
        • XML files: .xml extension  
        • VCF files: .vcf extension
        
        EXAMPLES:
        # Modern syntax with explicit operations
        contactscrub export --source contacts --destination backup.json --filter dubious
        contactscrub import --source data.vcf --create-in-contacts
        contactscrub analyze --filter with-email --show-details
        
        # Backward compatibility (legacy v2.x syntax)
        contactscrub --filter dubious --backup contacts.vcf
        contactscrub --filter all --all-fields
        """,
        version: "0.2",
        subcommands: [
            ExportCommand.self,
            ImportCommand.self,
            AnalyzeCommand.self,
            ListCommand.self
        ],
        defaultSubcommand: LegacyCommand.self
    )
    
    public func run() async throws {
        // Default behavior - show help
        print(ContactScrubby.helpMessage())
    }
}

// MARK: - Export Command

extension ContactScrubby {
    
    public struct ExportCommand: AsyncParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "export",
            abstract: "Export contacts to various formats"
        )
        
        @Option(name: .shortAndLong, help: "Source to read contacts from")
        public var source: String = "contacts"
        
        @Option(name: .shortAndLong, help: "Destination file path")
        public var destination: String
        
        @Option(name: .shortAndLong, help: "Filter mode for contacts")
        public var filter: FilterMode = .all
        
        @Option(name: .long, help: "Export format (json, xml, vcf)")
        public var format: ExportFormat?
        
        @Option(name: .long, help: "Image handling strategy")
        public var images: ImageExportStrategy = .none
        
        @Option(name: .long, help: "Minimum dubious score")
        public var dubiousScore: Int = 3
        
        @Flag(name: .long, help: "Include metadata in export")
        public var includeMetadata: Bool = false
        
        @Flag(name: .long, help: "Enable verbose logging")
        public var verbose: Bool = false
        
        public init() {}
        
        @MainActor
        public func run() async throws {
            let container = DependencyContainer()
            let coordinator = container.makeOperationCoordinator()
            
            // Configure logging level if verbose
            if verbose {
                // Could enhance logger configuration here
                print("Verbose logging enabled")
            }
            
            // Determine format from destination if not specified
            let exportFormat = format ?? {
                if let detectedFormat = ExportFormat.from(fileExtension: URL(fileURLWithPath: destination).pathExtension) {
                    return detectedFormat
                } else {
                    return ExportFormat.json
                }
            }()
            
            // Create configuration
            let exportConfig = ExportConfiguration(
                format: exportFormat,
                imageStrategy: images,
                includeMetadata: includeMetadata,
                customFields: []
            )
            
            // Create filter
            let contactFilter = container.makeContactFilter(mode: filter, dubiousScore: dubiousScore)
            
            // Execute export operation
            let result = await coordinator.executeExportOperation(
                filter: contactFilter,
                destination: .file(path: destination),
                configuration: exportConfig
            )
            
            switch result {
            case .success(let exportResult):
                print("✅ Successfully exported \(exportResult.itemsExported) contacts")
                if let outputPath = exportResult.outputPath {
                    print("📁 Output: \(outputPath)")
                }
                if !exportResult.warnings.isEmpty {
                    print("⚠️  Warnings:")
                    for warning in exportResult.warnings {
                        print("   • \(warning)")
                    }
                }
                print("⏱️  Duration: \(String(format: "%.2f", exportResult.duration))s")
                
            case .failure(let error):
                print("❌ Export failed: \(error.localizedDescription)")
                if let suggestion = error.recoverySuggestion {
                    print("💡 Suggestion: \(suggestion)")
                }
                throw ExitCode.failure
            }
        }
    }
}

// MARK: - Import Command

extension ContactScrubby {
    
    public struct ImportCommand: AsyncParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "import",
            abstract: "Import contacts from various formats"
        )
        
        @Option(name: .shortAndLong, help: "Source file path to import from")
        public var source: String
        
        @Option(name: .long, help: "Source format (json, xml, vcf)")
        public var format: ExportFormat?
        
        @Flag(name: .long, help: "Create contacts in macOS Contacts database")
        public var createInContacts: Bool = false
        
        @Flag(name: .long, help: "Enable verbose logging")
        public var verbose: Bool = false
        
        public init() {}
        
        @MainActor
        public func run() async throws {
            let container = DependencyContainer()
            let coordinator = container.makeOperationCoordinator()
            
            // Determine format from source if not specified
            let importFormat: ExportFormat
            if let format = format {
                importFormat = format
            } else if let detectedFormat = ExportFormat.from(fileExtension: URL(fileURLWithPath: source).pathExtension) {
                importFormat = detectedFormat
            } else {
                throw ValidationError("Cannot determine format from file extension. Use --format to specify.")
            }
            
            // Create import source
            let importSource = ImportSource.file(path: source, format: importFormat)
            
            // Execute import operation
            let result = await coordinator.executeImportOperation(
                source: importSource,
                createInContacts: createInContacts
            )
            
            switch result {
            case .success(let importResult):
                print("✅ Successfully imported \(importResult.itemsImported) contacts")
                
                if importResult.itemsFailed > 0 {
                    print("❌ Failed to import \(importResult.itemsFailed) contacts")
                    if !importResult.errors.isEmpty {
                        print("🔍 Errors:")
                        for error in importResult.errors.prefix(5) {
                            print("   • \(error)")
                        }
                        if importResult.errors.count > 5 {
                            print("   ... and \(importResult.errors.count - 5) more errors")
                        }
                    }
                }
                
                print("⏱️  Duration: \(String(format: "%.2f", importResult.duration))s")
                
                if createInContacts {
                    print("📱 Contacts have been added to your macOS Contacts database")
                }
                
            case .failure(let error):
                print("❌ Import failed: \(error.localizedDescription)")
                if let suggestion = error.recoverySuggestion {
                    print("💡 Suggestion: \(suggestion)")
                }
                throw ExitCode.failure
            }
        }
    }
}

// MARK: - Analyze Command

extension ContactScrubby {
    
    public struct AnalyzeCommand: AsyncParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "analyze",
            abstract: "Analyze contacts for quality and completeness"
        )
        
        @Option(name: .shortAndLong, help: "Filter mode for contacts")
        public var filter: FilterMode = .all
        
        @Option(name: .long, help: "Minimum dubious score")
        public var dubiousScore: Int = 3
        
        @Flag(name: .long, help: "Show detailed analysis for each contact")
        public var showDetails: Bool = false
        
        @Flag(name: .long, help: "Show only dubious contacts")
        public var dubiousOnly: Bool = false
        
        @Flag(name: .long, help: "Enable verbose logging")
        public var verbose: Bool = false
        
        public init() {}
        
        @MainActor
        public func run() async throws {
            let container = DependencyContainer()
            let coordinator = container.makeOperationCoordinator()
            
            // Create filter
            let contactFilter = container.makeContactFilter(
                mode: dubiousOnly ? .dubious : filter,
                dubiousScore: dubiousScore
            )
            
            // Execute analysis operation
            let result = await coordinator.executeAnalysisOperation(filter: contactFilter)
            
            switch result {
            case .success(let analyses):
                displayAnalysisResults(analyses, showDetails: showDetails, dubiousScore: dubiousScore)
                
            case .failure(let error):
                print("❌ Analysis failed: \(error.localizedDescription)")
                if let suggestion = error.recoverySuggestion {
                    print("💡 Suggestion: \(suggestion)")
                }
                throw ExitCode.failure
            }
        }
        
        private func displayAnalysisResults(_ analyses: [ContactAnalysis], showDetails: Bool, dubiousScore: Int) {
            let totalContacts = analyses.count
            let dubiousContacts = analyses.filter { $0.isDubious(minimumScore: dubiousScore) }
            let incompleteContacts = analyses.filter { $0.isIncomplete }
            let suspiciousContacts = analyses.filter { $0.isSuspicious }
            
            print("📊 Analysis Summary")
            print("==================")
            print("Total contacts analyzed: \(totalContacts)")
            print("Dubious contacts: \(dubiousContacts.count)")
            print("Incomplete contacts: \(incompleteContacts.count)")
            print("Suspicious contacts: \(suspiciousContacts.count)")
            
            if showDetails && !analyses.isEmpty {
                print("\n📋 Detailed Analysis")
                print("====================")
                
                for analysis in analyses.sorted(by: { $0.dubiousScore > $1.dubiousScore }) {
                    displayContactAnalysis(analysis, dubiousScore: dubiousScore)
                }
            } else if !dubiousContacts.isEmpty {
                print("\n🚨 Top Dubious Contacts")
                print("=======================")
                
                for analysis in dubiousContacts.prefix(10) {
                    print("• \(analysis.contact.name) (Score: \(analysis.dubiousScore))")
                    print("  Reasons: \(analysis.reasons.joined(separator: ", "))")
                }
                
                if dubiousContacts.count > 10 {
                    print("... and \(dubiousContacts.count - 10) more")
                }
            }
        }
        
        private func displayContactAnalysis(_ analysis: ContactAnalysis, dubiousScore: Int) {
            let indicators = [
                analysis.isIncomplete ? "📝" : "",
                analysis.isSuspicious ? "⚠️" : "",
                analysis.isDubious(minimumScore: dubiousScore) ? "🚨" : ""
            ].filter { !$0.isEmpty }.joined(separator: " ")
            
            print("\n\(indicators) \(analysis.contact.name)")
            print("Score: \(analysis.dubiousScore) | Confidence: \(String(format: "%.1f", analysis.confidence * 100))%")
            
            if !analysis.reasons.isEmpty {
                print("Issues: \(analysis.reasons.joined(separator: ", "))")
            }
            
            // Show basic contact info
            let contact = analysis.contact
            if !contact.emails.isEmpty {
                print("Emails: \(contact.emails.map { $0.value }.joined(separator: ", "))")
            }
            if !contact.phones.isEmpty {
                print("Phones: \(contact.phones.map { $0.value }.joined(separator: ", "))")
            }
        }
    }
}

// MARK: - List Command

extension ContactScrubby {
    
    public struct ListCommand: AsyncParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List contacts with filtering"
        )
        
        @Option(name: .shortAndLong, help: "Source to read contacts from")
        public var source: String = "contacts"
        
        @Option(name: .shortAndLong, help: "Filter mode for contacts")
        public var filter: FilterMode = .all
        
        @Option(name: .long, help: "Minimum dubious score")
        public var dubiousScore: Int = 3
        
        @Flag(name: .long, help: "Show all contact fields")
        public var allFields: Bool = false
        
        @Option(name: .long, help: "Maximum number of contacts to show")
        public var limit: Int?
        
        public init() {}
        
        @MainActor
        public func run() async throws {
            let container = DependencyContainer()
            
            // For now, only support contacts source
            guard source == "contacts" else {
                print("❌ Only 'contacts' source is currently supported for listing")
                throw ExitCode.failure
            }
            
            // Create filter
            let contactFilter = container.makeContactFilter(mode: filter, dubiousScore: dubiousScore)
            
            // Load contacts
            let contactManager = container.makeContactManager()
            
            do {
                let accessGranted = try await contactManager.requestAccess()
                guard accessGranted else {
                    print("❌ Access to contacts was denied")
                    throw ExitCode.failure
                }
            } catch {
                print("❌ Failed to request contacts access: \(error.localizedDescription)")
                throw ExitCode.failure
            }
            
            let result = await contactManager.loadContacts(filter: contactFilter)
            
            switch result {
            case .success(let contacts):
                let displayContacts = limit.map { Array(contacts.prefix($0)) } ?? contacts
                
                print("📋 \(filter.description)")
                print("Found \(contacts.count) contact(s)\n")
                
                if displayContacts.isEmpty {
                    print("No contacts found matching the specified criteria.")
                } else {
                    for contact in displayContacts {
                        displayContact(contact, allFields: allFields)
                    }
                    
                    if let limit = limit, contacts.count > limit {
                        print("\n... and \(contacts.count - limit) more contacts")
                        print("Use --limit to show more contacts")
                    }
                }
                
            case .failure(let error):
                print("❌ Failed to load contacts: \(error.localizedDescription)")
                if let suggestion = error.recoverySuggestion {
                    print("💡 Suggestion: \(suggestion)")
                }
                throw ExitCode.failure
            }
        }
        
        private func displayContact(_ contact: Contact, allFields: Bool) {
            print("📇 \(contact.name)")
            
            if !contact.emails.isEmpty {
                for email in contact.emails {
                    let label = email.label?.localizedDescription ?? "Email"
                    print("  📧 \(label): \(email.value)")
                }
            }
            
            if !contact.phones.isEmpty {
                for phone in contact.phones {
                    let label = phone.label?.localizedDescription ?? "Phone"
                    print("  📞 \(label): \(phone.value)")
                }
            }
            
            if allFields {
                if let org = contact.organizationName {
                    print("  🏢 Organization: \(org)")
                }
                if let title = contact.jobTitle {
                    print("  💼 Job Title: \(title)")
                }
                if !contact.addresses.isEmpty {
                    print("  🏠 Addresses: \(contact.addresses.count)")
                }
                if !contact.urls.isEmpty {
                    print("  🌐 URLs: \(contact.urls.count)")
                }
                if contact.imageData != nil {
                    print("  🖼️  Has Image")
                }
            }
            
            print()
        }
    }
}

// MARK: - Legacy Command (Default - Full Backward Compatibility)

extension ContactScrubby {
    
    public struct LegacyCommand: AsyncParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "legacy",
            abstract: "Legacy interface for backward compatibility",
            shouldDisplay: false
        )
        
        @Option(name: .shortAndLong, help: "Filter mode for contacts")
        public var filter: FilterMode = .all
        
        @Option(name: .long, help: "Minimum dubiousness score for dubious contacts")
        public var dubiousScore: Int = 3
        
        @Flag(name: .long, help: "Show all available contact fields")
        public var allFields: Bool = false
        
        @Option(name: .long, help: "Export contacts to file")
        public var backup: String?
        
        @Option(name: .long, help: "Include images in export")
        public var includeImages: ImageExportStrategy = .none
        
        @Option(name: .long, help: "Import contacts from VCF file")
        public var importVCF: String?
        
        // Additional legacy options for compatibility
        @Option(name: .long, help: "Source and destination (legacy format: source:destination)")
        public var sourceDestination: String?
        
        @Option(name: .long, help: "Source file or 'contacts'")
        public var source: String?
        
        @Option(name: .long, help: "Destination file")
        public var destination: String?
        
        public init() {}
        
        @MainActor
        public func run() async throws {
            // Handle --source-destination option (source:destination format)
            if let sourceDestination = sourceDestination {
                let parts = sourceDestination.split(separator: ":")
                if parts.count == 2 {
                    let sourceStr = String(parts[0])
                    let destinationStr = String(parts[1])
                    
                    try await handleSourceDestinationMode(source: sourceStr, destination: destinationStr)
                    return
                } else {
                    print("❌ Invalid source:destination format. Use 'source:destination'")
                    throw ExitCode.failure
                }
            }
            
            // Handle --source and --destination options
            if let source = source, let destination = destination {
                try await handleSourceDestinationMode(source: source, destination: destination)
                return
            }
            
            // Handle legacy --backup option
            if let backupFile = backup {
                var exportCommand = ExportCommand()
                exportCommand.source = "contacts"
                exportCommand.destination = backupFile
                exportCommand.filter = filter
                exportCommand.images = includeImages
                exportCommand.dubiousScore = dubiousScore
                
                try await exportCommand.run()
                return
            }
            
            // Handle legacy --import-vcf option
            if let vcfFile = importVCF {
                var importCommand = ImportCommand()
                importCommand.source = vcfFile
                importCommand.format = ExportFormat.vcf
                importCommand.createInContacts = true
                
                try await importCommand.run()
                return
            }
            
            // Default: list contacts (legacy behavior)
            var listCommand = ListCommand()
            listCommand.source = "contacts"
            listCommand.filter = filter
            listCommand.dubiousScore = dubiousScore
            listCommand.allFields = allFields
            
            try await listCommand.run()
        }
        
        @MainActor
        private func handleSourceDestinationMode(source: String, destination: String) async throws {
            let container = DependencyContainer()
            let coordinator = container.makeOperationCoordinator()
            
            if source == "contacts" {
                // Export from contacts to file
                let format = ExportFormat.from(fileExtension: URL(fileURLWithPath: destination).pathExtension) ?? .json
                
                let exportConfig = ExportConfiguration(
                    format: format,
                    imageStrategy: includeImages,
                    includeMetadata: true,
                    customFields: []
                )
                
                let contactFilter = container.makeContactFilter(mode: filter, dubiousScore: dubiousScore)
                
                let result = await coordinator.executeExportOperation(
                    filter: contactFilter,
                    destination: .file(path: destination),
                    configuration: exportConfig
                )
                
                switch result {
                case .success(let exportResult):
                    print("✅ Successfully exported \(exportResult.itemsExported) contacts to \(destination)")
                case .failure(let error):
                    print("❌ Export failed: \(error.localizedDescription)")
                    throw ExitCode.failure
                }
                
            } else if destination == "contacts" {
                // Import from file to contacts
                let format = ExportFormat.from(fileExtension: URL(fileURLWithPath: source).pathExtension)
                guard let importFormat = format else {
                    print("❌ Cannot determine format from file extension")
                    throw ExitCode.failure
                }
                
                let importSource = ImportSource.file(path: source, format: importFormat)
                
                let result = await coordinator.executeImportOperation(
                    source: importSource,
                    createInContacts: true
                )
                
                switch result {
                case .success(let importResult):
                    print("✅ Successfully imported \(importResult.itemsImported) contacts from \(source)")
                case .failure(let error):
                    print("❌ Import failed: \(error.localizedDescription)")
                    throw ExitCode.failure
                }
                
            } else {
                // File to file conversion
                print("🔄 Converting \(source) to \(destination)")
                
                // First import from source
                let sourceFormat = ExportFormat.from(fileExtension: URL(fileURLWithPath: source).pathExtension)
                guard let importFormat = sourceFormat else {
                    print("❌ Cannot determine source format")
                    throw ExitCode.failure
                }
                
                let importSource = ImportSource.file(path: source, format: importFormat)
                let importResult = await coordinator.executeImportOperation(source: importSource, createInContacts: false)
                
                guard case .success(let imported) = importResult else {
                    print("❌ Failed to import from \(source)")
                    throw ExitCode.failure
                }
                
                // Then export to destination
                let destFormat = ExportFormat.from(fileExtension: URL(fileURLWithPath: destination).pathExtension) ?? .json
                
                let exportConfig = ExportConfiguration(
                    format: destFormat,
                    imageStrategy: includeImages,
                    includeMetadata: true,
                    customFields: []
                )
                
                let exportResult = await coordinator.executeExportOperation(
                    filter: ContactFilter(mode: .all), // Use all contacts for conversion
                    destination: .file(path: destination),
                    configuration: exportConfig
                )
                
                switch exportResult {
                case .success(_):
                    print("✅ Successfully converted \(imported.itemsImported) contacts")
                case .failure(let error):
                    print("❌ Export failed: \(error.localizedDescription)")
                    throw ExitCode.failure
                }
            }
        }
    }
}

// MARK: - Custom Validation Error

public struct ValidationError: LocalizedError {
    public let message: String
    
    public init(_ message: String) {
        self.message = message
    }
    
    public var errorDescription: String? {
        message
    }
}