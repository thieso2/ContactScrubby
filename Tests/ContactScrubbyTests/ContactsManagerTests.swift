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
        XCTAssertEqual(contact.contactType, "Person")
        XCTAssertFalse(contact.hasImage)
        XCTAssertNil(contact.imageData)
        XCTAssertNil(contact.thumbnailImageData)
        XCTAssertEqual(contact.note, "Test contact")
    }
    
    func testSerializableContactCodable() throws {
        let contact = SerializableContact(
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
            emails: [SerializableContact.LabeledValue(label: "home", value: "jane@gmail.com")],
            phones: [],
            postalAddresses: [],
            urls: [],
            socialProfiles: [],
            instantMessageAddresses: [],
            birthday: SerializableContact.DateInfo(day: 15, month: 6, year: 1990),
            dates: [],
            contactType: "Person",
            hasImage: true,
            imageData: "base64imagedata",
            thumbnailImageData: "base64thumbnaildata",
            note: nil
        )
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(contact)
        XCTAssertGreaterThan(data.count, 0)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedContact = try decoder.decode(SerializableContact.self, from: data)
        
        XCTAssertEqual(decodedContact.name, contact.name)
        XCTAssertEqual(decodedContact.givenName, contact.givenName)
        XCTAssertEqual(decodedContact.familyName, contact.familyName)
        XCTAssertEqual(decodedContact.emails.count, 1)
        XCTAssertEqual(decodedContact.emails[0].value, "jane@gmail.com")
        XCTAssertEqual(decodedContact.birthday?.day, 15)
        XCTAssertEqual(decodedContact.birthday?.month, 6)
        XCTAssertEqual(decodedContact.birthday?.year, 1990)
        XCTAssertTrue(decodedContact.hasImage)
        XCTAssertEqual(decodedContact.imageData, "base64imagedata")
        XCTAssertEqual(decodedContact.thumbnailImageData, "base64thumbnaildata")
    }
    
    // MARK: - ContactAnalysis Tests
    
    func testContactAnalysisCreation() {
        let mockContact = CNMutableContact()
        mockContact.givenName = "Test"
        mockContact.familyName = "User"
        
        let analysis = ContactsManager.ContactAnalysis(
            contact: mockContact,
            dubiousScore: 5,
            reasons: ["No phone number", "Only basic info"],
            isIncomplete: true,
            isSuspicious: false
        )
        
        XCTAssertEqual(analysis.contact.givenName, "Test")
        XCTAssertEqual(analysis.contact.familyName, "User")
        XCTAssertEqual(analysis.dubiousScore, 5)
        XCTAssertEqual(analysis.reasons.count, 2)
        XCTAssertTrue(analysis.reasons.contains("No phone number"))
        XCTAssertTrue(analysis.reasons.contains("Only basic info"))
        XCTAssertTrue(analysis.isIncomplete)
        XCTAssertFalse(analysis.isSuspicious)
    }
    
    func testContactAnalysisIsDubious() {
        let mockContact = CNMutableContact()
        
        let analysis = ContactsManager.ContactAnalysis(
            contact: mockContact,
            dubiousScore: 5,
            reasons: [],
            isIncomplete: false,
            isSuspicious: false
        )
        
        XCTAssertTrue(analysis.isDubious(minimumScore: 3))
        XCTAssertTrue(analysis.isDubious(minimumScore: 5))
        XCTAssertFalse(analysis.isDubious(minimumScore: 6))
        XCTAssertFalse(analysis.isDubious(minimumScore: 10))
    }
    
    // MARK: - Contact Analysis Logic Tests
    
    func testAnalyzeContactWithNoName() {
        let contact = CNMutableContact()
        // Empty name should trigger "No name provided" heuristic
        
        let analysis = contactsManager.analyzeContact(contact)
        
        XCTAssertGreaterThan(analysis.dubiousScore, 0)
        XCTAssertTrue(analysis.reasons.contains("No name provided"))
        XCTAssertTrue(analysis.isIncomplete)
    }
    
    func testAnalyzeContactWithSuspiciousName() {
        let contact = CNMutableContact()
        contact.givenName = "Facebook"
        contact.familyName = "User"
        
        let analysis = contactsManager.analyzeContact(contact)
        
        XCTAssertGreaterThan(analysis.dubiousScore, 0)
        XCTAssertTrue(analysis.reasons.contains("Generic or suspicious name pattern"))
        XCTAssertTrue(analysis.isSuspicious)
    }
    
    func testAnalyzeContactWithShortName() {
        let contact = CNMutableContact()
        contact.givenName = "A"
        contact.familyName = "B"
        
        let analysis = contactsManager.analyzeContact(contact)
        
        XCTAssertGreaterThan(analysis.dubiousScore, 0)
        XCTAssertTrue(analysis.reasons.contains("Very short name"))
        XCTAssertTrue(analysis.isSuspicious)
    }
    
    func testAnalyzeContactWithFacebookOnlyEmail() {
        let contact = CNMutableContact()
        contact.givenName = "John"
        contact.familyName = "Doe"
        
        let email = CNLabeledValue(label: CNLabelWork, value: "john.doe@facebook.com" as NSString)
        contact.emailAddresses = [email]
        
        let analysis = contactsManager.analyzeContact(contact)
        
        XCTAssertGreaterThan(analysis.dubiousScore, 0)
        XCTAssertTrue(analysis.reasons.contains("Only Facebook email, no other contact info"))
        XCTAssertTrue(analysis.isSuspicious)
    }
    
    func testAnalyzeContactWithNoReplyEmail() {
        let contact = CNMutableContact()
        contact.givenName = "System"
        contact.familyName = "Account"
        
        let email = CNLabeledValue(label: CNLabelWork, value: "noreply@example.com" as NSString)
        contact.emailAddresses = [email]
        
        let analysis = contactsManager.analyzeContact(contact)
        
        XCTAssertGreaterThan(analysis.dubiousScore, 0)
        XCTAssertTrue(analysis.reasons.contains("No-reply email address"))
        XCTAssertTrue(analysis.isSuspicious)
    }
    
    func testAnalyzeContactWithNumericEmail() {
        let contact = CNMutableContact()
        contact.givenName = "Test"
        contact.familyName = "User"
        
        let email = CNLabeledValue(label: CNLabelWork, value: "12345@example.com" as NSString)
        contact.emailAddresses = [email]
        
        let analysis = contactsManager.analyzeContact(contact)
        
        XCTAssertGreaterThan(analysis.dubiousScore, 0)
        XCTAssertTrue(analysis.reasons.contains("Numeric email username"))
        XCTAssertTrue(analysis.isSuspicious)
    }
    
    func testAnalyzeContactWithMissingBasicInfo() {
        let contact = CNMutableContact()
        contact.givenName = "John"
        contact.familyName = "Doe"
        // No email, no phone, no organization
        
        let analysis = contactsManager.analyzeContact(contact)
        
        XCTAssertGreaterThan(analysis.dubiousScore, 0)
        XCTAssertTrue(analysis.reasons.contains { $0.contains("Missing multiple basic fields") })
        XCTAssertTrue(analysis.isIncomplete)
    }
    
    func testAnalyzeContactWithOnlyBasicInfo() {
        let contact = CNMutableContact()
        contact.givenName = "Jane"
        contact.familyName = "Smith"
        
        let email = CNLabeledValue(label: CNLabelHome, value: "jane@example.com" as NSString)
        contact.emailAddresses = [email]
        
        let analysis = contactsManager.analyzeContact(contact)
        
        XCTAssertGreaterThan(analysis.dubiousScore, 0)
        XCTAssertTrue(analysis.reasons.contains("Only basic info (name + email)"))
        XCTAssertTrue(analysis.isIncomplete)
    }
    
    func testAnalyzeContactWithSuspiciousPhone() {
        let contact = CNMutableContact()
        contact.givenName = "Test"
        contact.familyName = "User"
        
        let phone = CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "555-1234"))
        contact.phoneNumbers = [phone]
        
        let analysis = contactsManager.analyzeContact(contact)
        
        XCTAssertGreaterThan(analysis.dubiousScore, 0)
        XCTAssertTrue(analysis.reasons.contains("Suspicious phone number pattern"))
        XCTAssertTrue(analysis.isSuspicious)
    }
    
    func testAnalyzeContactWithCompleteInfo() {
        let contact = CNMutableContact()
        contact.givenName = "John"
        contact.familyName = "Doe"
        contact.organizationName = "Apple Inc."
        
        let email = CNLabeledValue(label: CNLabelWork, value: "john.doe@apple.com" as NSString)
        contact.emailAddresses = [email]
        
        let phone = CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "123-456-7890"))
        contact.phoneNumbers = [phone]
        
        let address = CNMutablePostalAddress()
        address.street = "1 Apple Park Way"
        address.city = "Cupertino"
        address.state = "CA"
        address.postalCode = "95014"
        let postalAddress = CNLabeledValue(label: CNLabelWork, value: address as CNPostalAddress)
        contact.postalAddresses = [postalAddress]
        
        let analysis = contactsManager.analyzeContact(contact)
        
        // A complete contact should have a low dubious score
        XCTAssertLessThan(analysis.dubiousScore, 3)
        XCTAssertFalse(analysis.isDubious(minimumScore: 3))
    }
    
    // MARK: - Utility Function Tests
    
    func testSanitizeFilename() {
        let testCases = [
            ("John Doe", "John Doe"),
            ("John/Doe", "John_Doe"),
            ("John\\Doe", "John_Doe"),
            ("John:Doe", "John_Doe"),
            ("John*Doe", "John_Doe"),
            ("John?Doe", "John_Doe"),
            ("John\"Doe", "John_Doe"),
            ("John<Doe", "John_Doe"),
            ("John>Doe", "John_Doe"),
            ("John|Doe", "John_Doe"),
            ("John/\\:*?\"<>|Doe", "John_________Doe"),
            ("", ""),
            ("ValidName", "ValidName")
        ]
        
        for (input, expected) in testCases {
            let result = ContactScrubby.sanitizeFilename(input)
            XCTAssertEqual(result, expected, "Failed for input: '\(input)'")
        }
    }
    
    func testEscapeXML() {
        let testCases = [
            ("Hello", "Hello"),
            ("Hello & World", "Hello &amp; World"),
            ("Hello <World>", "Hello &lt;World&gt;"),
            ("Hello \"World\"", "Hello &quot;World&quot;"),
            ("Hello 'World'", "Hello &apos;World&apos;"),
            ("&<>\"'", "&amp;&lt;&gt;&quot;&apos;"),
            ("", ""),
            ("No special chars", "No special chars")
        ]
        
        for (input, expected) in testCases {
            let result = ContactScrubby.escapeXML(input)
            XCTAssertEqual(result, expected, "Failed for input: '\(input)'")
        }
    }
    
    func testGetEmptyMessage() {
        XCTAssertEqual(ContactScrubby.getEmptyMessage(for: .withEmail), "No contacts with email addresses found.")
        XCTAssertEqual(ContactScrubby.getEmptyMessage(for: .withoutEmail), "No contacts without email addresses found.")
        XCTAssertEqual(ContactScrubby.getEmptyMessage(for: .facebookOnly), "No contacts with @facebook.com email addresses found.")
        XCTAssertEqual(ContactScrubby.getEmptyMessage(for: .facebookExclusive), "No contacts with only @facebook.com email addresses and no phone numbers found.")
        XCTAssertEqual(ContactScrubby.getEmptyMessage(for: .dubious), "No dubious or incomplete contacts found.")
        XCTAssertEqual(ContactScrubby.getEmptyMessage(for: .all), "No contacts found.")
    }
    
    func testGetHeaderMessage() {
        XCTAssertEqual(ContactScrubby.getHeaderMessage(for: .withEmail), "Contacts with email addresses:")
        XCTAssertEqual(ContactScrubby.getHeaderMessage(for: .withoutEmail), "Contacts without email addresses:")
        XCTAssertEqual(ContactScrubby.getHeaderMessage(for: .facebookOnly), "Contacts with @facebook.com email addresses:")
        XCTAssertEqual(ContactScrubby.getHeaderMessage(for: .facebookExclusive), "Contacts with ONLY @facebook.com email addresses and no phone numbers:")
        XCTAssertEqual(ContactScrubby.getHeaderMessage(for: .dubious), "Dubious or incomplete contacts:")
        XCTAssertEqual(ContactScrubby.getHeaderMessage(for: .all), "All contacts:")
    }
    
    func testFormatLabel() {
        // Test with nil label
        XCTAssertEqual(ContactScrubby.formatLabel(nil), "")
        
        // Test with standard labels (these may be localized, so we test they're not empty)
        XCTAssertFalse(ContactScrubby.formatLabel(CNLabelWork).isEmpty)
        XCTAssertFalse(ContactScrubby.formatLabel(CNLabelHome).isEmpty)
        XCTAssertFalse(ContactScrubby.formatLabel(CNLabelPhoneNumberMobile).isEmpty)
        
        // Test with internal format labels
        let internalLabel = "_$!<TestLabel>!$_"
        XCTAssertEqual(ContactScrubby.formatLabel(internalLabel), "TestLabel")
        
        // Test with regular string
        XCTAssertEqual(ContactScrubby.formatLabel("Custom Label"), "Custom Label")
    }
}