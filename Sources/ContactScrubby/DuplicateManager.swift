import Foundation
import Contacts

struct DuplicateManager {
    
    // MARK: - Duplicate Detection
    
    /// Find all duplicate contacts using smart matching algorithms
    static func findDuplicates(in contacts: [CNContact], strategy: MergeStrategy = .conservative) -> [DuplicateGroup] {
        var groups: [DuplicateGroup] = []
        var processedContacts: Set<String> = []
        
        for (index, contact) in contacts.enumerated() {
            guard !processedContacts.contains(contact.identifier) else { continue }
            
            var duplicateGroup = [contact]
            processedContacts.insert(contact.identifier)
            
            // Find duplicates for this contact
            for otherIndex in (index + 1)..<contacts.count {
                let otherContact = contacts[otherIndex]
                guard !processedContacts.contains(otherContact.identifier) else { continue }
                
                if let match = detectDuplicate(contact, otherContact) {
                    let confidenceThreshold = strategy == .conservative ? 0.8 : 0.6
                    
                    if match.confidence >= confidenceThreshold {
                        duplicateGroup.append(otherContact)
                        processedContacts.insert(otherContact.identifier)
                    }
                }
            }
            
            // Only create group if we found duplicates
            if duplicateGroup.count > 1 {
                let primary = selectPrimaryContact(from: duplicateGroup)
                let duplicates = duplicateGroup.filter { $0.identifier != primary.identifier }
                let confidence = calculateGroupConfidence(duplicateGroup)
                let totalFields = duplicateGroup.reduce(0) { $0 + countFields($1) }
                
                groups.append(DuplicateGroup(
                    contacts: duplicateGroup,
                    primaryContact: primary,
                    duplicates: duplicates,
                    confidence: confidence,
                    totalFields: totalFields
                ))
            }
        }
        
        return groups.sorted { $0.confidence > $1.confidence }
    }
    
    /// Detect if two contacts are duplicates
    static func detectDuplicate(_ contact1: CNContact, _ contact2: CNContact) -> DuplicateMatch? {
        var matchingFields: [String] = []
        var conflictingFields: [String] = []
        var confidence: Double = 0.0
        var matchType: DuplicateMatchType = .exact
        
        // Name matching
        let nameMatch = compareNames(contact1, contact2)
        if nameMatch.isMatch {
            matchingFields.append("name")
            confidence += nameMatch.confidence * 0.4 // Names are 40% of total confidence
            matchType = nameMatch.type
        } else {
            conflictingFields.append("name")
        }
        
        // Email matching
        let emailMatch = compareEmails(contact1, contact2)
        if emailMatch.hasSharedEmails {
            matchingFields.append("email")
            confidence += emailMatch.confidence * 0.3 // Emails are 30% of total confidence
            
            // If names don't match but emails do, it's a contact info match
            if !nameMatch.isMatch && emailMatch.confidence > 0.8 {
                matchType = .contactInfo
            }
        }
        
        // Phone matching
        let phoneMatch = comparePhones(contact1, contact2)
        if phoneMatch.hasSharedPhones {
            matchingFields.append("phone")
            confidence += phoneMatch.confidence * 0.2 // Phones are 20% of total confidence
            
            // If names don't match but phones do, it's a contact info match
            if !nameMatch.isMatch && phoneMatch.confidence > 0.8 {
                matchType = .contactInfo
            }
        }
        
        // Organization matching
        let orgMatch = compareOrganizations(contact1, contact2)
        if orgMatch.isMatch {
            matchingFields.append("organization")
            confidence += orgMatch.confidence * 0.1 // Organizations are 10% of total confidence
        }
        
        // Minimum confidence threshold
        guard confidence >= 0.5 else { return nil }
        
        return DuplicateMatch(
            contact1: contact1,
            contact2: contact2,
            matchType: matchType,
            confidence: confidence,
            matchingFields: matchingFields,
            conflictingFields: conflictingFields
        )
    }
    
    // MARK: - Name Comparison
    
    static func compareNames(_ contact1: CNContact, _ contact2: CNContact) -> (isMatch: Bool, confidence: Double, type: DuplicateMatchType) {
        let name1 = getFullName(contact1)
        let name2 = getFullName(contact2)
        
        // Exact match
        if name1.lowercased() == name2.lowercased() {
            return (true, 1.0, .exact)
        }
        
        // Check if one is a subset of the other (e.g., "John Smith" vs "John")
        let words1 = name1.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let words2 = name2.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        if words1.count != words2.count {
            let shorterWords = words1.count < words2.count ? words1 : words2
            let longerWords = words1.count < words2.count ? words2 : words1
            
            let matchedWords = shorterWords.filter { word in
                longerWords.contains { $0.contains(word) || word.contains($0) }
            }
            
            if matchedWords.count == shorterWords.count {
                return (true, 0.85, .fuzzy)
            }
        }
        
        // Fuzzy string matching (Levenshtein distance)
        let distance = levenshteinDistance(name1.lowercased(), name2.lowercased())
        let maxLength = max(name1.count, name2.count)
        
        if maxLength > 0 {
            let similarity = 1.0 - (Double(distance) / Double(maxLength))
            
            if similarity >= 0.8 {
                return (true, similarity, .fuzzy)
            }
            
            // Check phonetic similarity for names that sound similar
            if similarity >= 0.6 && soundsLike(name1, name2) {
                return (true, similarity * 0.9, .phonetic)
            }
        }
        
        return (false, 0.0, .exact)
    }
    
    // MARK: - Contact Info Comparison
    
    static func compareEmails(_ contact1: CNContact, _ contact2: CNContact) -> (hasSharedEmails: Bool, confidence: Double) {
        let emails1 = Set(contact1.emailAddresses.map { ($0.value as String).lowercased() })
        let emails2 = Set(contact2.emailAddresses.map { ($0.value as String).lowercased() })
        
        let intersection = emails1.intersection(emails2)
        
        if intersection.isEmpty {
            return (false, 0.0)
        }
        
        let union = emails1.union(emails2)
        let jaccardSimilarity = Double(intersection.count) / Double(union.count)
        
        return (true, jaccardSimilarity)
    }
    
    static func comparePhones(_ contact1: CNContact, _ contact2: CNContact) -> (hasSharedPhones: Bool, confidence: Double) {
        let phones1 = Set(contact1.phoneNumbers.map { normalizePhoneNumber($0.value.stringValue) })
        let phones2 = Set(contact2.phoneNumbers.map { normalizePhoneNumber($0.value.stringValue) })
        
        let intersection = phones1.intersection(phones2)
        
        if intersection.isEmpty {
            return (false, 0.0)
        }
        
        let union = phones1.union(phones2)
        let jaccardSimilarity = Double(intersection.count) / Double(union.count)
        
        return (true, jaccardSimilarity)
    }
    
    static func compareOrganizations(_ contact1: CNContact, _ contact2: CNContact) -> (isMatch: Bool, confidence: Double) {
        let org1 = contact1.organizationName.lowercased()
        let org2 = contact2.organizationName.lowercased()
        
        if org1.isEmpty || org2.isEmpty {
            return (false, 0.0)
        }
        
        if org1 == org2 {
            return (true, 1.0)
        }
        
        // Check if one contains the other
        if org1.contains(org2) || org2.contains(org1) {
            return (true, 0.8)
        }
        
        return (false, 0.0)
    }
    
    // MARK: - Merge Operations
    
    /// Merge a group of duplicate contacts
    static func mergeDuplicateGroup(_ group: DuplicateGroup, strategy: MergeStrategy = .mostComplete) -> MergeResult {
        let mergedContact = createMergedContact(from: group.contacts, strategy: strategy)
        
        return MergeResult(
            mergedContact: mergedContact,
            originalContacts: group.contacts,
            conflictsResolved: [],
            fieldsMerged: countFields(mergedContact),
            success: true,
            error: nil
        )
    }
    
    /// Create a merged contact from multiple contacts
    static func createMergedContact(from contacts: [CNContact], strategy: MergeStrategy) -> CNContact {
        guard !contacts.isEmpty else { return CNContact() }
        
        let mutableContact = contacts[0].mutableCopy() as! CNMutableContact
        
        // Merge name fields (prefer most complete)
        for contact in contacts[1...] {
            if mutableContact.namePrefix.isEmpty && !contact.namePrefix.isEmpty {
                mutableContact.namePrefix = contact.namePrefix
            }
            if mutableContact.givenName.isEmpty && !contact.givenName.isEmpty {
                mutableContact.givenName = contact.givenName
            }
            if mutableContact.middleName.isEmpty && !contact.middleName.isEmpty {
                mutableContact.middleName = contact.middleName
            }
            if mutableContact.familyName.isEmpty && !contact.familyName.isEmpty {
                mutableContact.familyName = contact.familyName
            }
            if mutableContact.nameSuffix.isEmpty && !contact.nameSuffix.isEmpty {
                mutableContact.nameSuffix = contact.nameSuffix
            }
            if mutableContact.nickname.isEmpty && !contact.nickname.isEmpty {
                mutableContact.nickname = contact.nickname
            }
        }
        
        // Merge email addresses (union of all unique emails)
        var allEmails = Set<String>()
        var emailEntries: [CNLabeledValue<NSString>] = []
        
        for contact in contacts {
            for email in contact.emailAddresses {
                let emailString = email.value as String
                if !allEmails.contains(emailString.lowercased()) {
                    allEmails.insert(emailString.lowercased())
                    emailEntries.append(email)
                }
            }
        }
        mutableContact.emailAddresses = emailEntries
        
        // Merge phone numbers (union of all unique phones)
        var allPhones = Set<String>()
        var phoneEntries: [CNLabeledValue<CNPhoneNumber>] = []
        
        for contact in contacts {
            for phone in contact.phoneNumbers {
                let phoneString = normalizePhoneNumber(phone.value.stringValue)
                if !allPhones.contains(phoneString) {
                    allPhones.insert(phoneString)
                    phoneEntries.append(phone)
                }
            }
        }
        mutableContact.phoneNumbers = phoneEntries
        
        // Merge other fields (prefer most complete)
        for contact in contacts[1...] {
            if mutableContact.organizationName.isEmpty && !contact.organizationName.isEmpty {
                mutableContact.organizationName = contact.organizationName
            }
            if mutableContact.departmentName.isEmpty && !contact.departmentName.isEmpty {
                mutableContact.departmentName = contact.departmentName
            }
            if mutableContact.jobTitle.isEmpty && !contact.jobTitle.isEmpty {
                mutableContact.jobTitle = contact.jobTitle
            }
            if mutableContact.note.isEmpty && !contact.note.isEmpty {
                mutableContact.note = contact.note
            }
        }
        
        // Merge addresses, URLs, social profiles (union of all)
        var allAddresses = mutableContact.postalAddresses
        var allUrls = mutableContact.urlAddresses
        var allSocialProfiles = mutableContact.socialProfiles
        
        for contact in contacts[1...] {
            allAddresses.append(contentsOf: contact.postalAddresses)
            allUrls.append(contentsOf: contact.urlAddresses)
            allSocialProfiles.append(contentsOf: contact.socialProfiles)
        }
        
        mutableContact.postalAddresses = allAddresses
        mutableContact.urlAddresses = allUrls
        mutableContact.socialProfiles = allSocialProfiles
        
        return mutableContact
    }
    
    // MARK: - Helper Functions
    
    static func selectPrimaryContact(from contacts: [CNContact]) -> CNContact {
        // Select the contact with the most fields
        return contacts.max { countFields($0) < countFields($1) } ?? contacts[0]
    }
    
    static func calculateGroupConfidence(_ contacts: [CNContact]) -> Double {
        guard contacts.count > 1 else { return 0.0 }
        
        var totalConfidence = 0.0
        var pairCount = 0
        
        for i in 0..<contacts.count {
            for j in (i + 1)..<contacts.count {
                if let match = detectDuplicate(contacts[i], contacts[j]) {
                    totalConfidence += match.confidence
                    pairCount += 1
                }
            }
        }
        
        return pairCount > 0 ? totalConfidence / Double(pairCount) : 0.0
    }
    
    static func countFields(_ contact: CNContact) -> Int {
        var count = 0
        
        if contact.isKeyAvailable(CNContactGivenNameKey) && !contact.givenName.isEmpty { count += 1 }
        if contact.isKeyAvailable(CNContactFamilyNameKey) && !contact.familyName.isEmpty { count += 1 }
        if contact.isKeyAvailable(CNContactMiddleNameKey) && !contact.middleName.isEmpty { count += 1 }
        if contact.isKeyAvailable(CNContactNamePrefixKey) && !contact.namePrefix.isEmpty { count += 1 }
        if contact.isKeyAvailable(CNContactNameSuffixKey) && !contact.nameSuffix.isEmpty { count += 1 }
        if contact.isKeyAvailable(CNContactNicknameKey) && !contact.nickname.isEmpty { count += 1 }
        if contact.isKeyAvailable(CNContactOrganizationNameKey) && !contact.organizationName.isEmpty { count += 1 }
        if contact.isKeyAvailable(CNContactDepartmentNameKey) && !contact.departmentName.isEmpty { count += 1 }
        if contact.isKeyAvailable(CNContactJobTitleKey) && !contact.jobTitle.isEmpty { count += 1 }
        if contact.isKeyAvailable(CNContactNoteKey) && !contact.note.isEmpty { count += 1 }
        
        if contact.isKeyAvailable(CNContactEmailAddressesKey) {
            count += contact.emailAddresses.count
        }
        if contact.isKeyAvailable(CNContactPhoneNumbersKey) {
            count += contact.phoneNumbers.count
        }
        if contact.isKeyAvailable(CNContactPostalAddressesKey) {
            count += contact.postalAddresses.count
        }
        if contact.isKeyAvailable(CNContactUrlAddressesKey) {
            count += contact.urlAddresses.count
        }
        if contact.isKeyAvailable(CNContactSocialProfilesKey) {
            count += contact.socialProfiles.count
        }
        
        if contact.isKeyAvailable(CNContactBirthdayKey) && contact.birthday != nil { count += 1 }
        if contact.isKeyAvailable(CNContactImageDataAvailableKey) && contact.imageDataAvailable { count += 1 }
        
        return count
    }
    
    static func getFullName(_ contact: CNContact) -> String {
        var components: [String] = []
        
        if contact.isKeyAvailable(CNContactNamePrefixKey) && !contact.namePrefix.isEmpty {
            components.append(contact.namePrefix)
        }
        if contact.isKeyAvailable(CNContactGivenNameKey) && !contact.givenName.isEmpty {
            components.append(contact.givenName)
        }
        if contact.isKeyAvailable(CNContactMiddleNameKey) && !contact.middleName.isEmpty {
            components.append(contact.middleName)
        }
        if contact.isKeyAvailable(CNContactFamilyNameKey) && !contact.familyName.isEmpty {
            components.append(contact.familyName)
        }
        if contact.isKeyAvailable(CNContactNameSuffixKey) && !contact.nameSuffix.isEmpty {
            components.append(contact.nameSuffix)
        }
        
        return components.joined(separator: " ")
    }
    
    static func normalizePhoneNumber(_ phone: String) -> String {
        // Remove all non-numeric characters
        let digits = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Handle US numbers with country code
        if digits.count == 11 && digits.hasPrefix("1") {
            return String(digits.dropFirst())
        }
        
        return digits
    }
    
    static func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let str1Array = Array(str1)
        let str2Array = Array(str2)
        let str1Count = str1Array.count
        let str2Count = str2Array.count
        
        if str1Count == 0 { return str2Count }
        if str2Count == 0 { return str1Count }
        
        var matrix = Array(repeating: Array(repeating: 0, count: str2Count + 1), count: str1Count + 1)
        
        for i in 0...str1Count {
            matrix[i][0] = i
        }
        
        for j in 0...str2Count {
            matrix[0][j] = j
        }
        
        for i in 1...str1Count {
            for j in 1...str2Count {
                let cost = str1Array[i - 1] == str2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }
        
        return matrix[str1Count][str2Count]
    }
    
    static func soundsLike(_ str1: String, _ str2: String) -> Bool {
        // Simple soundex-like comparison
        let soundex1 = soundex(str1)
        let soundex2 = soundex(str2)
        return soundex1 == soundex2
    }
    
    static func soundex(_ str: String) -> String {
        let str = str.uppercased()
        guard let first = str.first else { return "0000" }
        
        var soundex = String(first)
        let soundexMap: [Character: Character] = [
            "B": "1", "F": "1", "P": "1", "V": "1",
            "C": "2", "G": "2", "J": "2", "K": "2", "Q": "2", "S": "2", "X": "2", "Z": "2",
            "D": "3", "T": "3",
            "L": "4",
            "M": "5", "N": "5",
            "R": "6"
        ]
        
        for char in str.dropFirst() {
            if let mapped = soundexMap[char] {
                if soundex.last != mapped {
                    soundex.append(mapped)
                }
            }
        }
        
        soundex = soundex.padding(toLength: 4, withPad: "0", startingAt: 0)
        return String(soundex.prefix(4))
    }
}