import Foundation
import Contacts
import ArgumentParser

@main
struct ContactScrubby: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "contactscrub",
        abstract: "A powerful contact scrubbing and management tool",
        version: "0.1"
    )

    @Option(name: .shortAndLong, help: "Filter mode for contacts")
    var filter: FilterMode = .all

    @Option(name: .long, help: "Minimum dubiousness score for dubious contacts")
    var dubiousScore: Int = 3

    @Flag(name: .long, help: "Show all available contact fields")
    var allFields: Bool = false

    @Option(name: .long, help: "Export contacts to file (JSON or XML)")
    var backup: String?

    @Option(name: .long, help: "Include images in export")
    var includeImages: ImageMode = .none

    @Option(name: .long, help: "Add filtered contacts to specified group")
    var addToGroup: String?

    @Flag(name: .long, help: "Find and display duplicate contacts")
    var findDuplicates: Bool = false

    @Flag(name: .long, help: "Merge duplicate contacts automatically")
    var mergeDuplicates: Bool = false

    @Option(name: .long, help: "Merge strategy: conservative, mostComplete, interactive")
    var mergeStrategy: String = "conservative"

    func run() async throws {
        // Check if no arguments were provided (all options are at their default values)
        if filter == .all && dubiousScore == 3 && !allFields && backup == nil && 
           includeImages == .none && addToGroup == nil && !findDuplicates && !mergeDuplicates &&
           mergeStrategy == "conservative" {
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
            try await CommandHandlers.handleAllFieldsOperation(manager: manager)
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
