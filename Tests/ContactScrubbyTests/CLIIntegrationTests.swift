import XCTest
import ArgumentParser
@testable import ContactScrubby

final class CLIIntegrationTests: XCTestCase {

    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        // Create a temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ContactScrubbyTests")
            .appendingPathComponent(UUID().uuidString)

        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - Command Configuration Tests

    func testCommandConfiguration() {
        let config = ContactScrubby.configuration

        XCTAssertEqual(config.commandName, "contactscrub")
        XCTAssertEqual(config.abstract, "A powerful contact scrubbing and management tool")
        XCTAssertEqual(config.version, "0.1")
    }

    // MARK: - Argument Parsing Tests

    func testDefaultArgumentParsing() throws {
        let command = try ContactScrubby.parse([])

        XCTAssertEqual(command.filter, .all)
        XCTAssertEqual(command.dubiousScore, 3)
        XCTAssertFalse(command.allFields)
        XCTAssertNil(command.backup)
        XCTAssertEqual(command.includeImages, .none)
        XCTAssertNil(command.addToGroup)
    }

    func testFilterArguments() throws {
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
            XCTAssertEqual(command.filter, expectedMode, "Failed for argument: \(arg)")
        }
    }

    func testDubiousScoreArgument() throws {
        let command1 = try ContactScrubby.parse(["--dubious-score", "5"])
        XCTAssertEqual(command1.dubiousScore, 5)

        let command2 = try ContactScrubby.parse(["--dubious-score=10"])
        XCTAssertEqual(command2.dubiousScore, 10)
    }

    func testAllFieldsFlag() throws {
        let command1 = try ContactScrubby.parse([])
        XCTAssertFalse(command1.allFields)

        let command2 = try ContactScrubby.parse(["--all-fields"])
        XCTAssertTrue(command2.allFields)
    }

    func testBackupArgument() throws {
        let command1 = try ContactScrubby.parse([])
        XCTAssertNil(command1.backup)

        let command2 = try ContactScrubby.parse(["--backup", "test.json"])
        XCTAssertEqual(command2.backup, "test.json")

        let command3 = try ContactScrubby.parse(["--backup=contacts.xml"])
        XCTAssertEqual(command3.backup, "contacts.xml")
    }

    func testIncludeImagesArgument() throws {
        let testCases: [(String, ImageMode)] = [
            ("none", .none),
            ("inline", .inline),
            ("folder", .folder)
        ]

        for (value, expectedMode) in testCases {
            let command = try ContactScrubby.parse(["--include-images", value])
            XCTAssertEqual(command.includeImages, expectedMode, "Failed for value: \(value)")
        }
    }

    func testAddToGroupArgument() throws {
        let command1 = try ContactScrubby.parse([])
        XCTAssertNil(command1.addToGroup)

        let command2 = try ContactScrubby.parse(["--add-to-group", "Test Group"])
        XCTAssertEqual(command2.addToGroup, "Test Group")

        let command3 = try ContactScrubby.parse(["--add-to-group=Facebook Contacts"])
        XCTAssertEqual(command3.addToGroup, "Facebook Contacts")
    }

    func testCombinedArguments() throws {
        let command = try ContactScrubby.parse([
            "--filter", "dubious",
            "--dubious-score", "2",
            "--backup", "suspicious.json",
            "--include-images", "inline"
        ])

        XCTAssertEqual(command.filter, .dubious)
        XCTAssertEqual(command.dubiousScore, 2)
        XCTAssertEqual(command.backup, "suspicious.json")
        XCTAssertEqual(command.includeImages, .inline)
    }

    // MARK: - Invalid Argument Tests

    func testInvalidFilterMode() {
        XCTAssertThrowsError(try ContactScrubby.parse(["--filter", "invalid"])) { error in
            // ArgumentParser throws different error types for invalid values
            XCTAssertTrue(error is Error)
        }
    }

    func testInvalidImageMode() {
        XCTAssertThrowsError(try ContactScrubby.parse(["--include-images", "invalid"])) { error in
            // ArgumentParser throws different error types for invalid values
            XCTAssertTrue(error is Error)
        }
    }

    func testInvalidDubiousScore() {
        XCTAssertThrowsError(try ContactScrubby.parse(["--dubious-score", "invalid"])) { error in
            // ArgumentParser throws different error types for invalid values
            XCTAssertTrue(error is Error)
        }
    }

    // MARK: - Help and Version Tests

    func testHelpOutput() {
        XCTAssertThrowsError(try ContactScrubby.parse(["--help"])) { error in
            // Help should throw some kind of error to exit
            XCTAssertTrue(error is Error)
        }
    }

    func testVersionOutput() {
        XCTAssertThrowsError(try ContactScrubby.parse(["--version"])) { error in
            // Version should throw some kind of error to exit
            XCTAssertTrue(error is Error)
        }
    }

    func testNoArgumentsShowsUsage() {
        // This tests the logical behavior - when no arguments are provided,
        // all options should be at their default values
        let command = try! ContactScrubby.parse([])
        XCTAssertEqual(command.filter, .all)
        XCTAssertEqual(command.dubiousScore, 3)
        XCTAssertFalse(command.allFields)
        XCTAssertNil(command.backup)
        XCTAssertEqual(command.includeImages, .none)
        XCTAssertNil(command.addToGroup)
    }

    // MARK: - File Operations Tests

    func testExportAsJSON() throws {
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
                emails: [SerializableContact.LabeledValue(label: "work", value: "john@example.com")],
                phones: [SerializableContact.LabeledValue(label: "mobile", value: "123-456-7890")],
                postalAddresses: [],
                urls: [],
                socialProfiles: [],
                instantMessageAddresses: [],
                birthday: nil,
                dates: [],
                contactType: "Person",
                hasImage: false,
                imageData: nil,
                thumbnailImageData: nil,
                note: nil
            )
        ]

        try ContactScrubby.exportAsJSON(contacts: testContacts, to: testFile)

        XCTAssertTrue(FileManager.default.fileExists(atPath: testFile.path))

        let data = try Data(contentsOf: testFile)
        let jsonObject = try JSONSerialization.jsonObject(with: data)

        XCTAssertTrue(jsonObject is [Any])

        if let contacts = jsonObject as? [[String: Any]] {
            XCTAssertEqual(contacts.count, 1)
            let contact = contacts[0]
            XCTAssertEqual(contact["name"] as? String, "John Doe")
            XCTAssertEqual(contact["givenName"] as? String, "John")
            XCTAssertEqual(contact["familyName"] as? String, "Doe")
            XCTAssertEqual(contact["contactType"] as? String, "Person")
            XCTAssertEqual(contact["hasImage"] as? Bool, false)

            if let emails = contact["emails"] as? [[String: Any]] {
                XCTAssertEqual(emails.count, 1)
                XCTAssertEqual(emails[0]["label"] as? String, "work")
                XCTAssertEqual(emails[0]["value"] as? String, "john@example.com")
            }

            if let phones = contact["phones"] as? [[String: Any]] {
                XCTAssertEqual(phones.count, 1)
                XCTAssertEqual(phones[0]["label"] as? String, "mobile")
                XCTAssertEqual(phones[0]["value"] as? String, "123-456-7890")
            }
        }
    }

    func testExportAsXML() throws {
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
                organizationName: "Apple Inc.",
                departmentName: nil,
                jobTitle: "Engineer",
                emails: [SerializableContact.LabeledValue(label: "work", value: "jane@apple.com")],
                phones: [],
                postalAddresses: [],
                urls: [],
                socialProfiles: [],
                instantMessageAddresses: [],
                birthday: SerializableContact.DateInfo(day: 15, month: 6, year: 1990),
                dates: [],
                contactType: "Person",
                hasImage: true,
                imageData: "base64data",
                thumbnailImageData: "base64thumbnail",
                note: "Test contact"
            )
        ]

        try ContactScrubby.exportAsXML(contacts: testContacts, to: testFile)

        XCTAssertTrue(FileManager.default.fileExists(atPath: testFile.path))

        let content = try String(contentsOf: testFile, encoding: .utf8)

        XCTAssertTrue(content.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        XCTAssertTrue(content.contains("<contacts>"))
        XCTAssertTrue(content.contains("</contacts>"))
        XCTAssertTrue(content.contains("<contact>"))
        XCTAssertTrue(content.contains("</contact>"))
        XCTAssertTrue(content.contains("<name>Jane Smith</name>"))
        XCTAssertTrue(content.contains("<givenName>Jane</givenName>"))
        XCTAssertTrue(content.contains("<familyName>Smith</familyName>"))
        XCTAssertTrue(content.contains("<organizationName>Apple Inc.</organizationName>"))
        XCTAssertTrue(content.contains("<jobTitle>Engineer</jobTitle>"))
        XCTAssertTrue(content.contains("<contactType>Person</contactType>"))
        XCTAssertTrue(content.contains("<hasImage>true</hasImage>"))
        XCTAssertTrue(content.contains("<imageData>base64data</imageData>"))
        XCTAssertTrue(content.contains("<thumbnailImageData>base64thumbnail</thumbnailImageData>"))
        XCTAssertTrue(content.contains("<note>Test contact</note>"))
        XCTAssertTrue(content.contains("jane@apple.com"))
        XCTAssertTrue(content.contains("day=\"15\""))
        XCTAssertTrue(content.contains("month=\"6\""))
        XCTAssertTrue(content.contains("year=\"1990\""))
    }

    // MARK: - Export Options Tests

    func testExportOptionsValidation() {
        let validOptions = ExportOptions(
            filename: "test.json",
            imageMode: .inline,
            filterMode: .all,
            dubiousMinScore: 3
        )
        XCTAssertTrue(validOptions.isValidFormat)
        XCTAssertEqual(validOptions.fileExtension, "json")

        let invalidOptions = ExportOptions(
            filename: "test.txt",
            imageMode: .inline,
            filterMode: .all,
            dubiousMinScore: 3
        )
        XCTAssertFalse(invalidOptions.isValidFormat)
        XCTAssertEqual(invalidOptions.fileExtension, "txt")
    }

    // MARK: - Filename Sanitization Tests

    func testSanitizeFilenameIntegration() {
        let testCases = [
            ("Normal Name", "Normal Name"),
            ("Name/With\\Slashes", "Name_With_Slashes"),
            ("Name:With*Special?Chars", "Name_With_Special_Chars"),
            ("Name\"With<Quotes>", "Name_With_Quotes_"),
            ("Name|With|Pipes", "Name_With_Pipes")
        ]

        for (input, expected) in testCases {
            let result = ContactScrubby.sanitizeFilename(input)
            XCTAssertEqual(result, expected, "Failed for: \(input)")
        }
    }

    // MARK: - Performance Tests

    func testLargeContactListPerformance() throws {
        let contacts = (0..<1000).map { index in
            SerializableContact(
                name: "Test User \(index)",
                namePrefix: nil,
                givenName: "Test",
                middleName: nil,
                familyName: "User",
                nameSuffix: nil,
                nickname: nil,
                phoneticGivenName: nil,
                phoneticMiddleName: nil,
                phoneticFamilyName: nil,
                organizationName: nil,
                departmentName: nil,
                jobTitle: nil,
                emails: [SerializableContact.LabeledValue(label: "work", value: "test\(index)@example.com")],
                phones: [],
                postalAddresses: [],
                urls: [],
                socialProfiles: [],
                instantMessageAddresses: [],
                birthday: nil,
                dates: [],
                contactType: "Person",
                hasImage: false,
                imageData: nil,
                thumbnailImageData: nil,
                note: nil
            )
        }

        let testFile = tempDirectory.appendingPathComponent("large_test.json")

        measure {
            try! ContactScrubby.exportAsJSON(contacts: contacts, to: testFile)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: testFile.path))

        let data = try Data(contentsOf: testFile)
        let jsonObject = try JSONSerialization.jsonObject(with: data)

        if let contactsArray = jsonObject as? [Any] {
            XCTAssertEqual(contactsArray.count, 1000)
        }
    }
}