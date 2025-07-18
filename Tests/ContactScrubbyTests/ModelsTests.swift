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
    }
    
    func testFilterModeFromString() {
        XCTAssertEqual(FilterMode(rawValue: "with-email"), .withEmail)
        XCTAssertEqual(FilterMode(rawValue: "no-email"), .withoutEmail)
        XCTAssertEqual(FilterMode(rawValue: "facebook"), .facebookOnly)
        XCTAssertEqual(FilterMode(rawValue: "facebook-exclusive"), .facebookExclusive)
        XCTAssertEqual(FilterMode(rawValue: "dubious"), .dubious)
        XCTAssertEqual(FilterMode(rawValue: "all"), .all)
        XCTAssertNil(FilterMode(rawValue: "invalid"))
    }
    
    func testFilterModeHelp() {
        XCTAssertTrue(FilterMode.withEmail.help.contains("email addresses"))
        XCTAssertTrue(FilterMode.withoutEmail.help.contains("no email"))
        XCTAssertTrue(FilterMode.facebookOnly.help.contains("@facebook.com"))
        XCTAssertTrue(FilterMode.facebookExclusive.help.contains("ONLY @facebook.com"))
        XCTAssertTrue(FilterMode.dubious.help.contains("dubious"))
        XCTAssertTrue(FilterMode.all.help.contains("all contacts"))
    }
    
    func testFilterModeAllCases() {
        let allCases = FilterMode.allCases
        XCTAssertEqual(allCases.count, 6)
        XCTAssertTrue(allCases.contains(.withEmail))
        XCTAssertTrue(allCases.contains(.withoutEmail))
        XCTAssertTrue(allCases.contains(.facebookOnly))
        XCTAssertTrue(allCases.contains(.facebookExclusive))
        XCTAssertTrue(allCases.contains(.dubious))
        XCTAssertTrue(allCases.contains(.all))
    }
    
    // MARK: - ImageMode Tests
    
    func testImageModeRawValues() {
        XCTAssertEqual(ImageMode.none.rawValue, "none")
        XCTAssertEqual(ImageMode.inline.rawValue, "inline")
        XCTAssertEqual(ImageMode.folder.rawValue, "folder")
    }
    
    func testImageModeFromString() {
        XCTAssertEqual(ImageMode(rawValue: "none"), ImageMode.none)
        XCTAssertEqual(ImageMode(rawValue: "inline"), .inline)
        XCTAssertEqual(ImageMode(rawValue: "folder"), .folder)
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
            filename: "/tmp/test.json",
            imageMode: .inline,
            filterMode: .all,
            dubiousMinScore: 3
        )
        
        XCTAssertEqual(options.fileURL.path, "/tmp/test.json")
        XCTAssertEqual(options.fileURL.lastPathComponent, "test.json")
    }
    
    func testExportOptionsFileExtension() {
        let jsonOptions = ExportOptions(
            filename: "/tmp/test.json",
            imageMode: .inline,
            filterMode: .all,
            dubiousMinScore: 3
        )
        XCTAssertEqual(jsonOptions.fileExtension, "json")
        
        let xmlOptions = ExportOptions(
            filename: "/tmp/test.XML",
            imageMode: .inline,
            filterMode: .all,
            dubiousMinScore: 3
        )
        XCTAssertEqual(xmlOptions.fileExtension, "xml")
        
        let noExtOptions = ExportOptions(
            filename: "/tmp/test",
            imageMode: .inline,
            filterMode: .all,
            dubiousMinScore: 3
        )
        XCTAssertEqual(noExtOptions.fileExtension, "")
    }
    
    func testExportOptionsIsValidFormat() {
        let jsonOptions = ExportOptions(
            filename: "/tmp/test.json",
            imageMode: .inline,
            filterMode: .all,
            dubiousMinScore: 3
        )
        XCTAssertTrue(jsonOptions.isValidFormat)
        
        let xmlOptions = ExportOptions(
            filename: "/tmp/test.xml",
            imageMode: .inline,
            filterMode: .all,
            dubiousMinScore: 3
        )
        XCTAssertTrue(xmlOptions.isValidFormat)
        
        let invalidOptions = ExportOptions(
            filename: "/tmp/test.txt",
            imageMode: .inline,
            filterMode: .all,
            dubiousMinScore: 3
        )
        XCTAssertFalse(invalidOptions.isValidFormat)
        
        let noExtOptions = ExportOptions(
            filename: "/tmp/test",
            imageMode: .inline,
            filterMode: .all,
            dubiousMinScore: 3
        )
        XCTAssertFalse(noExtOptions.isValidFormat)
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
            filterMode: .facebookOnly,
            dubiousMinScore: 2,
            showAllFields: true
        )
        
        XCTAssertEqual(options.filterMode, .facebookOnly)
        XCTAssertEqual(options.dubiousMinScore, 2)
        XCTAssertTrue(options.showAllFields)
    }
}