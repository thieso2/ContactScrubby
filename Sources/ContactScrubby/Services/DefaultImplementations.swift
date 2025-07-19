import Foundation

// MARK: - Default Contact Analyzer

struct DefaultContactAnalyzer: ContactAnalyzing {
    private let configuration: AnalysisConfiguration
    
    init(configuration: AnalysisConfiguration = .default) {
        self.configuration = configuration
    }
    
    func analyze(_ contact: Contact) async -> Result<ContactAnalysis, ContactError> {
        let analysis = await performAnalysis(contact)
        return .success(analysis)
    }
    
    func analyzeContacts(_ contacts: [Contact]) async -> Result<[ContactAnalysis], ContactError> {
        // Use structured concurrency for parallel processing
        let results = await withTaskGroup(of: ContactAnalysis.self, returning: [ContactAnalysis].self) { group in
            for contact in contacts {
                group.addTask {
                    await performAnalysis(contact)
                }
            }
            
            var analyses: [ContactAnalysis] = []
            for await analysis in group {
                analyses.append(analysis)
            }
            return analyses
        }
        
        return .success(results)
    }
    
    func getDubiousContacts(minimumScore: Int, from contacts: [Contact]) async -> Result<[ContactAnalysis], ContactError> {
        let analysisResult = await analyzeContacts(contacts)
        
        switch analysisResult {
        case .success(let analyses):
            let dubious = analyses.filter { $0.isDubious(minimumScore: minimumScore) }
            return .success(dubious)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    private func performAnalysis(_ contact: Contact) async -> ContactAnalysis {
        var score = 0
        var reasons: [String] = []
        var isIncomplete = false
        var isSuspicious = false
        
        let weights = configuration.scoringWeights
        
        // Analyze name
        if contact.name == "No Name" || contact.name.isEmpty {
            score += weights.noName
            reasons.append("No name provided")
            isIncomplete = true
        } else if contact.name.count <= 2 {
            score += weights.shortName
            reasons.append("Very short name")
            isSuspicious = true
        } else if isGenericName(contact.name) {
            score += weights.genericName
            reasons.append("Generic or suspicious name")
            isSuspicious = true
        }
        
        // Analyze contact information
        let hasEmail = !contact.emails.isEmpty
        let hasPhone = !contact.phones.isEmpty
        
        if !hasEmail && !hasPhone {
            score += weights.missingInfo + 1
            reasons.append("No contact information")
            isIncomplete = true
        }
        
        // Check for Facebook-only emails
        let facebookEmails = contact.emails.filter { $0.value.lowercased().hasSuffix("@facebook.com") }
        if hasEmail && facebookEmails.count == contact.emails.count && !hasPhone {
            score += weights.facebookOnly
            reasons.append("Facebook-only contact")
            isSuspicious = true
        }
        
        // Check for suspicious phone numbers
        for phone in contact.phones {
            if isSuspiciousPhone(phone.value) {
                score += weights.suspiciousPhone
                reasons.append("Suspicious phone number")
                isSuspicious = true
                break
            }
        }
        
        // Check for missing basic information
        let missingFields = getMissingBasicFields(contact)
        if missingFields.count >= 2 {
            score += weights.missingInfo
            reasons.append("Missing basic information")
            isIncomplete = true
        }
        
        let confidence = calculateConfidence(score: score, contact: contact)
        
        return ContactAnalysis(
            id: contact.id,
            contact: contact,
            dubiousScore: score,
            reasons: reasons,
            isIncomplete: isIncomplete,
            isSuspicious: isSuspicious,
            confidence: confidence,
            metadata: [
                "analyzed_at": ISO8601DateFormatter().string(from: Date()),
                "analyzer_version": "2.0"
            ]
        )
    }
    
    private func isGenericName(_ name: String) -> Bool {
        let genericNames = [
            "test", "user", "admin", "sample", "example", "demo",
            "john doe", "jane doe", "lorem ipsum", "placeholder"
        ]
        
        let lowercased = name.lowercased()
        return genericNames.contains { lowercased.contains($0) }
    }
    
    private func isSuspiciousPhone(_ phone: String) -> Bool {
        let digits = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Check for patterns like 1111111111 or 1234567890
        let suspiciousPatterns = [
            "1111111111", "2222222222", "3333333333", "4444444444", "5555555555",
            "6666666666", "7777777777", "8888888888", "9999999999", "0000000000",
            "1234567890", "0123456789"
        ]
        
        return suspiciousPatterns.contains(digits)
    }
    
    private func getMissingBasicFields(_ contact: Contact) -> [String] {
        var missing: [String] = []
        
        if contact.nameComponents.given == nil { missing.append("given_name") }
        if contact.nameComponents.family == nil { missing.append("family_name") }
        if contact.organizationName == nil { missing.append("organization") }
        if contact.jobTitle == nil { missing.append("job_title") }
        if contact.addresses.isEmpty { missing.append("address") }
        
        return missing
    }
    
    private func calculateConfidence(score: Int, contact: Contact) -> Double {
        // Higher scores = lower confidence in legitimacy
        let maxScore = 15.0 // Theoretical maximum score
        let normalizedScore = min(Double(score), maxScore) / maxScore
        
        // Invert so high confidence means legitimate contact
        return 1.0 - normalizedScore
    }
}

// MARK: - Default Contact Filter

struct DefaultContactFilter: ContactFiltering {
    
    func filter(_ contacts: [Contact], using filter: ContactFilter) async -> Result<[Contact], ContactError> {
        let filtered = await withTaskGroup(of: (Contact, Bool).self, returning: [Contact].self) { group in
            for contact in contacts {
                group.addTask {
                    let matches = await shouldInclude(contact, filter: filter)
                    return (contact, matches)
                }
            }
            
            var result: [Contact] = []
            for await (contact, matches) in group {
                if matches {
                    result.append(contact)
                }
            }
            return result
        }
        
        return .success(filtered)
    }
    
    func validateFilter(_ filter: ContactFilter) -> Result<Void, ContactError> {
        guard filter.dubiousScore >= 1 && filter.dubiousScore <= 10 else {
            return .failure(.configuration(.invalidDubiousScore(filter.dubiousScore)))
        }
        
        return .success(())
    }
    
    private func shouldInclude(_ contact: Contact, filter: ContactFilter) async -> Bool {
        let emails = contact.emails.map { $0.value }
        let phones = contact.phones.map { $0.value }
        
        switch filter.mode {
        case .all:
            return true
            
        case .withEmail:
            return !emails.isEmpty
            
        case .withoutEmail:
            return emails.isEmpty
            
        case .facebookOnly:
            return emails.contains { $0.lowercased().hasSuffix("@facebook.com") }
            
        case .facebookExclusive:
            let facebookEmails = emails.filter { $0.lowercased().hasSuffix("@facebook.com") }
            return !facebookEmails.isEmpty && facebookEmails.count == emails.count && phones.isEmpty
            
        case .dubious:
            let analyzer = DefaultContactAnalyzer()
            let analysisResult = await analyzer.analyze(contact)
            switch analysisResult {
            case .success(let analysis):
                return analysis.isDubious(minimumScore: filter.dubiousScore)
            case .failure:
                return false
            }
            
        case .noContact:
            return emails.isEmpty && phones.isEmpty
        }
    }
}

// MARK: - Default Contact Exporter

struct DefaultContactExporter: ContactExporting {
    
    var supportedFormats: [ExportFormat] {
        [.json, .xml, .vcf]
    }
    
    func export(_ contacts: [Contact], to destination: ExportDestination, configuration: ExportConfiguration) async -> Result<ExportResult, ContactError> {
        let startTime = Date()
        
        // Validate configuration first
        let validationResult = validateConfiguration(configuration)
        guard case .success = validationResult else {
            return validationResult.map { _ in ExportResult(itemsExported: 0, warnings: [], duration: 0, outputPath: nil) }
        }
        
        do {
            let outputPath: String?
            
            switch destination {
            case .file(let path):
                outputPath = path
                let url = URL(fileURLWithPath: path)
                try await exportToFile(contacts, url: url, configuration: configuration)
                
            case .url(let url):
                outputPath = url.path
                try await exportToFile(contacts, url: url, configuration: configuration)
                
            case .contacts:
                outputPath = nil
                // Would implement contacts database export here
                throw ContactError.export(.unsupportedFormat(configuration.format))
            }
            
            let duration = Date().timeIntervalSince(startTime)
            let result = ExportResult(
                itemsExported: contacts.count,
                warnings: [],
                duration: duration,
                outputPath: outputPath
            )
            
            return .success(result)
            
        } catch let error as ContactError {
            return .failure(error)
        } catch {
            return .failure(.export(.serializationFailed(reason: error.localizedDescription)))
        }
    }
    
    func validateConfiguration(_ configuration: ExportConfiguration) -> Result<Void, ContactError> {
        guard supportedFormats.contains(configuration.format) else {
            return .failure(.export(.unsupportedFormat(configuration.format)))
        }
        
        return configuration.validate()
    }
    
    private func exportToFile(_ contacts: [Contact], url: URL, configuration: ExportConfiguration) async throws {
        switch configuration.format {
        case .json:
            try await exportAsJSON(contacts, to: url, configuration: configuration)
        case .xml:
            try await exportAsXML(contacts, to: url, configuration: configuration)
        case .vcf:
            try await exportAsVCF(contacts, to: url, configuration: configuration)
        }
    }
    
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
            xml += await generateXMLForContact(contact, configuration: configuration)
        }
        
        xml += "</contacts>\n"
        
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private func exportAsVCF(_ contacts: [Contact], to url: URL, configuration: ExportConfiguration) async throws {
        var vcf = ""
        
        for contact in contacts {
            vcf += await generateVCFForContact(contact, configuration: configuration)
        }
        
        try vcf.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private func generateXMLForContact(_ contact: Contact, configuration: ExportConfiguration) async -> String {
        var xml = "  <contact>\n"
        xml += "    <id>\(contact.id.value)</id>\n"
        xml += "    <name>\(escapeXML(contact.name))</name>\n"
        
        // Add other fields...
        // (Implementation would be similar to existing XML export but using new Contact model)
        
        xml += "  </contact>\n"
        return xml
    }
    
    private func generateVCFForContact(_ contact: Contact, configuration: ExportConfiguration) async -> String {
        var vcf = "BEGIN:VCARD\n"
        vcf += "VERSION:3.0\n"
        vcf += "FN:\(escapeVCF(contact.name))\n"
        
        // Add other fields...
        // (Implementation would be similar to existing VCF export but using new Contact model)
        
        vcf += "END:VCARD\n\n"
        return vcf
    }
    
    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    private func escapeVCF(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}

// MARK: - Default Contact Importer

struct DefaultContactImporter: ContactImporting {
    
    var supportedFormats: [ExportFormat] {
        [.json, .xml, .vcf]
    }
    
    func importContacts(from source: ImportSource) async -> Result<ImportResult, ContactError> {
        let startTime = Date()
        
        do {
            let contacts: [Contact]
            
            switch source {
            case .file(let path, let format):
                let url = URL(fileURLWithPath: path)
                contacts = try await importFromFile(url: url, format: format)
                
            case .url(let url, let format):
                contacts = try await importFromFile(url: url, format: format)
                
            case .contacts:
                // Would implement contacts database import here
                throw ContactError.import(.unsupportedFormat("contacts"))
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
            
        } catch let error as ContactError {
            return .failure(error)
        } catch {
            return .failure(.import(.parseError(line: nil, reason: error.localizedDescription)))
        }
    }
    
    func validateSource(_ source: ImportSource) async -> Result<Void, ContactError> {
        switch source {
        case .file(let path, let format):
            guard FileManager.default.fileExists(atPath: path) else {
                return .failure(.import(.fileNotFound(path)))
            }
            guard supportedFormats.contains(format) else {
                return .failure(.import(.unsupportedFormat(format.rawValue)))
            }
            
        case .url(let url, let format):
            guard supportedFormats.contains(format) else {
                return .failure(.import(.unsupportedFormat(format.rawValue)))
            }
            // Could add URL validation here
            
        case .contacts:
            return .failure(.import(.unsupportedFormat("contacts")))
        }
        
        return .success(())
    }
    
    private func importFromFile(url: URL, format: ExportFormat) async throws -> [Contact] {
        switch format {
        case .json:
            return try await importFromJSON(url: url)
        case .xml:
            return try await importFromXML(url: url)
        case .vcf:
            return try await importFromVCF(url: url)
        }
    }
    
    private func importFromJSON(url: URL) async throws -> [Contact] {
        let data = try Data(contentsOf: url)
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
        
        throw ContactError.import(.parseError(line: nil, reason: "Invalid JSON format"))
    }
    
    private func importFromXML(url: URL) async throws -> [Contact] {
        // Would implement XML parsing using XMLParser or similar
        // This is a placeholder implementation
        throw ContactError.import(.unsupportedFormat("xml"))
    }
    
    private func importFromVCF(url: URL) async throws -> [Contact] {
        // Would implement VCF parsing
        // This is a placeholder implementation
        throw ContactError.import(.unsupportedFormat("vcf"))
    }
}

// MARK: - Configuration Extensions

extension AnalysisConfiguration {
    static let `default` = AnalysisConfiguration(
        enableCaching: true,
        scoringWeights: .default,
        timeoutPerContact: 1.0
    )
}

extension ExportConfiguration {
    static let `default` = ExportConfiguration(
        format: .json,
        imageStrategy: .none,
        includeMetadata: true,
        customFields: []
    )
}