import Testing
@testable import ContactScrubby

@Suite("Basic Tests")
struct BasicTests {
    
    @Test("ContactScrubby command configuration")
    func commandConfiguration() {
        let config = ContactScrubby.configuration
        #expect(config.commandName == "contactscrub")
        #expect(config.abstract == "A modern, powerful contact management and analysis tool")
    }
    
    @Test("FilterMode enum values")
    func filterModeValues() {
        #expect(FilterMode.all.rawValue == "all")
        #expect(FilterMode.dubious.rawValue == "dubious")
        #expect(FilterMode.withEmail.rawValue == "with-email")
        #expect(FilterMode.withoutEmail.rawValue == "no-email")
        #expect(FilterMode.facebookOnly.rawValue == "facebook-only")
        #expect(FilterMode.facebookExclusive.rawValue == "facebook-exclusive")
        #expect(FilterMode.noContact.rawValue == "no-contact")
    }
    
    @Test("ImageExportStrategy enum values")
    func imageExportStrategyValues() {
        #expect(ImageExportStrategy.none.rawValue == "none")
        #expect(ImageExportStrategy.inline.rawValue == "inline")
        #expect(ImageExportStrategy.folder.rawValue == "folder")
    }
    
    @Test("ExportFormat enum values")
    func exportFormatValues() {
        #expect(ExportFormat.json.rawValue == "json")
        #expect(ExportFormat.xml.rawValue == "xml")
        #expect(ExportFormat.vcf.rawValue == "vcf")
    }
    
    @Test("ContactID creation")
    func contactIDCreation() {
        let id: ContactID = "test-id"
        #expect(id.value == "test-id")
    }
    
    @Test("ContactFilter creation")
    func contactFilterCreation() {
        let filter = ContactFilter(mode: .all)
        #expect(filter.mode == .all)
        #expect(filter.dubiousScore == 3) // default value
    }
    
    @Test("DependencyContainer creation")
    @MainActor func dependencyContainerCreation() {
        let container = DependencyContainer()
        let contactManager = container.makeContactManager()
        #expect(contactManager is ModernContactsManager)
    }
}