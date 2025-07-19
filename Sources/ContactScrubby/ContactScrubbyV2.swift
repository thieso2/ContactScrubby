import Foundation
import Contacts
import ArgumentParser

struct ContactScrubbyV2: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "contactscrub",
        abstract: "A powerful contact scrubbing and management tool with flexible source/destination support",
        version: "0.2",
        subcommands: [Copy.self, List.self, FindDuplicates.self, MergeDuplicates.self],
        defaultSubcommand: List.self
    )
}

// MARK: - Copy Command

extension ContactScrubbyV2 {
    struct Copy: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Copy contacts between different sources and destinations"
        )
        
        @Option(name: .shortAndLong, help: "Source to read contacts from (file path or 'contacts')")
        var source: String = "contacts"
        
        @Option(name: .long, help: "Source type: contacts, json, xml, vcf")
        var sourceType: SourceType?
        
        @Option(name: .shortAndLong, help: "Destination to write contacts to (file path or 'contacts')")
        var destination: String
        
        @Option(name: .long, help: "Destination type: contacts, json, xml, vcf")
        var destType: DestinationType?
        
        @Option(name: .shortAndLong, help: "Filter mode for contacts")
        var filter: FilterMode = .all
        
        @Option(name: .long, help: "Minimum dubiousness score for dubious filter")
        var dubiousScore: Int = 3
        
        @Option(name: .long, help: "Include images in export")
        var images: ImageMode = .none
        
        @Option(name: .long, help: "Add copied contacts to specified group (only for contacts destination)")
        var addToGroup: String?
        
        func run() async throws {
            // Request access if needed
            if source == "contacts" || destination == "contacts" {
                let manager = ContactsManager()
                let granted = try await manager.requestAccess()
                if !granted {
                    print("Access to contacts was denied. Please grant permission in System Preferences.")
                    throw ExitCode.failure
                }
            }
            
            print("Reading contacts from \(source)...")
            
            // Read contacts from source
            let contacts = try ContactsIO.readContacts(
                from: source,
                type: sourceType,
                filter: filter,
                dubiousScore: dubiousScore
            )
            
            if contacts.isEmpty {
                print("No contacts found matching the specified criteria.")
                return
            }
            
            print("Found \(contacts.count) contact(s) to copy.")
            
            // Handle group addition if destination is contacts
            if destination == "contacts" && addToGroup != nil {
                // First write to contacts
                let result = try ContactsIO.writeContacts(
                    contacts,
                    to: destination,
                    type: destType,
                    imageMode: images
                )
                print(result.message)
                
                // Then add to group
                // Note: This requires converting back to CNContacts which is not ideal
                print("Note: --add-to-group is not yet supported with the new copy command")
            } else {
                // Write contacts to destination
                let result = try ContactsIO.writeContacts(
                    contacts,
                    to: destination,
                    type: destType,
                    imageMode: images
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
    }
}

// MARK: - List Command

extension ContactScrubbyV2 {
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List contacts from a source"
        )
        
        @Option(name: .shortAndLong, help: "Source to read contacts from (file path or 'contacts')")
        var source: String = "contacts"
        
        @Option(name: .long, help: "Source type: contacts, json, xml, vcf")
        var sourceType: SourceType?
        
        @Option(name: .shortAndLong, help: "Filter mode for contacts")
        var filter: FilterMode = .all
        
        @Option(name: .long, help: "Minimum dubiousness score for dubious filter")
        var dubiousScore: Int = 3
        
        @Flag(name: .long, help: "Show all available contact fields")
        var allFields: Bool = false
        
        func run() async throws {
            // Request access if reading from contacts
            if source == "contacts" {
                let manager = ContactsManager()
                let granted = try await manager.requestAccess()
                if !granted {
                    print("Access to contacts was denied. Please grant permission in System Preferences.")
                    throw ExitCode.failure
                }
            }
            
            // Read contacts
            let contacts = try ContactsIO.readContacts(
                from: source,
                type: sourceType,
                filter: filter,
                dubiousScore: dubiousScore
            )
            
            if contacts.isEmpty {
                print(MessageUtilities.getEmptyMessage(for: filter))
                return
            }
            
            print(MessageUtilities.getHeaderMessage(for: filter) + "\n")
            
            // Display contacts
            for contact in contacts {
                print("Name: \(contact.name)")
                
                if !contact.emails.isEmpty {
                    for email in contact.emails {
                        let label = email.label.map { " (\($0))" } ?? ""
                        print("  Email: \(email.value)\(label)")
                    }
                }
                
                if !contact.phones.isEmpty {
                    for phone in contact.phones {
                        let label = phone.label.map { " (\($0))" } ?? ""
                        print("  Phone: \(phone.value)\(label)")
                    }
                }
                
                if allFields {
                    // Show additional fields
                    if let org = contact.organizationName {
                        print("  Organization: \(org)")
                    }
                    if let title = contact.jobTitle {
                        print("  Job Title: \(title)")
                    }
                    if !contact.postalAddresses.isEmpty {
                        print("  Addresses: \(contact.postalAddresses.count)")
                    }
                    if !contact.urls.isEmpty {
                        print("  URLs: \(contact.urls.count)")
                    }
                    if !contact.socialProfiles.isEmpty {
                        print("  Social Profiles: \(contact.socialProfiles.count)")
                    }
                    if contact.hasImage {
                        print("  Has Image: Yes")
                    }
                    if let note = contact.note, !note.isEmpty {
                        print("  Has Note: Yes")
                    }
                }
                
                print()
            }
            
            print("Total: \(contacts.count) contact(s)")
        }
    }
}

// MARK: - Find Duplicates Command

extension ContactScrubbyV2 {
    struct FindDuplicates: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Find duplicate contacts in the macOS Contacts database"
        )
        
        @Option(name: .long, help: "Merge strategy for analysis: conservative, mostComplete")
        var strategy: String = "conservative"
        
        func run() async throws {
            let manager = ContactsManager()
            let granted = try await manager.requestAccess()
            if !granted {
                print("Access to contacts was denied. Please grant permission in System Preferences.")
                throw ExitCode.failure
            }
            
            let mergeStrategy = parseMergeStrategy(strategy)
            try await CommandHandlers.handleFindDuplicatesOperation(
                manager: manager,
                strategy: mergeStrategy
            )
        }
        
        private func parseMergeStrategy(_ strategy: String) -> MergeStrategy {
            switch strategy.lowercased() {
            case "conservative":
                return .conservative
            case "mostcomplete", "most-complete":
                return .mostComplete
            default:
                return .conservative
            }
        }
    }
}

// MARK: - Merge Duplicates Command

extension ContactScrubbyV2 {
    struct MergeDuplicates: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Automatically merge duplicate contacts in the macOS Contacts database"
        )
        
        @Option(name: .long, help: "Merge strategy: conservative, mostComplete")
        var strategy: String = "conservative"
        
        func run() async throws {
            let manager = ContactsManager()
            let granted = try await manager.requestAccess()
            if !granted {
                print("Access to contacts was denied. Please grant permission in System Preferences.")
                throw ExitCode.failure
            }
            
            let mergeStrategy = parseMergeStrategy(strategy)
            try await CommandHandlers.handleMergeOperation(
                manager: manager,
                strategy: mergeStrategy
            )
        }
        
        private func parseMergeStrategy(_ strategy: String) -> MergeStrategy {
            switch strategy.lowercased() {
            case "conservative":
                return .conservative
            case "mostcomplete", "most-complete":
                return .mostComplete
            default:
                return .conservative
            }
        }
    }
}