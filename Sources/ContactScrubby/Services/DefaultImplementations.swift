import Foundation
import Contacts

// MARK: - Default Contact Analyzer

public struct DefaultContactAnalyzer: ContactAnalyzing {
    private let configuration: AnalysisConfiguration
    
    public init(configuration: AnalysisConfiguration) {
        self.configuration = configuration
    }
    
    public func analyze(_ contact: Contact) async -> Result<ContactAnalysis, ContactError> {
        let startTime = Date()
        
        var score = 0
        var reasons: [String] = []
        var isIncomplete = false
        var isSuspicious = false
        
        // Analyze name
        if contact.name.isEmpty || contact.name == "Unknown" {
            score += configuration.scoringWeights.noName
            reasons.append("No name")
            isIncomplete = true
        } else if contact.name.count <= 2 {
            score += configuration.scoringWeights.shortName
            reasons.append("Very short name")
            isSuspicious = true
        } else if isGenericName(contact.name) {
            score += configuration.scoringWeights.genericName
            reasons.append("Generic or suspicious name")
            isSuspicious = true
        }
        
        // Analyze emails
        let facebookEmails = contact.emails.filter { $0.value.contains("@facebook.com") || $0.value.contains("@facebookmail.com") }
        let otherEmails = contact.emails.filter { !$0.value.contains("@facebook.com") && !$0.value.contains("@facebookmail.com") }
        
        if contact.emails.isEmpty {
            // No email is suspicious if contact is supposed to have contact info
            if !contact.phones.isEmpty {
                score += 1
                reasons.append("No email address")
                isIncomplete = true
            }
        } else if !facebookEmails.isEmpty && otherEmails.isEmpty {
            score += configuration.scoringWeights.facebookOnly
            reasons.append("Facebook-only email")
            isSuspicious = true
        }
        
        // Analyze missing basic info
        var missingFields = 0
        if contact.emails.isEmpty { missingFields += 1 }
        if contact.phones.isEmpty { missingFields += 1 }
        if contact.organizationName?.isEmpty ?? true { missingFields += 1 }
        
        if missingFields >= 2 {
            score += configuration.scoringWeights.missingInfo
            reasons.append("Missing basic contact information")
            isIncomplete = true
        }
        
        // Analyze phone numbers
        for phone in contact.phones {
            if isSuspiciousPhone(phone.value) {
                score += configuration.scoringWeights.suspiciousPhone
                reasons.append("Suspicious phone number pattern")
                isSuspicious = true
                break
            }
        }
        
        // Check for numeric emails (often fake)
        for email in contact.emails {
            if isNumericEmail(email.value) {
                score += 2
                reasons.append("Numeric email address")
                isSuspicious = true
                break
            }
        }
        
        // Check for no-reply emails
        for email in contact.emails {
            if isNoReplyEmail(email.value) {
                score += 1
                reasons.append("No-reply email address")
                isSuspicious = true
                break
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let confidence = calculateConfidence(score: score, contact: contact)
        
        let analysis = ContactAnalysis(
            id: contact.id,
            contact: contact,
            dubiousScore: score,
            reasons: reasons,
            isIncomplete: isIncomplete,
            isSuspicious: isSuspicious,
            confidence: confidence,
            metadata: [
                "analysisTime": String(format: "%.3f", duration),
                "version": "3.0"
            ]
        )
        
        return .success(analysis)
    }
    
    public func analyzeContacts(_ contacts: [Contact]) async -> Result<[ContactAnalysis], ContactError> {
        var analyses: [ContactAnalysis] = []
        
        for contact in contacts {
            let result = await analyze(contact)
            switch result {
            case .success(let analysis):
                analyses.append(analysis)
            case .failure(let error):
                return .failure(error)
            }
        }
        
        return .success(analyses)
    }
    
    public func getDubiousContacts(minimumScore: Int, from contacts: [Contact]) async -> Result<[ContactAnalysis], ContactError> {
        let analysisResult = await analyzeContacts(contacts)
        
        switch analysisResult {
        case .success(let analyses):
            let dubiousContacts = analyses.filter { $0.isDubious(minimumScore: minimumScore) }
            return .success(dubiousContacts)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    // MARK: - Helper Methods
    
    private func isGenericName(_ name: String) -> Bool {
        let lowercaseName = name.lowercased()
        let genericNames = [
            "user", "test", "demo", "sample", "example", "admin", "guest",
            "unknown", "contact", "person", "name", "customer", "client"
        ]
        return genericNames.contains { lowercaseName.contains($0) }
    }
    
    private func isSuspiciousPhone(_ phone: String) -> Bool {
        let digits = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Too short or too long
        if digits.count < 7 || digits.count > 15 {
            return true
        }
        
        // All same digit
        if Set(digits).count == 1 {
            return true
        }
        
        // Sequential numbers
        if isSequentialNumbers(digits) {
            return true
        }
        
        return false
    }
    
    private func isSequentialNumbers(_ digits: String) -> Bool {
        guard digits.count >= 4 else { return false }
        
        let digitArray = Array(digits.compactMap { Int(String($0)) })
        for i in 0..<(digitArray.count - 3) {
            let slice = Array(digitArray[i..<(i+4)])
            if slice == [slice[0], slice[0]+1, slice[0]+2, slice[0]+3] ||
               slice == [slice[0], slice[0]-1, slice[0]-2, slice[0]-3] {
                return true
            }
        }
        
        return false
    }
    
    private func isNumericEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@")
        guard let localPart = parts.first else { return false }
        
        // Check if local part is mostly numbers
        let digits = localPart.filter { $0.isNumber }
        return Double(digits.count) / Double(localPart.count) > 0.8
    }
    
    private func isNoReplyEmail(_ email: String) -> Bool {
        let lowercaseEmail = email.lowercased()
        return lowercaseEmail.contains("noreply") || 
               lowercaseEmail.contains("no-reply") ||
               lowercaseEmail.contains("donotreply")
    }
    
    private func calculateConfidence(score: Int, contact: Contact) -> Double {
        // Higher confidence for contacts with more data
        var dataPoints = 0
        if !contact.name.isEmpty && contact.name != "Unknown" { dataPoints += 1 }
        if !contact.emails.isEmpty { dataPoints += 1 }
        if !contact.phones.isEmpty { dataPoints += 1 }
        if contact.organizationName?.isEmpty == false { dataPoints += 1 }
        if contact.addresses.count > 0 { dataPoints += 1 }
        
        let baseConfidence = min(Double(dataPoints) / 5.0, 1.0)
        
        // Adjust based on score
        let scoreAdjustment = score > 5 ? 0.1 : 0.0
        
        return max(0.1, min(1.0, baseConfidence - scoreAdjustment))
    }
}

// MARK: - Default Contact Filter

public struct DefaultContactFilter: ContactFiltering {
    
    public init() {}
    
    public func filter(_ contacts: [Contact], using filter: ContactFilter) async -> Result<[Contact], ContactError> {
        let filteredContacts: [Contact]
        
        switch filter.mode {
        case .all:
            filteredContacts = contacts
            
        case .withEmail:
            filteredContacts = contacts.filter { !$0.emails.isEmpty }
            
        case .withoutEmail:
            filteredContacts = contacts.filter { $0.emails.isEmpty }
            
        case .facebookOnly:
            filteredContacts = contacts.filter { contact in
                let facebookEmails = contact.emails.filter { email in
                    email.value.contains("@facebook.com") || email.value.contains("@facebookmail.com")
                }
                return !facebookEmails.isEmpty
            }
            
        case .facebookExclusive:
            filteredContacts = contacts.filter { contact in
                let facebookEmails = contact.emails.filter { email in
                    email.value.contains("@facebook.com") || email.value.contains("@facebookmail.com")
                }
                let otherEmails = contact.emails.filter { email in
                    !email.value.contains("@facebook.com") && !email.value.contains("@facebookmail.com")
                }
                return !facebookEmails.isEmpty && otherEmails.isEmpty
            }
            
        case .noContact:
            filteredContacts = contacts.filter { contact in
                contact.emails.isEmpty && contact.phones.isEmpty
            }
            
        case .dubious:
            // For dubious filtering, we need to analyze contacts first
            let analyzer = DefaultContactAnalyzer(configuration: AnalysisConfiguration.default)
            let analysisResult = await analyzer.analyzeContacts(contacts)
            
            switch analysisResult {
            case .success(let analyses):
                let dubiousAnalyses = analyses.filter { $0.isDubious(minimumScore: filter.dubiousScore) }
                filteredContacts = dubiousAnalyses.map { $0.contact }
            case .failure(let error):
                return .failure(error)
            }
        }
        
        return .success(filteredContacts)
    }
    
    public func validateFilter(_ filter: ContactFilter) -> Result<Void, ContactError> {
        guard filter.dubiousScore > 0 && filter.dubiousScore <= 20 else {
            return .failure(.configuration(.invalidDubiousScore(filter.dubiousScore)))
        }
        return .success(())
    }
}

// MARK: - Default Contact Exporter

public struct DefaultContactExporter: ContactExporting {
    
    public var supportedFormats: [ExportFormat] {
        [.json, .xml, .vcf]
    }
    
    public func export(_ contacts: [Contact], to destination: ExportDestination, configuration: ExportConfiguration) async -> Result<ExportResult, ContactError> {
        let startTime = Date()
        
        // Validate configuration
        let validationResult = validateConfiguration(configuration)
        guard case .success = validationResult else {
            if case .failure(let error) = validationResult {
                return .failure(error)
            }
            return .failure(.export(.serializationFailed("Configuration validation failed")))
        }
        
        // Get destination path
        let outputPath: String
        switch destination {
        case .file(let path):
            outputPath = path
        case .url(let url):
            outputPath = url.path
        case .contacts:
            return .failure(.export(.invalidDestination("Cannot export to contacts database")))
        }
        
        let url = URL(fileURLWithPath: outputPath)
        
        do {
            switch configuration.format {
            case .json:
                try await exportAsJSON(contacts, to: url, configuration: configuration)
            case .xml:
                try await exportAsXML(contacts, to: url, configuration: configuration)
            case .vcf:
                try await exportAsVCF(contacts, to: url, configuration: configuration)
            }
            
            let duration = Date().timeIntervalSince(startTime)
            let result = ExportResult(
                itemsExported: contacts.count,
                warnings: [],
                duration: duration,
                outputPath: outputPath
            )
            
            return .success(result)
            
        } catch {
            return .failure(.export(.fileWriteFailed(path: outputPath, underlying: error.localizedDescription)))
        }
    }
    
    public func validateConfiguration(_ configuration: ExportConfiguration) -> Result<Void, ContactError> {
        guard supportedFormats.contains(configuration.format) else {
            return .failure(.export(.unsupportedFormat(configuration.format)))
        }
        return .success(())
    }
    
    // MARK: - Export Format Implementations
    
    private func exportAsJSON(_ contacts: [Contact], to url: URL, configuration: ExportConfiguration) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(contacts)
        try data.write(to: url)
    }
    
    private func exportAsXML(_ contacts: [Contact], to url: URL, configuration: ExportConfiguration) async throws {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<contacts>\n"
        
        for contact in contacts {
            xml += "  <contact id=\"\(contact.id.value)\">\n"
            xml += "    <name>\(escapeXML(contact.name))</name>\n"
            
            if !contact.emails.isEmpty {
                xml += "    <emails>\n"
                for email in contact.emails {
                    let label = email.label?.rawValue ?? "other"
                    xml += "      <email label=\"\(label)\">\(escapeXML(email.value))</email>\n"
                }
                xml += "    </emails>\n"
            }
            
            if !contact.phones.isEmpty {
                xml += "    <phones>\n"
                for phone in contact.phones {
                    let label = phone.label?.rawValue ?? "other"
                    xml += "      <phone label=\"\(label)\">\(escapeXML(phone.value))</phone>\n"
                }
                xml += "    </phones>\n"
            }
            
            if let organization = contact.organizationName {
                xml += "    <organization>\(escapeXML(organization))</organization>\n"
            }
            
            if let jobTitle = contact.jobTitle {
                xml += "    <jobTitle>\(escapeXML(jobTitle))</jobTitle>\n"
            }
            
            xml += "  </contact>\n"
        }
        
        xml += "</contacts>\n"
        
        guard let data = xml.data(using: .utf8) else {
            throw ContactError.export(.serializationFailed("Failed to encode XML as UTF-8"))
        }
        
        try data.write(to: url)
    }
    
    private func exportAsVCF(_ contacts: [Contact], to url: URL, configuration: ExportConfiguration) async throws {
        var vcf = ""
        
        for contact in contacts {
            vcf += "BEGIN:VCARD\n"
            vcf += "VERSION:3.0\n"
            
            // Name
            if let given = contact.nameComponents.given,
               let family = contact.nameComponents.family {
                vcf += "N:\(escapeVCF(family));\(escapeVCF(given));;;\n"
                vcf += "FN:\(escapeVCF("\(given) \(family)"))\n"
            } else {
                vcf += "FN:\(escapeVCF(contact.name))\n"
            }
            
            // Emails
            for email in contact.emails {
                let type = vcfLabelType(email.label)
                vcf += "EMAIL;TYPE=\(type):\(escapeVCF(email.value))\n"
            }
            
            // Phones
            for phone in contact.phones {
                let type = vcfLabelType(phone.label)
                vcf += "TEL;TYPE=\(type):\(escapeVCF(phone.value))\n"
            }
            
            // Organization
            if let org = contact.organizationName {
                vcf += "ORG:\(escapeVCF(org))\n"
            }
            
            // Job title
            if let title = contact.jobTitle {
                vcf += "TITLE:\(escapeVCF(title))\n"
            }
            
            // Note
            if let note = contact.note {
                vcf += "NOTE:\(escapeVCF(note))\n"
            }
            
            vcf += "END:VCARD\n"
        }
        
        guard let data = vcf.data(using: .utf8) else {
            throw ContactError.export(.serializationFailed("Failed to encode VCF as UTF-8"))
        }
        
        try data.write(to: url)
    }
    
    // MARK: - Helper Methods
    
    private func escapeXML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    private func escapeVCF(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
    
    private func vcfLabelType(_ label: ContactLabel?) -> String {
        switch label {
        case .home: return "HOME"
        case .work: return "WORK"
        case .mobile: return "CELL"
        case .main: return "MAIN"
        case .other, .none: return "OTHER"
        }
    }
}

// MARK: - Default Contact Importer

public struct DefaultContactImporter: ContactImporting {
    
    public var supportedFormats: [ExportFormat] {
        [.json, .xml, .vcf]
    }
    
    public func importContacts(from source: ImportSource) async -> Result<ImportResult, ContactError> {
        let startTime = Date()
        
        let validationResult = await validateSource(source)
        guard case .success = validationResult else {
            if case .failure(let error) = validationResult {
                return .failure(error)
            }
            return .failure(.importing(.invalidData("Source validation failed")))
        }
        
        do {
            let data: Data
            let format: ExportFormat
            
            switch source {
            case .file(let path, let fileFormat):
                data = try Data(contentsOf: URL(fileURLWithPath: path))
                format = fileFormat
            case .url(let url, let urlFormat):
                data = try Data(contentsOf: url)
                format = urlFormat
            case .contacts:
                return .failure(.importing(.invalidData("Cannot import from contacts database")))
            }
            
            let contacts: [Contact]
            
            switch format {
            case .json:
                contacts = try await importFromJSON(data)
            case .xml:
                contacts = try await importFromXML(data)
            case .vcf:
                contacts = try await importFromVCF(data)
            }
            
            let duration = Date().timeIntervalSince(startTime)
            let result = ImportResult(
                contacts: contacts,
                itemsImported: contacts.count,
                itemsFailed: 0,
                errors: [],
                duration: duration
            )
            
            return .success(result)
            
        } catch {
            return .failure(.importing(.parsingFailed(error.localizedDescription)))
        }
    }
    
    public func validateSource(_ source: ImportSource) async -> Result<Void, ContactError> {
        switch source {
        case .file(let path, let format):
            guard supportedFormats.contains(format) else {
                return .failure(.importing(.unsupportedFormat(format)))
            }
            guard FileManager.default.fileExists(atPath: path) else {
                return .failure(.importing(.fileNotFound(path)))
            }
        case .url(_, let format):
            guard supportedFormats.contains(format) else {
                return .failure(.importing(.unsupportedFormat(format)))
            }
        case .contacts:
            return .failure(.importing(.invalidData("Cannot import from contacts database")))
        }
        
        return .success(())
    }
    
    // MARK: - Import Format Implementations
    
    private func importFromJSON(_ data: Data) async throws -> [Contact] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // Try to decode as array first
        if let contacts = try? decoder.decode([Contact].self, from: data) {
            return contacts
        }
        
        // Try to decode as single contact
        if let contact = try? decoder.decode(Contact.self, from: data) {
            return [contact]
        }
        
        throw ContactError.importing(.parsingFailed("Invalid JSON format"))
    }
    
    private func importFromXML(_ data: Data) async throws -> [Contact] {
        // For now, return empty array as XML parsing is complex
        // In a real implementation, we would use XMLParser or similar
        return []
    }
    
    private func importFromVCF(_ data: Data) async throws -> [Contact] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw ContactError.importing(.parsingFailed("Invalid UTF-8 encoding"))
        }
        
        return parseVCFContent(content)
    }
    
    private func parseVCFContent(_ content: String) -> [Contact] {
        var contacts: [Contact] = []
        var currentContact: Contact?
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine == "BEGIN:VCARD" {
                currentContact = Contact(name: "")
            } else if trimmedLine == "END:VCARD" {
                if let contact = currentContact {
                    contacts.append(contact)
                }
                currentContact = nil
            } else if currentContact != nil {
                parseVCFLine(trimmedLine, into: &currentContact!)
            }
        }
        
        return contacts
    }
    
    private func parseVCFLine(_ line: String, into contact: inout Contact) {
        let parts = line.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return }
        
        let field = String(parts[0]).uppercased()
        let value = String(parts[1])
        
        if field == "FN" {
            contact.name = unescapeVCF(value)
        } else if field.starts(with: "EMAIL") {
            let email = LabeledValue(label: .other, value: unescapeVCF(value))
            contact.emails.append(email)
        } else if field.starts(with: "TEL") {
            let phone = LabeledValue(label: .other, value: unescapeVCF(value))
            contact.phones.append(phone)
        } else if field == "ORG" {
            contact.organizationName = unescapeVCF(value)
        } else if field == "TITLE" {
            contact.jobTitle = unescapeVCF(value)
        } else if field == "NOTE" {
            contact.note = unescapeVCF(value)
        }
    }
    
    private func unescapeVCF(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}