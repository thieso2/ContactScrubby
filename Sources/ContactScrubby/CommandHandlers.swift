import Foundation
import Contacts
import ArgumentParser

struct CommandHandlers {

    // MARK: - Group Operation Handler

    static func handleGroupOperation(
        manager: ContactsManager,
        groupName: String,
        filter: FilterMode,
        dubiousScore: Int
    ) async throws {
        let contacts: [CNContact]

        if filter == .dubious {
            let analyses = try manager.getDubiousContacts(minimumScore: dubiousScore)
            contacts = analyses.map { $0.contact }
        } else {
            contacts = try manager.listContactsWithAllFields().filter { contact in
                FilterUtilities.shouldIncludeContact(contact, filter: filter)
            }
        }

        if contacts.isEmpty {
            print("No contacts found matching the specified criteria.")
            return
        }

        print("Adding \(contacts.count) contact(s) to group '\(groupName)'...")

        let result = try manager.addContactsToGroup(contacts: contacts, groupName: groupName)

        print("Results:")
        print("  Successfully added: \(result.added)")
        if result.skipped > 0 {
            print("  Skipped (already in group): \(result.skipped)")
        }
        if !result.errors.isEmpty {
            print("  Errors:")
            for error in result.errors {
                print("    - \(error)")
            }
        }

        print("\nGroup operation completed.")
    }

    // MARK: - Export Operation Handler

    static func handleExportOperation(
        manager: ContactsManager,
        filename: String,
        includeImages: ImageMode,
        filter: FilterMode,
        dubiousScore: Int
    ) async throws {
        let exportOptions = ExportOptions(
            filename: filename,
            imageMode: includeImages,
            filterMode: filter,
            dubiousMinScore: dubiousScore
        )

        guard exportOptions.isValidFormat else {
            print("Error: Unsupported file format. Please use .json or .xml extension")
            throw ExitCode.failure
        }

        let contacts = try manager.getContactsForExport(
            filterMode: filter,
            dubiousMinScore: dubiousScore,
            imageMode: includeImages
        )

        if contacts.isEmpty {
            print(MessageUtilities.getEmptyMessage(for: filter))
            return
        }

        switch exportOptions.fileExtension {
        case "json":
            if includeImages == .folder {
                let rawContacts = try manager.getContactsForFolderExport(
                    filterMode: filter,
                    dubiousMinScore: dubiousScore
                )
                let (exportedContacts, imageFolder) = try ExportUtilities.exportWithFolderImages(
                    rawContacts: rawContacts,
                    baseFilename: filename
                )
                try ExportUtilities.exportAsJSON(contacts: exportedContacts, to: exportOptions.fileURL)
                print("Successfully exported \(exportedContacts.count) contact(s) to \(filename)")
                if let folder = imageFolder {
                    print("Images saved to folder: \(folder)")
                }
            } else {
                try ExportUtilities.exportAsJSON(contacts: contacts, to: exportOptions.fileURL)
                print("Successfully exported \(contacts.count) contact(s) to \(filename)")
            }
        case "xml":
            if includeImages == .folder {
                let rawContacts = try manager.getContactsForFolderExport(
                    filterMode: filter,
                    dubiousMinScore: dubiousScore
                )
                let (exportedContacts, imageFolder) = try ExportUtilities.exportWithFolderImages(
                    rawContacts: rawContacts,
                    baseFilename: filename
                )
                try ExportUtilities.exportAsXML(contacts: exportedContacts, to: exportOptions.fileURL)
                print("Successfully exported \(exportedContacts.count) contact(s) to \(filename)")
                if let folder = imageFolder {
                    print("Images saved to folder: \(folder)")
                }
            } else {
                try ExportUtilities.exportAsXML(contacts: contacts, to: exportOptions.fileURL)
                print("Successfully exported \(contacts.count) contact(s) to \(filename)")
            }
        default:
            print("Error: Unsupported file format. Please use .json or .xml extension")
            throw ExitCode.failure
        }
    }

    // MARK: - Dump Operation Handler

    static func handleDumpOperation(manager: ContactsManager) async throws {
        let fullContacts = try manager.listContactsWithAllFields()

        if fullContacts.isEmpty {
            print("No contacts found.")
        } else {
            print("All contacts with full details:\n")

            for contact in fullContacts {
                DisplayUtilities.printFullContactDetails(contact)
                print(String(repeating: "-", count: 50))
                print()
            }

            print("Total: \(fullContacts.count) contact(s)")
        }
    }

    // MARK: - Display Operation Handler

    static func handleDisplayOperation(
        manager: ContactsManager,
        filter: FilterMode,
        dubiousScore: Int
    ) async throws {
        if filter == .dubious {
            let dubiousAnalyses = try manager.getDubiousContacts(minimumScore: dubiousScore)

            if dubiousAnalyses.isEmpty {
                print(MessageUtilities.getEmptyMessage(for: filter))
            } else {
                var headerMessage = MessageUtilities.getHeaderMessage(for: filter)
                if dubiousScore != 3 {
                    headerMessage += " (minimum score: \(dubiousScore))"
                }
                print(headerMessage + "\n")

                for analysis in dubiousAnalyses {
                    let contact = analysis.contact
                    let fullName = [contact.givenName, contact.familyName]
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    let displayName = fullName.isEmpty ? "No Name" : fullName

                    print("== \(displayName) [Dubious Score: \(analysis.dubiousScore)] ==")
                    print("Issues: \(analysis.reasons.joined(separator: ", "))")

                    if analysis.isIncomplete {
                        print("Status: Incomplete")
                    }
                    if analysis.isSuspicious {
                        print("Status: Suspicious")
                    }

                    print()
                    DisplayUtilities.printFullContactDetails(contact)
                    print(String(repeating: "-", count: 50))
                    print()
                }

                print("Total: \(dubiousAnalyses.count) dubious contact(s)")
            }
        } else {
            let contacts = try manager.listAllContacts(filterMode: filter, dubiousMinScore: dubiousScore)

            if contacts.isEmpty {
                print(MessageUtilities.getEmptyMessage(for: filter))
            } else {
                print(MessageUtilities.getHeaderMessage(for: filter) + "\n")

                for contact in contacts {
                    print("Name: \(contact.name)")

                    if !contact.emails.isEmpty {
                        for email in contact.emails {
                            print("  Email: \(email)")
                        }
                    }

                    if !contact.phones.isEmpty {
                        for phone in contact.phones {
                            print("  Phone: \(phone)")
                        }
                    }

                    print()
                }

                print("Total: \(contacts.count) contact(s)")
            }
        }
    }
}
