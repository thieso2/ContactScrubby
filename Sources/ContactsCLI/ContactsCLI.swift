import Foundation
import Contacts
import ArgumentParser

@main
struct ContactsCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ContactsCLI",
        abstract: "A command-line tool for managing and exporting contacts",
        version: "1.0.0"
    )
    
    @Option(name: .shortAndLong, help: "Filter mode for contacts")
    var filter: FilterMode = .withEmail
    
    @Option(name: .long, help: "Minimum dubiousness score for dubious contacts")
    var dubiousScore: Int = 3
    
    @Flag(name: .long, help: "Show all available contact fields")
    var dump: Bool = false
    
    @Option(name: .long, help: "Export contacts to file (JSON or XML)")
    var backup: String?
    
    @Option(name: .long, help: "Include images in export")
    var includeImages: ImageMode = .none
    
    @Option(name: .long, help: "Add filtered contacts to specified group")
    var addToGroup: String?
    
    func run() async throws {
        let manager = ContactsManager()
        
        let granted = try await manager.requestAccess()
        
        if !granted {
            print("Access to contacts was denied. Please grant permission in System Preferences.")
            throw ExitCode.failure
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
        
        // Handle dump all fields
        if dump {
            try await CommandHandlers.handleDumpOperation(manager: manager)
            return
        }
        
        // Default: display contacts
        try await CommandHandlers.handleDisplayOperation(
            manager: manager,
            filter: filter,
            dubiousScore: dubiousScore
        )
    }
    
    // MARK: - Static utility methods for tests and backwards compatibility
    
    static func getEmptyMessage(for mode: FilterMode) -> String {
        return MessageUtilities.getEmptyMessage(for: mode)
    }
    
    static func getHeaderMessage(for mode: FilterMode) -> String {
        return MessageUtilities.getHeaderMessage(for: mode)
    }
    
    static func formatLabel(_ label: String?) -> String {
        return DisplayUtilities.formatLabel(label)
    }
    
    static func printFullContactDetails(_ contact: CNContact) {
        DisplayUtilities.printFullContactDetails(contact)
    }
    
    static func sanitizeFilename(_ name: String) -> String {
        return ExportUtilities.sanitizeFilename(name)
    }
    
    static func exportAsJSON(contacts: [SerializableContact], to url: URL) throws {
        try ExportUtilities.exportAsJSON(contacts: contacts, to: url)
    }
    
    static func exportAsXML(contacts: [SerializableContact], to url: URL) throws {
        try ExportUtilities.exportAsXML(contacts: contacts, to: url)
    }
    
    static func escapeXML(_ string: String) -> String {
        return ExportUtilities.escapeXML(string)
    }
    
    static func exportWithFolderImages(rawContacts: [CNContact], baseFilename: String) throws -> ([SerializableContact], String?) {
        return try ExportUtilities.exportWithFolderImages(rawContacts: rawContacts, baseFilename: baseFilename)
    }
}