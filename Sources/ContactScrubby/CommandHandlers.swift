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

    // MARK: - All Fields Operation Handler

    static func handleAllFieldsOperation(manager: ContactsManager) async throws {
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
            let fullContacts = try manager.listContactsWithAllFields()
            var filteredContacts: [CNContact] = []

            // Apply the same filtering logic as in ContactsManager.listAllContacts
            for contact in fullContacts {
                let emails = contact.emailAddresses.map { $0.value as String }
                let phones = contact.phoneNumbers.map { $0.value.stringValue }

                // Apply filter
                switch filter {
                case .withEmail:
                    if emails.isEmpty { continue }
                case .withoutEmail:
                    if !emails.isEmpty { continue }
                case .facebookOnly:
                    let facebookEmails = emails.filter { $0.lowercased().hasSuffix("@facebook.com") }
                    if facebookEmails.isEmpty { continue }
                case .facebookExclusive:
                    let facebookEmails = emails.filter { $0.lowercased().hasSuffix("@facebook.com") }
                    let hasOnlyFacebookEmails = !facebookEmails.isEmpty && facebookEmails.count == emails.count
                    let hasNoPhones = phones.isEmpty
                    if !(hasOnlyFacebookEmails && hasNoPhones) { continue }
                case .dubious:
                    let analysis = manager.analyzeContact(contact)
                    if !analysis.isDubious(minimumScore: dubiousScore) { continue }
                case .all:
                    break // Include all contacts
                }

                filteredContacts.append(contact)
            }

            if filteredContacts.isEmpty {
                print(MessageUtilities.getEmptyMessage(for: filter))
            } else {
                print(MessageUtilities.getHeaderMessage(for: filter) + "\n")

                for contact in filteredContacts {
                    let fullName = [contact.givenName, contact.familyName]
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    let displayName = fullName.isEmpty ? "No Name" : fullName
                    
                    print("Name: \(displayName)")

                    let emails = contact.emailAddresses.map { $0.value as String }
                    if !emails.isEmpty {
                        for email in emails {
                            print("  Email: \(email)")
                        }
                    }

                    let phones = contact.phoneNumbers.map { $0.value.stringValue }
                    if !phones.isEmpty {
                        for phone in phones {
                            print("  Phone: \(phone)")
                        }
                    }

                    // Count hidden fields
                    let hiddenFieldsCount = countHiddenFields(contact)
                    if hiddenFieldsCount > 0 {
                        print("  (+\(hiddenFieldsCount) more field\(hiddenFieldsCount == 1 ? "" : "s") - use --all-fields to see)")
                    }

                    print()
                }

                print("Total: \(filteredContacts.count) contact(s)")
            }
        }
    }

    // MARK: - Helper Functions

    /// Count fields that are not shown in the normal display
    static func countHiddenFields(_ contact: CNContact) -> Int {
        var count = 0
        
        // Count name components beyond given/family name
        if contact.isKeyAvailable(CNContactNamePrefixKey) && !contact.namePrefix.isEmpty { count += 1 }
        if contact.isKeyAvailable(CNContactMiddleNameKey) && !contact.middleName.isEmpty { count += 1 }
        if contact.isKeyAvailable(CNContactNameSuffixKey) && !contact.nameSuffix.isEmpty { count += 1 }
        if contact.isKeyAvailable(CNContactNicknameKey) && !contact.nickname.isEmpty { count += 1 }
        
        // Count phonetic names
        if contact.isKeyAvailable(CNContactPhoneticGivenNameKey) && !contact.phoneticGivenName.isEmpty { count += 1 }
        if contact.isKeyAvailable(CNContactPhoneticMiddleNameKey) && !contact.phoneticMiddleName.isEmpty { count += 1 }
        if contact.isKeyAvailable(CNContactPhoneticFamilyNameKey) && !contact.phoneticFamilyName.isEmpty { count += 1 }
        
        // Count organization fields
        if contact.isKeyAvailable(CNContactOrganizationNameKey) && !contact.organizationName.isEmpty { count += 1 }
        if contact.isKeyAvailable(CNContactDepartmentNameKey) && !contact.departmentName.isEmpty { count += 1 }
        if contact.isKeyAvailable(CNContactJobTitleKey) && !contact.jobTitle.isEmpty { count += 1 }
        
        // Count other contact info
        if contact.isKeyAvailable(CNContactPostalAddressesKey) && !contact.postalAddresses.isEmpty {
            count += contact.postalAddresses.count
        }
        if contact.isKeyAvailable(CNContactUrlAddressesKey) && !contact.urlAddresses.isEmpty {
            count += contact.urlAddresses.count
        }
        if contact.isKeyAvailable(CNContactSocialProfilesKey) && !contact.socialProfiles.isEmpty {
            count += contact.socialProfiles.count
        }
        if contact.isKeyAvailable(CNContactInstantMessageAddressesKey) && !contact.instantMessageAddresses.isEmpty {
            count += contact.instantMessageAddresses.count
        }
        
        // Count dates
        if contact.isKeyAvailable(CNContactBirthdayKey) && contact.birthday != nil { count += 1 }
        if contact.isKeyAvailable(CNContactDatesKey) && !contact.dates.isEmpty {
            count += contact.dates.count
        }
        
        // Count notes
        if contact.isKeyAvailable(CNContactNoteKey) && !contact.note.isEmpty { count += 1 }
        
        // Count image
        if contact.isKeyAvailable(CNContactImageDataAvailableKey) && contact.imageDataAvailable { count += 1 }
        
        return count
    }

    // MARK: - Duplicate Detection and Merging Handlers

    static func handleFindDuplicatesOperation(
        manager: ContactsManager,
        strategy: MergeStrategy
    ) async throws {
        print("Finding duplicate contacts...")
        
        let allContacts = try manager.listContactsWithAllFields()
        
        if allContacts.isEmpty {
            print("No contacts found.")
            return
        }
        
        let duplicateGroups = DuplicateManager.findDuplicates(in: allContacts, strategy: strategy)
        
        if duplicateGroups.isEmpty {
            print("No duplicate contacts found.")
            return
        }
        
        print("Found \(duplicateGroups.count) group(s) of duplicate contacts:\n")
        
        for (index, group) in duplicateGroups.enumerated() {
            print("== Duplicate Group \(index + 1) ==")
            print("Confidence: \(String(format: "%.1f", group.confidence * 100))%")
            print("Primary Contact: \(DuplicateManager.getFullName(group.primaryContact))")
            print("Duplicates: \(group.duplicates.count)")
            
            for duplicate in group.duplicates {
                print("  - \(DuplicateManager.getFullName(duplicate))")
            }
            
            print()
            
            // Show detailed information for each contact in the group
            for contact in group.contacts {
                let fullName = DuplicateManager.getFullName(contact)
                print("--- \(fullName.isEmpty ? "No Name" : fullName) ---")
                
                if !contact.emailAddresses.isEmpty {
                    print("Emails: \(contact.emailAddresses.map { $0.value as String }.joined(separator: ", "))")
                }
                
                if !contact.phoneNumbers.isEmpty {
                    print("Phones: \(contact.phoneNumbers.map { $0.value.stringValue }.joined(separator: ", "))")
                }
                
                if !contact.organizationName.isEmpty {
                    print("Organization: \(contact.organizationName)")
                }
                
                print()
            }
            
            print(String(repeating: "=", count: 50))
            print()
        }
        
        print("Total duplicate contacts found: \(duplicateGroups.reduce(0) { $0 + $1.duplicates.count })")
        print("Use --merge-duplicates to automatically merge them.")
    }

    static func handleMergeOperation(
        manager: ContactsManager,
        strategy: MergeStrategy
    ) async throws {
        print("Finding and merging duplicate contacts...")
        
        let allContacts = try manager.listContactsWithAllFields()
        
        if allContacts.isEmpty {
            print("No contacts found.")
            return
        }
        
        let duplicateGroups = DuplicateManager.findDuplicates(in: allContacts, strategy: strategy)
        
        if duplicateGroups.isEmpty {
            print("No duplicate contacts found.")
            return
        }
        
        print("Found \(duplicateGroups.count) group(s) of duplicate contacts.")
        
        var totalMerged = 0
        var totalDeleted = 0
        
        for (index, group) in duplicateGroups.enumerated() {
            print("\nProcessing group \(index + 1)/\(duplicateGroups.count)...")
            
            let result = DuplicateManager.mergeDuplicateGroup(group, strategy: strategy)
            
            if result.success {
                // Create the merged contact
                do {
                    _ = try manager.createContact(from: result.mergedContact)
                    
                    // Delete the original contacts
                    for originalContact in result.originalContacts {
                        try manager.deleteContact(originalContact)
                    }
                    
                    let primaryName = DuplicateManager.getFullName(group.primaryContact)
                    print("✅ Merged \(group.duplicates.count) duplicate(s) into: \(primaryName)")
                    
                    totalMerged += 1
                    totalDeleted += group.duplicates.count
                } catch {
                    print("❌ Failed to merge group: \(error.localizedDescription)")
                }
            } else {
                print("❌ Failed to merge group: \(result.error ?? "Unknown error")")
            }
        }
        
        print("\n🎉 Merge operation completed!")
        print("Groups merged: \(totalMerged)")
        print("Duplicate contacts removed: \(totalDeleted)")
        print("Total contacts saved: \(duplicateGroups.reduce(0) { $0 + $1.duplicates.count })")
    }
}
