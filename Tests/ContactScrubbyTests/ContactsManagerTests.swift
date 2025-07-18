import XCTest
import Contacts
@testable import ContactScrubby

final class ContactsManagerTests: XCTestCase {

    var contactsManager: ContactsManager!

    override func setUp() {
        super.setUp()
        contactsManager = ContactsManager()
    }

    override func tearDown() {
        contactsManager = nil
        super.tearDown()
    }

    // MARK: - SerializableContact Tests

    func testSerializableContactCreation() {
        let contact = SerializableContact(
            name: "John Doe",
            namePrefix: "Mr.",
            givenName: "John",
            middleName: "William",
            familyName: "Doe",
            nameSuffix: "Jr.",
            nickname: "Johnny",
            phoneticGivenName: nil,
            phoneticMiddleName: nil,
            phoneticFamilyName: nil,
            organizationName: "Apple Inc.",
            departmentName: "Engineering",
            jobTitle: "Software Engineer",
            emails: [SerializableContact.LabeledValue(label: "work", value: "john@apple.com")],
            phones: [SerializableContact.LabeledValue(label: "mobile", value: "+1234567890")],
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
            note: "Test contact"
        )

        XCTAssertEqual(contact.name, "John Doe")
        XCTAssertEqual(contact.namePrefix, "Mr.")
        XCTAssertEqual(contact.givenName, "John")
        XCTAssertEqual(contact.middleName, "William")
        XCTAssertEqual(contact.familyName, "Doe")
        XCTAssertEqual(contact.nameSuffix, "Jr.")
        XCTAssertEqual(contact.nickname, "Johnny")
        XCTAssertEqual(contact.organizationName, "Apple Inc.")
        XCTAssertEqual(contact.departmentName, "Engineering")
        XCTAssertEqual(contact.jobTitle, "Software Engineer")
        XCTAssertEqual(contact.emails.count, 1)
        XCTAssertEqual(contact.emails[0].label, "work")
        XCTAssertEqual(contact.emails[0].value, "john@apple.com")
        XCTAssertEqual(contact.phones.count, 1)
        XCTAssertEqual(contact.phones[0].label, "mobile")
        XCTAssertEqual(contact.phones[0].value, "+1234567890")
        XCTAssertEqual(contact.note, "Test contact")
        XCTAssertFalse(contact.hasImage)
    }

    func testSerializableContactCodable() throws {
        let originalContact = SerializableContact(
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
            emails: [SerializableContact.LabeledValue(label: "home", value: "jane@example.com")],
            phones: [],
            postalAddresses: [],
            urls: [],
            socialProfiles: [],
            instantMessageAddresses: [],
            birthday: SerializableContact.DateInfo(day: 15, month: 6, year: 1990),
            dates: [],
            contactType: "Person",
            hasImage: false,
            imageData: nil,
            thumbnailImageData: nil,
            note: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalContact)

        let decoder = JSONDecoder()
        let decodedContact = try decoder.decode(SerializableContact.self, from: data)

        XCTAssertEqual(decodedContact.name, originalContact.name)
        XCTAssertEqual(decodedContact.givenName, originalContact.givenName)
        XCTAssertEqual(decodedContact.familyName, originalContact.familyName)
        XCTAssertEqual(decodedContact.emails.count, originalContact.emails.count)
        XCTAssertEqual(decodedContact.birthday?.day, 15)
        XCTAssertEqual(decodedContact.birthday?.month, 6)
        XCTAssertEqual(decodedContact.birthday?.year, 1990)
    }

    // MARK: - ContactAnalysis Tests

    func testContactAnalysisCreation() {
        let contact = CNMutableContact()
        contact.givenName = "Test"
        contact.familyName = "User"

        let analysis = ContactAnalysis(
            contact: contact,
            dubiousScore: 5,
            reasons: ["Missing email", "Missing phone"],
            isIncomplete: true,
            isSuspicious: false
        )

        XCTAssertEqual(analysis.dubiousScore, 5)
        XCTAssertEqual(analysis.reasons.count, 2)
        XCTAssertTrue(analysis.isIncomplete)
        XCTAssertFalse(analysis.isSuspicious)
    }

    func testContactAnalysisIsDubious() {
        let contact = CNMutableContact()

        let lowScoreAnalysis = ContactAnalysis(
            contact: contact,
            dubiousScore: 2,
            reasons: [],
            isIncomplete: false,
            isSuspicious: false
        )

        let highScoreAnalysis = ContactAnalysis(
            contact: contact,
            dubiousScore: 5,
            reasons: [],
            isIncomplete: false,
            isSuspicious: false
        )

        XCTAssertFalse(lowScoreAnalysis.isDubious(minimumScore: 3))
        XCTAssertTrue(highScoreAnalysis.isDubious(minimumScore: 3))
        XCTAssertTrue(highScoreAnalysis.isDubious(minimumScore: 5))
        XCTAssertFalse(highScoreAnalysis.isDubious(minimumScore: 6))
    }

    // MARK: - Contact Analysis Tests

    func testAnalyzeContactWithCompleteInfo() {
        let contact = CNMutableContact()
        contact.givenName = "John"
        contact.familyName = "Doe"
        contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "john.doe@example.com" as NSString)]
        contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "+1234567890"))]
        contact.organizationName = "Example Corp"

        let analysis = contactsManager.analyzeContact(contact)

        XCTAssertEqual(analysis.dubiousScore, 0)
        XCTAssertTrue(analysis.reasons.isEmpty)
        XCTAssertFalse(analysis.isIncomplete)
        XCTAssertFalse(analysis.isSuspicious)
    }

    func testAnalyzeContactWithNoName() {
        let contact = CNMutableContact()
        contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "user@example.com" as NSString)]

        let analysis = contactsManager.analyzeContact(contact)

        XCTAssertGreaterThan(analysis.dubiousScore, 0)
        XCTAssertTrue(analysis.reasons.contains("No name"))
        XCTAssertTrue(analysis.isIncomplete)
    }

    func testAnalyzeContactWithOnlyBasicInfo() {
        let contact = CNMutableContact()
        contact.givenName = "John"
        contact.familyName = "Doe"

        let analysis = contactsManager.analyzeContact(contact)

        XCTAssertGreaterThan(analysis.dubiousScore, 0)
        XCTAssertTrue(analysis.reasons.contains("No email"))
        XCTAssertTrue(analysis.reasons.contains("No phone"))
        XCTAssertTrue(analysis.isIncomplete)
    }

    func testAnalyzeContactWithMissingBasicInfo() {
        let contact = CNMutableContact()
        contact.givenName = "John"
        // Missing family name
        contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "john@example.com" as NSString)]
        // Missing phone

        let analysis = contactsManager.analyzeContact(contact)

        XCTAssertGreaterThan(analysis.dubiousScore, 0)
        XCTAssertTrue(analysis.reasons.contains("Missing basic info"))
        XCTAssertTrue(analysis.isIncomplete)
    }

    func testAnalyzeContactWithFacebookOnlyEmail() {
        let contact = CNMutableContact()
        contact.givenName = "Facebook"
        contact.familyName = "User"
        contact.emailAddresses = [CNLabeledValue(label: CNLabelOther, value: "user@facebook.com" as NSString)]

        let analysis = contactsManager.analyzeContact(contact)

        XCTAssertGreaterThan(analysis.dubiousScore, 0)
        XCTAssertTrue(analysis.reasons.contains("Facebook-only email"))
        XCTAssertTrue(analysis.reasons.contains("No phone"))
        XCTAssertTrue(analysis.isSuspicious)
    }

    func testAnalyzeContactWithNoReplyEmail() {
        let contact = CNMutableContact()
        contact.givenName = "Service"
        contact.familyName = "Account"
        contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "noreply@example.com" as NSString)]

        let analysis = contactsManager.analyzeContact(contact)

        XCTAssertGreaterThan(analysis.dubiousScore, 0)
        XCTAssertTrue(analysis.reasons.contains("No-reply email"))
        XCTAssertTrue(analysis.isSuspicious)
    }

    func testAnalyzeContactWithSuspiciousPhone() {
        let contact = CNMutableContact()
        contact.givenName = "Test"
        contact.familyName = "User"
        contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "000-000-0000"))]

        let analysis = contactsManager.analyzeContact(contact)

        XCTAssertGreaterThan(analysis.dubiousScore, 0)
        XCTAssertTrue(analysis.reasons.contains("Suspicious phone"))
        XCTAssertTrue(analysis.isSuspicious)
    }

    func testAnalyzeContactWithNumericEmail() {
        let contact = CNMutableContact()
        contact.givenName = "User"
        contact.familyName = "Test"
        contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "12345@example.com" as NSString)]

        let analysis = contactsManager.analyzeContact(contact)

        XCTAssertGreaterThan(analysis.dubiousScore, 0)
        XCTAssertTrue(analysis.reasons.contains("Numeric/short email"))
        XCTAssertTrue(analysis.isSuspicious)
    }

    func testAnalyzeContactWithSuspiciousName() {
        let contact = CNMutableContact()
        contact.givenName = "aaa"
        contact.familyName = "bbb"
        contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "test@example.com" as NSString)]

        let analysis = contactsManager.analyzeContact(contact)

        XCTAssertGreaterThan(analysis.dubiousScore, 0)
        XCTAssertTrue(analysis.reasons.contains("Suspicious name pattern"))
        XCTAssertTrue(analysis.isSuspicious)
    }

    func testAnalyzeContactWithShortName() {
        let contact = CNMutableContact()
        contact.givenName = "J"
        contact.familyName = "D"
        contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "jd@example.com" as NSString)]

        let analysis = contactsManager.analyzeContact(contact)

        XCTAssertGreaterThan(analysis.dubiousScore, 0)
        XCTAssertTrue(analysis.reasons.contains("Very short name"))
        XCTAssertTrue(analysis.isSuspicious)
    }

    // MARK: - Utility Functions Tests

    func testFormatLabel() {
        XCTAssertEqual(ContactScrubby.formatLabel(CNLabelHome), "home")
        XCTAssertEqual(ContactScrubby.formatLabel(CNLabelWork), "work")
        XCTAssertEqual(ContactScrubby.formatLabel(CNLabelOther), "other")
        XCTAssertEqual(ContactScrubby.formatLabel(CNLabelPhoneNumberMobile), "mobile")
        XCTAssertEqual(ContactScrubby.formatLabel(CNLabelPhoneNumberMain), "main")
        XCTAssertEqual(ContactScrubby.formatLabel("_$!<Mobile>!$_"), "mobile")
        XCTAssertEqual(ContactScrubby.formatLabel("CustomLabel"), "CustomLabel")
        XCTAssertEqual(ContactScrubby.formatLabel(nil), "other")
        XCTAssertEqual(ContactScrubby.formatLabel(""), "other")
    }

    func testGetEmptyMessage() {
        XCTAssertEqual(ContactScrubby.getEmptyMessage(for: .withEmail), "No contacts with email addresses found.")
        XCTAssertEqual(ContactScrubby.getEmptyMessage(for: .withoutEmail), "No contacts without email addresses found.")
        XCTAssertEqual(ContactScrubby.getEmptyMessage(for: .facebookOnly), "No contacts with @facebook.com email addresses found.")
        XCTAssertEqual(ContactScrubby.getEmptyMessage(for: .facebookExclusive), "No contacts with only @facebook.com email addresses and no phone numbers found.")
        XCTAssertEqual(ContactScrubby.getEmptyMessage(for: .dubious), "No dubious or incomplete contacts found.")
        XCTAssertEqual(ContactScrubby.getEmptyMessage(for: .all), "No contacts found.")
        XCTAssertEqual(ContactScrubby.getEmptyMessage(for: .noContact), "No contacts without both email and phone numbers found.")
    }

    func testGetHeaderMessage() {
        XCTAssertEqual(ContactScrubby.getHeaderMessage(for: .withEmail), "Contacts with email addresses:")
        XCTAssertEqual(ContactScrubby.getHeaderMessage(for: .withoutEmail), "Contacts without email addresses:")
        XCTAssertEqual(ContactScrubby.getHeaderMessage(for: .facebookOnly), "Contacts with @facebook.com email addresses:")
        XCTAssertEqual(ContactScrubby.getHeaderMessage(for: .facebookExclusive), "Contacts with ONLY @facebook.com email addresses and no phone numbers:")
        XCTAssertEqual(ContactScrubby.getHeaderMessage(for: .dubious), "Dubious or incomplete contacts:")
        XCTAssertEqual(ContactScrubby.getHeaderMessage(for: .all), "All contacts:")
        XCTAssertEqual(ContactScrubby.getHeaderMessage(for: .noContact), "Contacts with no email AND no phone:")
    }

    func testSanitizeFilename() {
        XCTAssertEqual(ContactScrubby.sanitizeFilename("Normal Name"), "Normal Name")
        XCTAssertEqual(ContactScrubby.sanitizeFilename("Name/With\\Slashes"), "Name_With_Slashes")
        XCTAssertEqual(ContactScrubby.sanitizeFilename("Name:With*Special?Chars"), "Name_With_Special_Chars")
        XCTAssertEqual(ContactScrubby.sanitizeFilename("Name\"With<Quotes>"), "Name_With_Quotes_")
        XCTAssertEqual(ContactScrubby.sanitizeFilename("Name|With|Pipes"), "Name_With_Pipes")
        XCTAssertEqual(ContactScrubby.sanitizeFilename(""), "unnamed")
        XCTAssertEqual(ContactScrubby.sanitizeFilename("   "), "unnamed")
    }

    func testEscapeXML() {
        XCTAssertEqual(ContactScrubby.escapeXML("Normal text"), "Normal text")
        XCTAssertEqual(ContactScrubby.escapeXML("Text with & ampersand"), "Text with &amp; ampersand")
        XCTAssertEqual(ContactScrubby.escapeXML("Text with < and >"), "Text with &lt; and &gt;")
        XCTAssertEqual(ContactScrubby.escapeXML("Text with \"quotes\""), "Text with &quot;quotes&quot;")
        XCTAssertEqual(ContactScrubby.escapeXML("Text with 'apostrophe'"), "Text with &apos;apostrophe&apos;")
        XCTAssertEqual(ContactScrubby.escapeXML("All: & < > \" '"), "All: &amp; &lt; &gt; &quot; &apos;")
    }
}