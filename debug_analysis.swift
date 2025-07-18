import Foundation
import Contacts

let contact = CNMutableContact()
contact.givenName = "John"
contact.familyName = "Doe"

// Create a simple analysis to see what happens
let emails = contact.emailAddresses.map { $0.value as String }
let phones = contact.phoneNumbers.map { $0.value.stringValue }
let hasName = \!contact.givenName.isEmpty || \!contact.familyName.isEmpty

print("Has name: \(hasName)")
print("Emails: \(emails)")
print("Phones: \(phones)")
print("Organization: '\(contact.organizationName)'")

// Check what missingInfo would be
let missingInfo = [
    emails.isEmpty ? "email" : nil,
    phones.isEmpty ? "phone" : nil,
    contact.organizationName.isEmpty ? "organization" : nil
].compactMap { $0 }

print("Missing info: \(missingInfo)")
print("Missing info count: \(missingInfo.count)")
