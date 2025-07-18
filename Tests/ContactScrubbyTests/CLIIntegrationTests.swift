import Testing
import ArgumentParser
import Foundation
@testable import ContactScrubby

@Suite("CLI Integration Tests")
struct CLIIntegrationTests {
    
    // MARK: - Command Configuration Tests
    
    @Test("Command configuration")
    func commandConfiguration() {
        let config = ContactScrubby.configuration
        
        #expect(config.commandName == "contactscrub")
        #expect(config.abstract == "A powerful contact scrubbing and management tool")
        #expect(config.version == "0.1")
    }
    
    // MARK: - Argument Parsing Tests
    
    @Test("Default argument parsing")
    func defaultArgumentParsing() throws {
        let command = try ContactScrubby.parse([])
        
        #expect(command.filter == .all)
        #expect(command.dubiousScore == 3)
        #expect(command.allFields == false)
        #expect(command.backup == nil)
        #expect(command.includeImages == .none)
        #expect(command.addToGroup == nil)
    }
    
    @Test("Filter arguments")
    func filterArguments() throws {
        let testCases: [(String, FilterMode)] = [
            ("--filter", .all),
            ("--filter=with-email", .withEmail),
            ("--filter=no-email", .withoutEmail),
            ("--filter=facebook", .facebookOnly),
            ("--filter=facebook-exclusive", .facebookExclusive),
            ("--filter=dubious", .dubious),
            ("--filter=all", .all),
            ("--filter=no-contact", .noContact),
            ("-f", .all),
            ("-f=dubious", .dubious)
        ]
        
        for (arg, expectedMode) in testCases {
            let args = arg.contains("=") ? [arg] : [arg, expectedMode.rawValue]
            let command = try ContactScrubby.parse(args)
            #expect(command.filter == expectedMode, "Failed for argument: \(arg)")
        }
    }
    
    @Test("Dubious score argument")
    func dubiousScoreArgument() throws {
        let command1 = try ContactScrubby.parse(["--dubious-score", "5"])
        #expect(command1.dubiousScore == 5)
        
        let command2 = try ContactScrubby.parse(["--dubious-score=10"])
        #expect(command2.dubiousScore == 10)
    }
    
    @Test("All fields flag")
    func allFieldsFlag() throws {
        let command1 = try ContactScrubby.parse([])
        #expect(command1.allFields == false)
        
        let command2 = try ContactScrubby.parse(["--all-fields"])
        #expect(command2.allFields == true)
    }
    
    @Test("Backup argument")
    func backupArgument() throws {
        let command1 = try ContactScrubby.parse([])
        #expect(command1.backup == nil)
        
        let command2 = try ContactScrubby.parse(["--backup", "test.json"])
        #expect(command2.backup == "test.json")
        
        let command3 = try ContactScrubby.parse(["--backup=contacts.xml"])
        #expect(command3.backup == "contacts.xml")
    }
    
    @Test("Include images argument")
    func includeImagesArgument() throws {
        let testCases: [(String, ImageMode)] = [
            ("none", .none),
            ("inline", .inline),
            ("folder", .folder)
        ]
        
        for (value, expectedMode) in testCases {
            let command = try ContactScrubby.parse(["--include-images", value])
            #expect(command.includeImages == expectedMode, "Failed for value: \(value)")
        }
    }
    
    @Test("Add to group argument")
    func addToGroupArgument() throws {
        let command1 = try ContactScrubby.parse([])
        #expect(command1.addToGroup == nil)
        
        let command2 = try ContactScrubby.parse(["--add-to-group", "Test Group"])
        #expect(command2.addToGroup == "Test Group")
        
        let command3 = try ContactScrubby.parse(["--add-to-group=Facebook Contacts"])
        #expect(command3.addToGroup == "Facebook Contacts")
    }
    
    @Test("Combined arguments")
    func combinedArguments() throws {
        let command = try ContactScrubby.parse([
            "--filter", "dubious",
            "--dubious-score", "2",
            "--backup", "suspicious.json",
            "--include-images", "inline"
        ])
        
        #expect(command.filter == .dubious)
        #expect(command.dubiousScore == 2)
        #expect(command.backup == "suspicious.json")
        #expect(command.includeImages == .inline)
    }
    
    // MARK: - Invalid Argument Tests
    
    @Test("Invalid filter mode")
    func invalidFilterMode() {
        #expect(throws: (any Error).self) {
            try ContactScrubby.parse(["--filter", "invalid"])
        }
    }
    
    @Test("Invalid image mode")
    func invalidImageMode() {
        #expect(throws: (any Error).self) {
            try ContactScrubby.parse(["--include-images", "invalid"])
        }
    }
    
    @Test("Invalid dubious score")
    func invalidDubiousScore() {
        #expect(throws: (any Error).self) {
            try ContactScrubby.parse(["--dubious-score", "invalid"])
        }
    }
    
    // MARK: - Help and Version Tests
    
    @Test("Help output")
    func helpOutput() {
        #expect(throws: (any Error).self) {
            try ContactScrubby.parse(["--help"])
        }
    }
    
    @Test("Version output")
    func versionOutput() {
        #expect(throws: (any Error).self) {
            try ContactScrubby.parse(["--version"])
        }
    }
    
    @Test("No arguments shows usage")
    func noArgumentsShowsUsage() throws {
        // This tests the logical behavior - when no arguments are provided,
        // all options should be at their default values
        let command = try ContactScrubby.parse([])
        #expect(command.filter == .all)
        #expect(command.dubiousScore == 3)
        #expect(command.allFields == false)
        #expect(command.backup == nil)
        #expect(command.includeImages == .none)
        #expect(command.addToGroup == nil)
    }
    
    // MARK: - File Operations Tests
    
    @Test("Export as JSON")
    func exportAsJSON() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ContactScrubbyTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        
        let testFile = tempDirectory.appendingPathComponent("test.json")
        let testContacts = [
            SerializableContact(
                name: "John Doe",
                namePrefix: nil,
                givenName: "John",
                middleName: nil,
                familyName: "Doe",
                nameSuffix: nil,
                nickname: nil,
                phoneticGivenName: nil,
                phoneticMiddleName: nil,
                phoneticFamilyName: nil,
                organizationName: nil,
                departmentName: nil,
                jobTitle: nil,
                emails: [],
                phones: [],
                postalAddresses: [],
                urls: [],
                socialProfiles: [],
                instantMessageAddresses: [],
                birthday: nil,
                dates: [],
                contactType: "person",
                hasImage: false,
                imageData: nil,
                thumbnailImageData: nil,
                note: nil
            )
        ]
        
        try ContactScrubby.exportAsJSON(contacts: testContacts, to: testFile)
        
        #expect(FileManager.default.fileExists(atPath: testFile.path))
        
        let jsonData = try Data(contentsOf: testFile)
        let decodedContacts = try JSONDecoder().decode([SerializableContact].self, from: jsonData)
        
        #expect(decodedContacts.count == 1)
        #expect(decodedContacts[0].name == "John Doe")
        #expect(decodedContacts[0].givenName == "John")
        #expect(decodedContacts[0].familyName == "Doe")
    }
    
    @Test("Export as XML")
    func exportAsXML() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ContactScrubbyTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        
        let testFile = tempDirectory.appendingPathComponent("test.xml")
        let testContacts = [
            SerializableContact(
                name: "Jane Smith",
                namePrefix: nil,
                givenName: "Jane",
                middleName: nil,
                familyName: "Smith",
                nameSuffix: nil,
                nickname: nil,
                phoneticGivenName: nil,
                phoneticMiddleName: nil,
                phoneticFamilyName: nil,
                organizationName: nil,
                departmentName: nil,
                jobTitle: nil,
                emails: [],
                phones: [],
                postalAddresses: [],
                urls: [],
                socialProfiles: [],
                instantMessageAddresses: [],
                birthday: nil,
                dates: [],
                contactType: "person",
                hasImage: false,
                imageData: nil,
                thumbnailImageData: nil,
                note: nil
            )
        ]
        
        try ContactScrubby.exportAsXML(contacts: testContacts, to: testFile)
        
        #expect(FileManager.default.fileExists(atPath: testFile.path))
        
        let xmlContent = try String(contentsOf: testFile)
        #expect(xmlContent.contains("<contacts>"))
        #expect(xmlContent.contains("<contact>"))
        #expect(xmlContent.contains("Jane Smith"))
        #expect(xmlContent.contains("</contacts>"))
    }
    
    // MARK: - Export Options Tests
    
    @Test("Export options validation")
    func exportOptionsValidation() throws {
        let validOptions = ExportOptions(
            filename: "test.json",
            imageMode: .none,
            filterMode: .all,
            dubiousMinScore: 3
        )
        
        #expect(validOptions.fileURL.lastPathComponent == "test.json")
        #expect(validOptions.isValidFormat)
        #expect(validOptions.fileExtension == "json")
    }
    
    // MARK: - Sanitize Filename Integration Tests
    
    @Test("Sanitize filename integration")
    func sanitizeFilenameIntegration() {
        #expect(ContactScrubby.sanitizeFilename("Normal Name") == "Normal Name")
        #expect(ContactScrubby.sanitizeFilename("Name/With\\Slashes") == "Name_With_Slashes")
        #expect(ContactScrubby.sanitizeFilename("") == "unnamed")
        #expect(ContactScrubby.sanitizeFilename("   ") == "unnamed")
    }
    
    // MARK: - Performance Tests
    
    @Test("Large contact list performance")
    func largeContactListPerformance() throws {
        let contacts = (0..<1000).map { i in
            SerializableContact(
                name: "Contact \(i)",
                namePrefix: nil,
                givenName: "Contact",
                middleName: nil,
                familyName: "\(i)",
                nameSuffix: nil,
                nickname: nil,
                phoneticGivenName: nil,
                phoneticMiddleName: nil,
                phoneticFamilyName: nil,
                organizationName: nil,
                departmentName: nil,
                jobTitle: nil,
                emails: [],
                phones: [],
                postalAddresses: [],
                urls: [],
                socialProfiles: [],
                instantMessageAddresses: [],
                birthday: nil,
                dates: [],
                contactType: "person",
                hasImage: false,
                imageData: nil,
                thumbnailImageData: nil,
                note: nil
            )
        }
        
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ContactScrubbyTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        
        let testFile = tempDirectory.appendingPathComponent("large_test.json")
        
        // This should complete in a reasonable time
        try ContactScrubby.exportAsJSON(contacts: contacts, to: testFile)
        
        #expect(FileManager.default.fileExists(atPath: testFile.path))
        
        let jsonData = try Data(contentsOf: testFile)
        let decodedContacts = try JSONDecoder().decode([SerializableContact].self, from: jsonData)
        
        #expect(decodedContacts.count == 1000)
    }
}