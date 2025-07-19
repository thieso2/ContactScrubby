import Foundation
import Contacts
import ArgumentParser

@main
struct ContactScrubby: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "contactscrub",
        abstract: "A powerful contact scrubbing and management tool",
        discussion: """
        ContactScrubby can work with multiple sources and destinations:
        
        SOURCES & DESTINATIONS:
        - contacts: macOS Contacts database (default source)
        - JSON files: .json extension
        - XML files: .xml extension  
        - VCF files: .vcf extension
        
        EXAMPLES:
        # List all contacts from macOS Contacts
        contactscrub
        
        # Export dubious contacts to VCF
        contactscrub --filter dubious --backup dubious.vcf
        
        # Copy contacts from JSON to macOS Contacts
        contactscrub --source contacts.json --destination contacts
        
        # Convert VCF to JSON with filtering
        contactscrub --source contacts.vcf --destination filtered.json --filter with-email
        """,
        version: "0.2"
    )

    @Option(name: .shortAndLong, help: "Filter mode for contacts")
    var filter: FilterMode = .all

    @Option(name: .long, help: "Minimum dubiousness score for dubious contacts")
    var dubiousScore: Int = 3

    @Flag(name: .long, help: "Show all available contact fields")
    var allFields: Bool = false

    @Option(name: .long, help: "Export contacts to file (JSON, XML, or VCF)")
    var backup: String?

    @Option(name: .long, help: "Include images in export")
    var includeImages: ImageMode = .none

    @Option(name: .long, help: "Import contacts from VCF file")
    var importVCF: String?

    @Option(name: .shortAndLong, help: "Source to read contacts from (file path or 'contacts')")
    var source: String?
    
    @Option(name: .long, help: "Source type: contacts, json, xml, vcf")
    var sourceType: SourceType?
    
    @Option(name: .shortAndLong, help: "Destination to write contacts to (file path or 'contacts')")
    var destination: String?
    
    @Option(name: .long, help: "Destination type: contacts, json, xml, vcf")
    var destType: DestinationType?

    @Option(name: .long, help: "Add filtered contacts to specified group")
    var addToGroup: String?

    @Flag(name: .long, help: "Find and display duplicate contacts")
    var findDuplicates: Bool = false

    @Flag(name: .long, help: "Merge duplicate contacts automatically")
    var mergeDuplicates: Bool = false

    @Option(name: .long, help: "Merge strategy: conservative, mostComplete, interactive")
    var mergeStrategy: String = "conservative"

    func run() async throws {
        // Check if using new source/destination syntax
        if source != nil || destination != nil {
            try await handleSourceDestinationMode()
            return
        }
        
        // Check if no arguments were provided (all options are at their default values)
        if filter == .all && dubiousScore == 3 && !allFields && backup == nil && 
           includeImages == .none && importVCF == nil && addToGroup == nil && !findDuplicates && !mergeDuplicates &&
           mergeStrategy == "conservative" && source == nil && destination == nil {
            // Check if we're being called with no arguments at all
            if CommandLine.arguments.count == 1 {
                print(ContactScrubby.helpMessage())
                return
            }
        }

        let manager = ContactsManager()

        let granted = try await manager.requestAccess()

        if !granted {
            print("Access to contacts was denied. Please grant permission in System Preferences.")
            throw ExitCode.failure
        }

        // Handle VCF import if requested
        if let vcfFile = importVCF {
            try await handleImportOperation(
                manager: manager,
                filename: vcfFile
            )
            return
        }

        // Handle merge duplicates if requested
        if mergeDuplicates {
            let strategy = parseMergeStrategy(mergeStrategy)
            try await CommandHandlers.handleMergeOperation(
                manager: manager,
                strategy: strategy
            )
            return
        }

        // Handle find duplicates if requested
        if findDuplicates {
            let strategy = parseMergeStrategy(mergeStrategy)
            try await CommandHandlers.handleFindDuplicatesOperation(
                manager: manager,
                strategy: strategy
            )
            return
        }

        // Handle group addition if requested
        if let groupName = addToGroup {
            try await CommandHandlers.handleGroupOperation(
                manager: manager,
                groupName: groupName,
                filter: filter,
                dubiousScore: dubiousScore
            )
            return
        }

        // Handle backup/export if requested
        if let filename = backup {
            try await CommandHandlers.handleExportOperation(
                manager: manager,
                filename: filename,
                includeImages: includeImages,
                filter: filter,
                dubiousScore: dubiousScore
            )
            return
        }

        // Handle all fields display
        if allFields {
            try await CommandHandlers.handleAllFieldsOperation(
                manager: manager,
                filter: filter,
                dubiousScore: dubiousScore
            )
            return
        }

        // Default: display contacts
        try await CommandHandlers.handleDisplayOperation(
            manager: manager,
            filter: filter,
            dubiousScore: dubiousScore
        )
    }

    // MARK: - Helper Methods

    private func handleSourceDestinationMode() async throws {
        // Determine source and destination
        let src = source ?? "contacts"
        let dst = destination ?? (backup ?? "")
        
        if dst.isEmpty && !allFields {
            print("Error: When using --source, you must specify either --destination or use --all-fields to list contacts")
            throw ExitCode.failure
        }
        
        // Request access if needed
        if src == "contacts" || dst == "contacts" {
            let manager = ContactsManager()
            let granted = try await manager.requestAccess()
            if !granted {
                print("Access to contacts was denied. Please grant permission in System Preferences.")
                throw ExitCode.failure
            }
        }
        
        // If destination is empty, we're in list mode
        if dst.isEmpty {
            // Read and display contacts
            let contacts = try ContactsIO.readContacts(
                from: src,
                type: sourceType,
                filter: filter,
                dubiousScore: dubiousScore
            )
            
            if contacts.isEmpty {
                print(MessageUtilities.getEmptyMessage(for: filter))
                return
            }
            
            print(MessageUtilities.getHeaderMessage(for: filter) + "\n")
            
            for contact in contacts {
                if allFields {
                    // Convert to CNContact-like display
                    printSerializableContactDetails(contact)
                } else {
                    print("Name: \(contact.name)")
                    
                    for email in contact.emails {
                        print("  Email: \(email.value)")
                    }
                    
                    for phone in contact.phones {
                        print("  Phone: \(phone.value)")
                    }
                    
                    print()
                }
            }
            
            print("Total: \(contacts.count) contact(s)")
        } else {
            // Copy mode
            print("Reading contacts from \(src)...")
            
            let contacts = try ContactsIO.readContacts(
                from: src,
                type: sourceType,
                filter: filter,
                dubiousScore: dubiousScore
            )
            
            if contacts.isEmpty {
                print("No contacts found matching the specified criteria.")
                return
            }
            
            print("Found \(contacts.count) contact(s) to copy.")
            
            let result = try ContactsIO.writeContacts(
                contacts,
                to: dst,
                type: destType ?? DestinationType.fromFilename(dst),
                imageMode: includeImages
            )
            
            print("\n✅ \(result.message)")
            
            if result.failedCount > 0 {
                print("Failed: \(result.failedCount) contact(s)")
                if !result.errors.isEmpty && result.errors.count <= 10 {
                    print("\nErrors:")
                    for error in result.errors {
                        print("  - \(error)")
                    }
                }
            }
        }
    }
    
    private func printSerializableContactDetails(_ contact: SerializableContact) {
        print("== \(contact.name) ==")
        
        if let prefix = contact.namePrefix { print("Name Prefix: \(prefix)") }
        if let given = contact.givenName { print("Given Name: \(given)") }
        if let middle = contact.middleName { print("Middle Name: \(middle)") }
        if let family = contact.familyName { print("Family Name: \(family)") }
        if let suffix = contact.nameSuffix { print("Name Suffix: \(suffix)") }
        if let nickname = contact.nickname { print("Nickname: \(nickname)") }
        
        if let org = contact.organizationName { print("Organization: \(org)") }
        if let dept = contact.departmentName { print("Department: \(dept)") }
        if let title = contact.jobTitle { print("Job Title: \(title)") }
        
        if !contact.emails.isEmpty {
            print("Emails:")
            for email in contact.emails {
                let label = email.label.map { " (\($0))" } ?? ""
                print("  \(email.value)\(label)")
            }
        }
        
        if !contact.phones.isEmpty {
            print("Phones:")
            for phone in contact.phones {
                let label = phone.label.map { " (\($0))" } ?? ""
                print("  \(phone.value)\(label)")
            }
        }
        
        if !contact.postalAddresses.isEmpty {
            print("Addresses:")
            for address in contact.postalAddresses {
                let label = address.label.map { " (\($0)):" } ?? ":"
                print("  Address\(label)")
                if let street = address.street { print("    \(street)") }
                if let city = address.city { print("    \(city)") }
                if let state = address.state { print("    \(state)") }
                if let zip = address.postalCode { print("    \(zip)") }
                if let country = address.country { print("    \(country)") }
            }
        }
        
        if !contact.urls.isEmpty {
            print("URLs:")
            for url in contact.urls {
                let label = url.label.map { " (\($0))" } ?? ""
                print("  \(url.value)\(label)")
            }
        }
        
        if contact.hasImage {
            print("Has Image: Yes")
        }
        
        if let note = contact.note {
            print("Note: \(note)")
        }
        
        print(String(repeating: "-", count: 50))
        print()
    }

    private func parseMergeStrategy(_ strategy: String) -> MergeStrategy {
        switch strategy.lowercased() {
        case "conservative":
            return .conservative
        case "mostcomplete", "most-complete":
            return .mostComplete
        case "interactive":
            return .interactive
        default:
            return .conservative
        }
    }

    private func handleImportOperation(manager: ContactsManager, filename: String) async throws {
        let url = URL(fileURLWithPath: filename)
        
        guard FileManager.default.fileExists(atPath: filename) else {
            print("Error: File not found at \(filename)")
            throw ExitCode.failure
        }
        
        guard url.pathExtension.lowercased() == "vcf" else {
            print("Error: Import only supports VCF files. File must have .vcf extension")
            throw ExitCode.failure
        }
        
        print("Importing contacts from \(filename)...")
        
        do {
            let serializableContacts = try VCFImportUtilities.importFromVCF(at: url)
            
            if serializableContacts.isEmpty {
                print("No valid contacts found in the VCF file.")
                return
            }
            
            print("Found \(serializableContacts.count) contact(s) to import.")
            
            var successCount = 0
            var failedCount = 0
            var errors: [String] = []
            
            for (index, serializable) in serializableContacts.enumerated() {
                do {
                    _ = try manager.createContact(from: serializable)
                    successCount += 1
                    print("✓ Imported: \(serializable.name)")
                } catch {
                    failedCount += 1
                    errors.append("\(serializable.name): \(error.localizedDescription)")
                    print("✗ Failed: \(serializable.name) - \(error.localizedDescription)")
                }
                
                // Show progress for large imports
                if (index + 1) % 10 == 0 {
                    print("Progress: \(index + 1)/\(serializableContacts.count)...")
                }
            }
            
            print("\n🎉 Import completed!")
            print("Successfully imported: \(successCount) contact(s)")
            if failedCount > 0 {
                print("Failed to import: \(failedCount) contact(s)")
                if !errors.isEmpty && errors.count <= 10 {
                    print("\nErrors:")
                    for error in errors {
                        print("  - \(error)")
                    }
                } else if errors.count > 10 {
                    print("\nFirst 10 errors:")
                    for error in errors.prefix(10) {
                        print("  - \(error)")
                    }
                    print("... and \(errors.count - 10) more errors")
                }
            }
        } catch {
            print("Error reading VCF file: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }

    // MARK: - Static utility methods for tests and backwards compatibility

    static func getEmptyMessage(for mode: FilterMode) -> String {
        MessageUtilities.getEmptyMessage(for: mode)
    }

    static func getHeaderMessage(for mode: FilterMode) -> String {
        MessageUtilities.getHeaderMessage(for: mode)
    }

    static func formatLabel(_ label: String?) -> String {
        DisplayUtilities.formatLabel(label)
    }

    static func printFullContactDetails(_ contact: CNContact) {
        DisplayUtilities.printFullContactDetails(contact)
    }

    static func sanitizeFilename(_ name: String) -> String {
        ExportUtilities.sanitizeFilename(name)
    }

    static func exportAsJSON(contacts: [SerializableContact], to url: URL) throws {
        try ExportUtilities.exportAsJSON(contacts: contacts, to: url)
    }

    static func exportAsXML(contacts: [SerializableContact], to url: URL) throws {
        try ExportUtilities.exportAsXML(contacts: contacts, to: url)
    }

    static func escapeXML(_ string: String) -> String {
        ExportUtilities.escapeXML(string)
    }

    static func exportWithFolderImages(rawContacts: [CNContact], baseFilename: String) throws
        -> ([SerializableContact], String?) {
        try ExportUtilities.exportWithFolderImages(rawContacts: rawContacts, baseFilename: baseFilename)
    }
}
