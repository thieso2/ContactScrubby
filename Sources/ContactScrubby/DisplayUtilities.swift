import Foundation
import Contacts

struct DisplayUtilities {
    
    // MARK: - Label Formatting
    
    static func formatLabel(_ label: String?) -> String {
        guard let label = label else { return "" }
        
        // Use the Contacts framework's built-in localization
        let localizedLabel = CNLabeledValue<NSString>.localizedString(forLabel: label)
        
        // If it's still in the internal format, clean it up
        if localizedLabel.hasPrefix("_$!<") && localizedLabel.hasSuffix(">!$_") {
            let cleaned = localizedLabel
                .replacingOccurrences(of: "_$!<", with: "")
                .replacingOccurrences(of: ">!$_", with: "")
            return cleaned
        }
        
        return localizedLabel
    }
    
    // MARK: - Full Contact Details Display
    
    static func printFullContactDetails(_ contact: CNContact) {
        var nameComponents: [String] = []
        if contact.isKeyAvailable(CNContactNamePrefixKey) && !contact.namePrefix.isEmpty {
            nameComponents.append(contact.namePrefix)
        }
        if contact.isKeyAvailable(CNContactGivenNameKey) && !contact.givenName.isEmpty {
            nameComponents.append(contact.givenName)
        }
        if contact.isKeyAvailable(CNContactMiddleNameKey) && !contact.middleName.isEmpty {
            nameComponents.append(contact.middleName)
        }
        if contact.isKeyAvailable(CNContactFamilyNameKey) && !contact.familyName.isEmpty {
            nameComponents.append(contact.familyName)
        }
        if contact.isKeyAvailable(CNContactNameSuffixKey) && !contact.nameSuffix.isEmpty {
            nameComponents.append(contact.nameSuffix)
        }
        
        let fullName = nameComponents.joined(separator: " ")
        print("Full Name: \(fullName.isEmpty ? "No Name" : fullName)")
        
        if contact.isKeyAvailable(CNContactNicknameKey) && !contact.nickname.isEmpty {
            print("Nickname: \(contact.nickname)")
        }
        
        var phoneticComponents: [String] = []
        if contact.isKeyAvailable(CNContactPhoneticGivenNameKey) && !contact.phoneticGivenName.isEmpty {
            phoneticComponents.append(contact.phoneticGivenName)
        }
        if contact.isKeyAvailable(CNContactPhoneticMiddleNameKey) && !contact.phoneticMiddleName.isEmpty {
            phoneticComponents.append(contact.phoneticMiddleName)
        }
        if contact.isKeyAvailable(CNContactPhoneticFamilyNameKey) && !contact.phoneticFamilyName.isEmpty {
            phoneticComponents.append(contact.phoneticFamilyName)
        }
        if !phoneticComponents.isEmpty {
            print("Phonetic Name: \(phoneticComponents.joined(separator: " "))")
        }
        
        if contact.isKeyAvailable(CNContactOrganizationNameKey) && !contact.organizationName.isEmpty {
            print("Organization: \(contact.organizationName)")
        }
        
        if contact.isKeyAvailable(CNContactDepartmentNameKey) && !contact.departmentName.isEmpty {
            print("Department: \(contact.departmentName)")
        }
        
        if contact.isKeyAvailable(CNContactJobTitleKey) && !contact.jobTitle.isEmpty {
            print("Job Title: \(contact.jobTitle)")
        }
        
        if contact.isKeyAvailable(CNContactEmailAddressesKey) && !contact.emailAddresses.isEmpty {
            print("Email Addresses:")
            for email in contact.emailAddresses {
                let label = formatLabel(email.label)
                print("  \(label.isEmpty ? "Email" : label): \(email.value)")
            }
        }
        
        if contact.isKeyAvailable(CNContactPhoneNumbersKey) && !contact.phoneNumbers.isEmpty {
            print("Phone Numbers:")
            for phone in contact.phoneNumbers {
                let label = formatLabel(phone.label)
                print("  \(label.isEmpty ? "Phone" : label): \(phone.value.stringValue)")
            }
        }
        
        if contact.isKeyAvailable(CNContactPostalAddressesKey) && !contact.postalAddresses.isEmpty {
            print("Postal Addresses:")
            for address in contact.postalAddresses {
                let label = formatLabel(address.label)
                print("  \(label.isEmpty ? "Address" : label):")
                let value = address.value
                if !value.street.isEmpty { print("    Street: \(value.street)") }
                if !value.city.isEmpty { print("    City: \(value.city)") }
                if !value.state.isEmpty { print("    State: \(value.state)") }
                if !value.postalCode.isEmpty { print("    Postal Code: \(value.postalCode)") }
                if !value.country.isEmpty { print("    Country: \(value.country)") }
            }
        }
        
        if contact.isKeyAvailable(CNContactUrlAddressesKey) && !contact.urlAddresses.isEmpty {
            print("URLs:")
            for url in contact.urlAddresses {
                let label = formatLabel(url.label)
                print("  \(label.isEmpty ? "URL" : label): \(url.value)")
            }
        }
        
        if contact.isKeyAvailable(CNContactSocialProfilesKey) && !contact.socialProfiles.isEmpty {
            print("Social Profiles:")
            for profile in contact.socialProfiles {
                let value = profile.value
                let label = formatLabel(profile.label)
                print("  \(label.isEmpty ? value.service : label): \(value.service) - \(value.username)")
            }
        }
        
        if contact.isKeyAvailable(CNContactInstantMessageAddressesKey) && !contact.instantMessageAddresses.isEmpty {
            print("Instant Message:")
            for im in contact.instantMessageAddresses {
                let value = im.value
                let label = formatLabel(im.label)
                print("  \(label.isEmpty ? value.service : label): \(value.service) - \(value.username)")
            }
        }
        
        if contact.isKeyAvailable(CNContactBirthdayKey), let birthday = contact.birthday {
            print("Birthday: \(birthday.month ?? 0)/\(birthday.day ?? 0)/\(birthday.year ?? 0)")
        }
        
        if contact.isKeyAvailable(CNContactDatesKey) && !contact.dates.isEmpty {
            print("Important Dates:")
            for date in contact.dates {
                let dateComponents = date.value as DateComponents
                let label = formatLabel(date.label)
                print("  \(label.isEmpty ? "Date" : label): \(dateComponents.month ?? 0)/\(dateComponents.day ?? 0)/\(dateComponents.year ?? 0)")
            }
        }
        
        if contact.isKeyAvailable(CNContactTypeKey) && contact.contactType == .organization {
            print("Contact Type: Organization")
        } else {
            print("Contact Type: Person")
        }
        
        if contact.isKeyAvailable(CNContactImageDataAvailableKey) && contact.imageDataAvailable {
            print("Has Profile Image: Yes")
        }
        
        if contact.isKeyAvailable(CNContactNoteKey) && !contact.note.isEmpty {
            print("Notes: \(contact.note)")
        }
    }
}