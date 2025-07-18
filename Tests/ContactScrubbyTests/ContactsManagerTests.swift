import Testing
import Contacts
@testable import ContactScrubby

@Suite("ContactsManager Tests")
struct ContactsManagerTests {

    // MARK: - SerializableContact Tests

    @Test("SerializableContact creation")
    func serializableContactCreation() {
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

        #expect(contact.name == "John Doe")
        #expect(contact.namePrefix == "Mr.")
        #expect(contact.givenName == "John")
        #expect(contact.middleName == "William")
        #expect(contact.familyName == "Doe")
        #expect(contact.nameSuffix == "Jr.")
        #expect(contact.nickname == "Johnny")
        #expect(contact.organizationName == "Apple Inc.")
        #expect(contact.departmentName == "Engineering")
        #expect(contact.jobTitle == "Software Engineer")
        #expect(contact.emails.count == 1)
        #expect(contact.emails[0].label == "work")
        #expect(contact.emails[0].value == "john@apple.com")
        #expect(contact.phones.count == 1)
        #expect(contact.phones[0].label == "mobile")
        #expect(contact.phones[0].value == "+1234567890")
        #expect(contact.note == "Test contact")
        #expect(contact.hasImage == false)
    }

    @Test("SerializableContact Codable")
    func serializableContactCodable() throws {
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

        #expect(decodedContact.name == originalContact.name)
        #expect(decodedContact.givenName == originalContact.givenName)
        #expect(decodedContact.familyName == originalContact.familyName)
        #expect(decodedContact.emails.count == originalContact.emails.count)
        #expect(decodedContact.birthday?.day == 15)
        #expect(decodedContact.birthday?.month == 6)
        #expect(decodedContact.birthday?.year == 1990)
    }

    // MARK: - ContactAnalysis Tests

    @Test("ContactAnalysis creation")
    func contactAnalysisCreation() {
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

        #expect(analysis.dubiousScore == 5)
        #expect(analysis.reasons.count == 2)
        #expect(analysis.isIncomplete == true)
        #expect(analysis.isSuspicious == false)
    }

    @Test("ContactAnalysis isDubious")
    func contactAnalysisIsDubious() {
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

        #expect(lowScoreAnalysis.isDubious(minimumScore: 3) == false)
        #expect(highScoreAnalysis.isDubious(minimumScore: 3) == true)
        #expect(highScoreAnalysis.isDubious(minimumScore: 5) == true)
        #expect(highScoreAnalysis.isDubious(minimumScore: 6) == false)
    }

    // MARK: - Contact Analysis Tests

    @Test("Analyze contact with complete info")
    func analyzeContactWithCompleteInfo() {
        let contact = CNMutableContact()
        contact.givenName = "John"
        contact.familyName = "Doe"
        contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "john.doe@example.com" as NSString)]
        contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "+1-617-123-4567"))]
        contact.organizationName = "Example Corp"

        let contactsManager = ContactsManager()
        let analysis = contactsManager.analyzeContact(contact)

        #expect(analysis.dubiousScore == 0)
        #expect(analysis.reasons.isEmpty == true)
        #expect(analysis.isIncomplete == false)
        #expect(analysis.isSuspicious == false)
    }

    @Test("Analyze contact with no name")
    func analyzeContactWithNoName() {
        let contact = CNMutableContact()
        contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "user@example.com" as NSString)]

        let contactsManager = ContactsManager()
        let analysis = contactsManager.analyzeContact(contact)

        #expect(analysis.dubiousScore > 0)
        #expect(analysis.reasons.contains("No name provided"))
        #expect(analysis.isIncomplete == true)
    }

    @Test("Analyze contact with only basic info")
    func analyzeContactWithOnlyBasicInfo() {
        let contact = CNMutableContact()
        contact.givenName = "John"
        contact.familyName = "Doe"

        let contactsManager = ContactsManager()
        let analysis = contactsManager.analyzeContact(contact)

        #expect(analysis.dubiousScore > 0)
        #expect(analysis.reasons.contains("Missing multiple basic fields: email, phone, organization"))
        #expect(analysis.isIncomplete == true)
    }

    @Test("Analyze contact with missing basic info")
    func analyzeContactWithMissingBasicInfo() {
        let contact = CNMutableContact()
        contact.givenName = "John"
        // Missing family name
        contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "john@example.com" as NSString)]
        // Missing phone

        let contactsManager = ContactsManager()
        let analysis = contactsManager.analyzeContact(contact)

        #expect(analysis.dubiousScore > 0)
        #expect(analysis.reasons.contains("Missing multiple basic fields: phone, organization"))
        #expect(analysis.isIncomplete == true)
    }

    @Test("Analyze contact with Facebook-only email")
    func analyzeContactWithFacebookOnlyEmail() {
        let contact = CNMutableContact()
        contact.givenName = "Facebook"
        contact.familyName = "User"
        contact.emailAddresses = [CNLabeledValue(label: CNLabelOther, value: "user@facebook.com" as NSString)]

        let contactsManager = ContactsManager()
        let analysis = contactsManager.analyzeContact(contact)

        #expect(analysis.dubiousScore > 0)
        #expect(analysis.reasons.contains("Only Facebook email, no other contact info"))
        #expect(analysis.isSuspicious == true)
    }

    @Test("Analyze contact with no-reply email")
    func analyzeContactWithNoReplyEmail() {
        let contact = CNMutableContact()
        contact.givenName = "Service"
        contact.familyName = "Account"
        contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "noreply@example.com" as NSString)]

        let contactsManager = ContactsManager()
        let analysis = contactsManager.analyzeContact(contact)

        #expect(analysis.dubiousScore > 0)
        #expect(analysis.reasons.contains("No-reply email address"))
        #expect(analysis.isSuspicious == true)
    }

    @Test("Analyze contact with suspicious phone")
    func analyzeContactWithSuspiciousPhone() {
        let contact = CNMutableContact()
        contact.givenName = "Test"
        contact.familyName = "User"
        contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "000-000-0000"))]

        let contactsManager = ContactsManager()
        let analysis = contactsManager.analyzeContact(contact)

        #expect(analysis.dubiousScore > 0)
        #expect(analysis.reasons.contains("Suspicious phone number pattern"))
        #expect(analysis.isSuspicious == true)
    }

    @Test("Analyze contact with numeric email")
    func analyzeContactWithNumericEmail() {
        let contact = CNMutableContact()
        contact.givenName = "User"
        contact.familyName = "Test"
        contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "12345@example.com" as NSString)]

        let contactsManager = ContactsManager()
        let analysis = contactsManager.analyzeContact(contact)

        #expect(analysis.dubiousScore > 0)
        #expect(analysis.reasons.contains("Numeric email username"))
        #expect(analysis.isSuspicious == true)
    }

    @Test("Analyze contact with suspicious name")
    func analyzeContactWithSuspiciousName() {
        let contact = CNMutableContact()
        contact.givenName = "aaa"
        contact.familyName = "bbb"
        contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "test@example.com" as NSString)]

        let contactsManager = ContactsManager()
        let analysis = contactsManager.analyzeContact(contact)

        #expect(analysis.dubiousScore > 0)
        #expect(analysis.reasons.contains("Unusual capitalization"))
        #expect(analysis.isIncomplete == true)
    }

    @Test("Analyze contact with short name")
    func analyzeContactWithShortName() {
        let contact = CNMutableContact()
        contact.givenName = "J"
        contact.familyName = "D"
        contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "jd@example.com" as NSString)]

        let contactsManager = ContactsManager()
        let analysis = contactsManager.analyzeContact(contact)

        #expect(analysis.dubiousScore > 0)
        #expect(analysis.reasons.contains("Very short name"))
        #expect(analysis.isSuspicious == true)
    }

    // MARK: - Utility Functions Tests

    @Test("Format label")
    func formatLabel() {
        #expect(ContactScrubby.formatLabel(CNLabelHome) == "home")
        #expect(ContactScrubby.formatLabel(CNLabelWork) == "work")
        #expect(ContactScrubby.formatLabel(CNLabelOther) == "other")
        #expect(ContactScrubby.formatLabel(CNLabelPhoneNumberMobile) == "mobile")
        #expect(ContactScrubby.formatLabel(CNLabelPhoneNumberMain) == "main")
        #expect(ContactScrubby.formatLabel("_$!<Mobile>!$_") == "mobile")
        #expect(ContactScrubby.formatLabel("CustomLabel") == "CustomLabel")
        #expect(ContactScrubby.formatLabel(nil) == "other")
        #expect(ContactScrubby.formatLabel("") == "other")
    }

    @Test("Get empty message")
    func getEmptyMessage() {
        #expect(ContactScrubby.getEmptyMessage(for: .withEmail) == "No contacts with email addresses found.")
        #expect(ContactScrubby.getEmptyMessage(for: .withoutEmail) == "No contacts without email addresses found.")
        #expect(ContactScrubby.getEmptyMessage(for: .facebookOnly) == "No contacts with @facebook.com email addresses found.")
        #expect(ContactScrubby.getEmptyMessage(for: .facebookExclusive) == "No contacts with only @facebook.com email addresses and no phone numbers found.")
        #expect(ContactScrubby.getEmptyMessage(for: .dubious) == "No dubious or incomplete contacts found.")
        #expect(ContactScrubby.getEmptyMessage(for: .all) == "No contacts found.")
        #expect(ContactScrubby.getEmptyMessage(for: .noContact) == "No contacts without both email and phone numbers found.")
    }

    @Test("Get header message")
    func getHeaderMessage() {
        #expect(ContactScrubby.getHeaderMessage(for: .withEmail) == "Contacts with email addresses:")
        #expect(ContactScrubby.getHeaderMessage(for: .withoutEmail) == "Contacts without email addresses:")
        #expect(ContactScrubby.getHeaderMessage(for: .facebookOnly) == "Contacts with @facebook.com email addresses:")
        #expect(ContactScrubby.getHeaderMessage(for: .facebookExclusive) == "Contacts with ONLY @facebook.com email addresses and no phone numbers:")
        #expect(ContactScrubby.getHeaderMessage(for: .dubious) == "Dubious or incomplete contacts:")
        #expect(ContactScrubby.getHeaderMessage(for: .all) == "All contacts:")
        #expect(ContactScrubby.getHeaderMessage(for: .noContact) == "Contacts with no email AND no phone:")
    }

    @Test("Sanitize filename")
    func sanitizeFilename() {
        #expect(ContactScrubby.sanitizeFilename("Normal Name") == "Normal Name")
        #expect(ContactScrubby.sanitizeFilename("Name/With\\Slashes") == "Name_With_Slashes")
        #expect(ContactScrubby.sanitizeFilename("Name:With*Special?Chars") == "Name_With_Special_Chars")
        #expect(ContactScrubby.sanitizeFilename("Name\"With<Quotes>") == "Name_With_Quotes_")
        #expect(ContactScrubby.sanitizeFilename("Name|With|Pipes") == "Name_With_Pipes")
        #expect(ContactScrubby.sanitizeFilename("") == "unnamed")
        #expect(ContactScrubby.sanitizeFilename("   ") == "unnamed")
    }

    @Test("Escape XML")
    func escapeXML() {
        #expect(ContactScrubby.escapeXML("Normal text") == "Normal text")
        #expect(ContactScrubby.escapeXML("Text with & ampersand") == "Text with &amp; ampersand")
        #expect(ContactScrubby.escapeXML("Text with < and >") == "Text with &lt; and &gt;")
        #expect(ContactScrubby.escapeXML("Text with \"quotes\"") == "Text with &quot;quotes&quot;")
        #expect(ContactScrubby.escapeXML("Text with 'apostrophe'") == "Text with &apos;apostrophe&apos;")
        #expect(ContactScrubby.escapeXML("All: & < > \" '") == "All: &amp; &lt; &gt; &quot; &apos;")
    }
}