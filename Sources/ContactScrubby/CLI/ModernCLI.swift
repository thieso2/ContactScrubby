import Foundation
import ArgumentParser

/// Modern CLI interface using the new architecture
@main
struct ModernContactScrubby: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(
        commandName: "contactscrub",
        abstract: "A modern, powerful contact management and analysis tool",
        discussion: """
        ContactScrubby v3.0 - Modern Swift architecture with protocol-oriented design
        
        FEATURES:
        • Protocol-based architecture with dependency injection
        • Modern Swift concurrency with actors and structured concurrency
        • Type-safe configuration and error handling
        • Comprehensive logging and progress reporting
        • Result builders for clean configuration DSL
        
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
        
        # Backward compatibility
        contactscrub --filter dubious --backup contacts.vcf
        """,
        version: "3.0",
        subcommands: [
            ExportCommand.self,
            ImportCommand.self,
            AnalyzeCommand.self,
            ListCommand.self,
            LegacyCommand.self
        ],
        defaultSubcommand: LegacyCommand.self
    )
}

// MARK: - Export Command

extension ModernContactScrubby {
    
    struct ExportCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "export",
            abstract: "Export contacts to various formats"
        )
        
        @Option(name: .shortAndLong, help: "Source to read contacts from")
        var source: String = "contacts"
        
        @Option(name: .shortAndLong, help: "Destination file path")
        var destination: String
        
        @Option(name: .shortAndLong, help: "Filter mode for contacts")
        var filter: FilterMode = .all
        
        @Option(name: .long, help: "Export format (json, xml, vcf)")
        var format: ExportFormat?
        
        @Option(name: .long, help: "Image handling strategy")
        var images: ImageExportStrategy = .none
        
        @Option(name: .long, help: "Minimum dubious score")
        var dubiousScore: Int = 3
        
        @Flag(name: .long, help: "Include metadata in export")
        var includeMetadata: Bool = false
        
        @Flag(name: .long, help: "Enable verbose logging")
        var verbose: Bool = false
        
        func run() async throws {
            let container = DependencyContainer()
            let coordinator = container.makeOperationCoordinator()
            
            // Configure logging level
            if verbose {
                // Would configure verbose logging here
            }
            
            // Determine format from destination if not specified
            let exportFormat = format ?? {
                if let detectedFormat = ExportFormat.from(fileExtension: URL(fileURLWithPath: destination).pathExtension) {
                    return detectedFormat
                } else {
                    return .json
                }
            }()
            
            // Create configuration using DSL
            let exportConfig = createExportConfiguration(format: exportFormat)
            
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
        
        @ExportConfigurationBuilder
        private func createExportConfiguration(format: ExportFormat) -> ExportConfiguration {
            format(format)
            images(images)
            includeMetadata(includeMetadata)
        }
    }
}

// MARK: - Import Command

extension ModernContactScrubby {
    
    struct ImportCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "import",
            abstract: "Import contacts from various formats"
        )
        
        @Option(name: .shortAndLong, help: "Source file path to import from")
        var source: String
        
        @Option(name: .long, help: "Source format (json, xml, vcf)")
        var format: ExportFormat?
        
        @Flag(name: .long, help: "Create contacts in macOS Contacts database")
        var createInContacts: Bool = false
        
        @Flag(name: .long, help: "Enable verbose logging")
        var verbose: Bool = false
        
        func run() async throws {
            let container = DependencyContainer()
            let coordinator = container.makeOperationCoordinator()
            
            // Determine format from source if not specified
            let importFormat = format ?? {
                if let detectedFormat = ExportFormat.from(fileExtension: URL(fileURLWithPath: source).pathExtension) {
                    return detectedFormat
                } else {
                    throw ValidationError("Cannot determine format from file extension. Use --format to specify.")
                }
            }()
            
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

extension ModernContactScrubby {
    
    struct AnalyzeCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "analyze",
            abstract: "Analyze contacts for quality and completeness"
        )
        
        @Option(name: .shortAndLong, help: "Filter mode for contacts")
        var filter: FilterMode = .all
        
        @Option(name: .long, help: "Minimum dubious score")
        var dubiousScore: Int = 3
        
        @Flag(name: .long, help: "Show detailed analysis for each contact")
        var showDetails: Bool = false
        
        @Flag(name: .long, help: "Show only dubious contacts")
        var dubiousOnly: Bool = false
        
        @Flag(name: .long, help: "Enable verbose logging")
        var verbose: Bool = false
        
        func run() async throws {
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
                displayAnalysisResults(analyses, showDetails: showDetails)
                
            case .failure(let error):
                print("❌ Analysis failed: \(error.localizedDescription)")
                if let suggestion = error.recoverySuggestion {
                    print("💡 Suggestion: \(suggestion)")
                }
                throw ExitCode.failure
            }
        }
        
        private func displayAnalysisResults(_ analyses: [ContactAnalysis], showDetails: Bool) {
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
                    displayContactAnalysis(analysis)
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
        
        private func displayContactAnalysis(_ analysis: ContactAnalysis) {
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

extension ModernContactScrubby {
    
    struct ListCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List contacts with filtering"
        )
        
        @Option(name: .shortAndLong, help: "Source to read contacts from")
        var source: String = "contacts"
        
        @Option(name: .shortAndLong, help: "Filter mode for contacts")
        var filter: FilterMode = .all
        
        @Option(name: .long, help: "Minimum dubious score")
        var dubiousScore: Int = 3
        
        @Flag(name: .long, help: "Show all contact fields")
        var allFields: Bool = false
        
        @Option(name: .long, help: "Maximum number of contacts to show")
        var limit: Int?
        
        func run() async throws {
            let container = DependencyContainer()
            let coordinator = container.makeOperationCoordinator()
            
            // For now, only support contacts source
            guard source == "contacts" else {
                print("❌ Only 'contacts' source is currently supported for listing")
                throw ExitCode.failure
            }
            
            // Create filter
            let contactFilter = container.makeContactFilter(mode: filter, dubiousScore: dubiousScore)
            
            // Load contacts
            let contactManager = container.contactManager
            
            do {
                let accessGranted = try await contactManager.requestAccess()
                guard accessGranted else {
                    print("❌ Access to contacts was denied")
                    throw ExitCode.failure
                }
            } catch {
                print("❌ Failed to request contacts access")
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

// MARK: - Legacy Command (Backward Compatibility)

extension ModernContactScrubby {
    
    struct LegacyCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "legacy",
            abstract: "Legacy interface for backward compatibility",
            shouldDisplay: false
        )
        
        @Option(name: .shortAndLong, help: "Filter mode for contacts")
        var filter: FilterMode = .all
        
        @Option(name: .long, help: "Minimum dubiousness score for dubious contacts")
        var dubiousScore: Int = 3
        
        @Flag(name: .long, help: "Show all available contact fields")
        var allFields: Bool = false
        
        @Option(name: .long, help: "Export contacts to file")
        var backup: String?
        
        @Option(name: .long, help: "Include images in export")
        var includeImages: ImageExportStrategy = .none
        
        @Option(name: .long, help: "Import contacts from VCF file")
        var importVCF: String?
        
        func run() async throws {
            // Handle legacy --backup option
            if let backupFile = backup {
                let exportCommand = ExportCommand()
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
                let importCommand = ImportCommand()
                importCommand.source = vcfFile
                importCommand.format = .vcf
                importCommand.createInContacts = true
                
                try await importCommand.run()
                return
            }
            
            // Default: list contacts
            let listCommand = ListCommand()
            listCommand.source = "contacts"
            listCommand.filter = filter
            listCommand.dubiousScore = dubiousScore
            listCommand.allFields = allFields
            
            try await listCommand.run()
        }
    }
}

// MARK: - Custom Validation Error

struct ValidationError: LocalizedError {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
    
    var errorDescription: String? {
        message
    }
}