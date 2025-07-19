import Testing
@testable import ContactScrubby

@Suite("Models Tests")
struct ModelsTests {

    // MARK: - FilterMode Tests

    @Test("FilterMode raw values")
    func filterModeRawValues() {
        #expect(FilterMode.withEmail.rawValue == "with-email")
        #expect(FilterMode.withoutEmail.rawValue == "no-email")
        #expect(FilterMode.facebookOnly.rawValue == "facebook")
        #expect(FilterMode.facebookExclusive.rawValue == "facebook-exclusive")
        #expect(FilterMode.dubious.rawValue == "dubious")
        #expect(FilterMode.all.rawValue == "all")
        #expect(FilterMode.noContact.rawValue == "no-contact")
    }

    @Test("FilterMode from string")
    func filterModeFromString() {
        #expect(FilterMode(rawValue: "with-email") == .withEmail)
        #expect(FilterMode(rawValue: "no-email") == .withoutEmail)
        #expect(FilterMode(rawValue: "facebook") == .facebookOnly)
        #expect(FilterMode(rawValue: "facebook-exclusive") == .facebookExclusive)
        #expect(FilterMode(rawValue: "dubious") == .dubious)
        #expect(FilterMode(rawValue: "all") == .all)
        #expect(FilterMode(rawValue: "no-contact") == .noContact)
        #expect(FilterMode(rawValue: "invalid") == nil)
    }

    @Test("FilterMode help")
    func filterModeHelp() {
        #expect(FilterMode.withEmail.help.contains("email addresses"))
        #expect(FilterMode.withoutEmail.help.contains("no email"))
        #expect(FilterMode.facebookOnly.help.contains("@facebook.com"))
        #expect(FilterMode.facebookExclusive.help.contains("ONLY @facebook.com"))
        #expect(FilterMode.dubious.help.contains("dubious"))
        #expect(FilterMode.all.help.contains("all contacts"))
        #expect(FilterMode.noContact.help.contains("no email AND no phone"))
    }

    @Test("FilterMode all cases")
    func filterModeAllCases() {
        let allCases = FilterMode.allCases
        #expect(allCases.count == 7)
        #expect(allCases.contains(.withEmail))
        #expect(allCases.contains(.withoutEmail))
        #expect(allCases.contains(.facebookOnly))
        #expect(allCases.contains(.facebookExclusive))
        #expect(allCases.contains(.dubious))
        #expect(allCases.contains(.all))
        #expect(allCases.contains(.noContact))
    }

    // MARK: - ImageMode Tests

    @Test("ImageMode raw values")
    func imageModeRawValues() {
        #expect(ImageMode.none.rawValue == "none")
        #expect(ImageMode.inline.rawValue == "inline")
        #expect(ImageMode.folder.rawValue == "folder")
    }

    @Test("ImageMode from string")
    func imageModeFromString() {
        #expect(ImageMode(rawValue: "none") == ImageMode.none)
        #expect(ImageMode(rawValue: "inline") == ImageMode.inline)
        #expect(ImageMode(rawValue: "folder") == ImageMode.folder)
        #expect(ImageMode(rawValue: "invalid") == nil)
    }

    @Test("ImageMode help")
    func imageModeHelp() {
        #expect(ImageMode.none.help.contains("Don't include"))
        #expect(ImageMode.inline.help.contains("Base64"))
        #expect(ImageMode.folder.help.contains("separate folder"))
    }

    @Test("ImageMode all cases")
    func imageModeAllCases() {
        let allCases = ImageMode.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.none))
        #expect(allCases.contains(.inline))
        #expect(allCases.contains(.folder))
    }

    // MARK: - ExportOptions Tests

    @Test("ExportOptions file URL")
    func exportOptionsFileURL() {
        let options = ExportOptions(
            filename: "test.json",
            imageMode: .none,
            filterMode: .all,
            dubiousMinScore: 3
        )
        #expect(options.fileURL.path.hasSuffix("test.json"))
    }

    @Test("ExportOptions file extension")
    func exportOptionsFileExtension() {
        let jsonOptions = ExportOptions(
            filename: "test.json",
            imageMode: .none,
            filterMode: .all,
            dubiousMinScore: 3
        )
        #expect(jsonOptions.fileExtension == "json")

        let xmlOptions = ExportOptions(
            filename: "test.XML",
            imageMode: .none,
            filterMode: .all,
            dubiousMinScore: 3
        )
        #expect(xmlOptions.fileExtension == "xml")
    }

    @Test("ExportOptions is valid format")
    func exportOptionsIsValidFormat() {
        let validJson = ExportOptions(
            filename: "test.json",
            imageMode: .none,
            filterMode: .all,
            dubiousMinScore: 3
        )
        #expect(validJson.isValidFormat == true)

        let validXml = ExportOptions(
            filename: "test.xml",
            imageMode: .none,
            filterMode: .all,
            dubiousMinScore: 3
        )
        #expect(validXml.isValidFormat == true)

        let invalid = ExportOptions(
            filename: "test.txt",
            imageMode: .none,
            filterMode: .all,
            dubiousMinScore: 3
        )
        #expect(invalid.isValidFormat == false)
    }

    // MARK: - GroupOptions Tests

    @Test("GroupOptions creation")
    func groupOptionsCreation() {
        let options = GroupOptions(
            groupName: "Test Group",
            filterMode: .dubious,
            dubiousMinScore: 5
        )
        #expect(options.groupName == "Test Group")
        #expect(options.filterMode == .dubious)
        #expect(options.dubiousMinScore == 5)
    }

    // MARK: - DisplayOptions Tests

    @Test("DisplayOptions creation")
    func displayOptionsCreation() {
        let options = DisplayOptions(
            filterMode: .withEmail,
            dubiousMinScore: 4,
            showAllFields: true
        )
        #expect(options.filterMode == .withEmail)
        #expect(options.dubiousMinScore == 4)
        #expect(options.showAllFields == true)
    }
}