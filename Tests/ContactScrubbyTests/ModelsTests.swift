import XCTest
@testable import ContactScrubby

final class ModelsTests: XCTestCase {

    // MARK: - FilterMode Tests

    func testFilterModeRawValues() {
        XCTAssertEqual(FilterMode.withEmail.rawValue, "with-email")
        XCTAssertEqual(FilterMode.withoutEmail.rawValue, "no-email")
        XCTAssertEqual(FilterMode.facebookOnly.rawValue, "facebook")
        XCTAssertEqual(FilterMode.facebookExclusive.rawValue, "facebook-exclusive")
        XCTAssertEqual(FilterMode.dubious.rawValue, "dubious")
        XCTAssertEqual(FilterMode.all.rawValue, "all")
        XCTAssertEqual(FilterMode.noContact.rawValue, "no-contact")
    }

    func testFilterModeFromString() {
        XCTAssertEqual(FilterMode(rawValue: "with-email"), .withEmail)
        XCTAssertEqual(FilterMode(rawValue: "no-email"), .withoutEmail)
        XCTAssertEqual(FilterMode(rawValue: "facebook"), .facebookOnly)
        XCTAssertEqual(FilterMode(rawValue: "facebook-exclusive"), .facebookExclusive)
        XCTAssertEqual(FilterMode(rawValue: "dubious"), .dubious)
        XCTAssertEqual(FilterMode(rawValue: "all"), .all)
        XCTAssertEqual(FilterMode(rawValue: "no-contact"), .noContact)
        XCTAssertNil(FilterMode(rawValue: "invalid"))
    }

    func testFilterModeHelp() {
        XCTAssertTrue(FilterMode.withEmail.help.contains("email addresses"))
        XCTAssertTrue(FilterMode.withoutEmail.help.contains("no email"))
        XCTAssertTrue(FilterMode.facebookOnly.help.contains("@facebook.com"))
        XCTAssertTrue(FilterMode.facebookExclusive.help.contains("ONLY @facebook.com"))
        XCTAssertTrue(FilterMode.dubious.help.contains("dubious"))
        XCTAssertTrue(FilterMode.all.help.contains("all contacts"))
        XCTAssertTrue(FilterMode.noContact.help.contains("no email AND no phone"))
    }

    func testFilterModeAllCases() {
        let allCases = FilterMode.allCases
        XCTAssertEqual(allCases.count, 7)
        XCTAssertTrue(allCases.contains(.withEmail))
        XCTAssertTrue(allCases.contains(.withoutEmail))
        XCTAssertTrue(allCases.contains(.facebookOnly))
        XCTAssertTrue(allCases.contains(.facebookExclusive))
        XCTAssertTrue(allCases.contains(.dubious))
        XCTAssertTrue(allCases.contains(.all))
        XCTAssertTrue(allCases.contains(.noContact))
    }

    // MARK: - ImageMode Tests

    func testImageModeRawValues() {
        XCTAssertEqual(ImageMode.none.rawValue, "none")
        XCTAssertEqual(ImageMode.inline.rawValue, "inline")
        XCTAssertEqual(ImageMode.folder.rawValue, "folder")
    }

    func testImageModeFromString() {
        XCTAssertEqual(ImageMode(rawValue: "none"), ImageMode.none)
        XCTAssertEqual(ImageMode(rawValue: "inline"), ImageMode.inline)
        XCTAssertEqual(ImageMode(rawValue: "folder"), ImageMode.folder)
        XCTAssertNil(ImageMode(rawValue: "invalid"))
    }

    func testImageModeHelp() {
        XCTAssertTrue(ImageMode.none.help.contains("Don't include"))
        XCTAssertTrue(ImageMode.inline.help.contains("Base64"))
        XCTAssertTrue(ImageMode.folder.help.contains("separate folder"))
    }

    func testImageModeAllCases() {
        let allCases = ImageMode.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.none))
        XCTAssertTrue(allCases.contains(.inline))
        XCTAssertTrue(allCases.contains(.folder))
    }

    // MARK: - ExportOptions Tests

    func testExportOptionsFileURL() {
        let options = ExportOptions(
            filename: "test.json",
            imageMode: .none,
            filterMode: .all,
            dubiousMinScore: 3
        )
        XCTAssertTrue(options.fileURL.path.hasSuffix("test.json"))
    }

    func testExportOptionsFileExtension() {
        let jsonOptions = ExportOptions(
            filename: "test.json",
            imageMode: .none,
            filterMode: .all,
            dubiousMinScore: 3
        )
        XCTAssertEqual(jsonOptions.fileExtension, "json")

        let xmlOptions = ExportOptions(
            filename: "test.XML",
            imageMode: .none,
            filterMode: .all,
            dubiousMinScore: 3
        )
        XCTAssertEqual(xmlOptions.fileExtension, "xml")
    }

    func testExportOptionsIsValidFormat() {
        let validJson = ExportOptions(
            filename: "test.json",
            imageMode: .none,
            filterMode: .all,
            dubiousMinScore: 3
        )
        XCTAssertTrue(validJson.isValidFormat)

        let validXml = ExportOptions(
            filename: "test.xml",
            imageMode: .none,
            filterMode: .all,
            dubiousMinScore: 3
        )
        XCTAssertTrue(validXml.isValidFormat)

        let invalid = ExportOptions(
            filename: "test.txt",
            imageMode: .none,
            filterMode: .all,
            dubiousMinScore: 3
        )
        XCTAssertFalse(invalid.isValidFormat)
    }

    // MARK: - GroupOptions Tests

    func testGroupOptionsCreation() {
        let options = GroupOptions(
            groupName: "Test Group",
            filterMode: .dubious,
            dubiousMinScore: 5
        )
        XCTAssertEqual(options.groupName, "Test Group")
        XCTAssertEqual(options.filterMode, .dubious)
        XCTAssertEqual(options.dubiousMinScore, 5)
    }

    // MARK: - DisplayOptions Tests

    func testDisplayOptionsCreation() {
        let options = DisplayOptions(
            filterMode: .withEmail,
            dubiousMinScore: 4,
            showAllFields: true
        )
        XCTAssertEqual(options.filterMode, .withEmail)
        XCTAssertEqual(options.dubiousMinScore, 4)
        XCTAssertTrue(options.showAllFields)
    }
}