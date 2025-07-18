import Foundation
import Contacts

// Create a contact
let contact = CNMutableContact()
contact.givenName = "John"
contact.familyName = "Doe"
contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "john.doe@example.com" as NSString)]
contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "+1234567890"))]
contact.organizationName = "Example Corp"

// Test the scoring logic
let emails = contact.emailAddresses.map { $0.value as String }
let phones = contact.phoneNumbers.map { $0.value.stringValue }
let hasName = \!contact.givenName.isEmpty || \!contact.familyName.isEmpty

let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
print("Full name: '\(fullName)'")
print("Full name length after removing spaces: \(fullName.replacingOccurrences(of: " ", with: "").count)")

let suspiciousNames = ["facebook user", "unknown", "user", "contact", "friend", "no name", "temp", "test"]
let containsSuspicious = suspiciousNames.contains(where: { fullName.lowercased().contains($0) })
print("Contains suspicious name: \(containsSuspicious)")

let isShort = fullName.replacingOccurrences(of: " ", with: "").count <= 2
print("Is short name: \(isShort)")
