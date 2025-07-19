import Foundation

// MARK: - Contact Filter Builder

/// Result builder for creating complex contact filters with a clean DSL
@resultBuilder
struct ContactFilterBuilder {
    
    // MARK: - Building Blocks
    
    static func buildBlock(_ components: FilterComponent...) -> ContactFilter {
        let combinedFilter = CombinedFilterComponent(components: components)
        return combinedFilter.build()
    }
    
    static func buildOptional(_ component: FilterComponent?) -> FilterComponent {
        component ?? EmptyFilterComponent()
    }
    
    static func buildEither(first component: FilterComponent) -> FilterComponent {
        component
    }
    
    static func buildEither(second component: FilterComponent) -> FilterComponent {
        component
    }
    
    static func buildArray(_ components: [FilterComponent]) -> FilterComponent {
        CombinedFilterComponent(components: components)
    }
    
    static func buildLimitedAvailability(_ component: FilterComponent) -> FilterComponent {
        component
    }
}

// MARK: - Filter Components

/// Protocol for filter components that can be combined
protocol FilterComponent {
    func build() -> ContactFilter
}

/// Empty filter component for optional cases
struct EmptyFilterComponent: FilterComponent {
    func build() -> ContactFilter {
        ContactFilter(mode: .all)
    }
}

/// Combined filter component for multiple filters
struct CombinedFilterComponent: FilterComponent {
    let components: [FilterComponent]
    
    func build() -> ContactFilter {
        // For now, use the first non-empty component
        // In a real implementation, this could combine filters with AND/OR logic
        for component in components {
            let filter = component.build()
            if filter.mode != .all {
                return filter
            }
        }
        return ContactFilter(mode: .all)
    }
}

// MARK: - Specific Filter Components

/// Email-based filters
struct EmailFilter: FilterComponent {
    enum EmailFilterType {
        case hasEmail
        case noEmail
        case facebookOnly
        case facebookExclusive
    }
    
    let type: EmailFilterType
    
    func build() -> ContactFilter {
        switch type {
        case .hasEmail:
            return ContactFilter(mode: .withEmail)
        case .noEmail:
            return ContactFilter(mode: .withoutEmail)
        case .facebookOnly:
            return ContactFilter(mode: .facebookOnly)
        case .facebookExclusive:
            return ContactFilter(mode: .facebookExclusive)
        }
    }
}

/// Score-based filters
struct ScoreFilter: FilterComponent {
    let minimumScore: Int
    
    func build() -> ContactFilter {
        ContactFilter(mode: .dubious, dubiousScore: minimumScore)
    }
}

/// Contact information filters
struct ContactInfoFilter: FilterComponent {
    enum InfoFilterType {
        case noContactInfo
        case all
    }
    
    let type: InfoFilterType
    
    func build() -> ContactFilter {
        switch type {
        case .noContactInfo:
            return ContactFilter(mode: .noContact)
        case .all:
            return ContactFilter(mode: .all)
        }
    }
}

// MARK: - DSL Functions

/// Create email-based filters
func hasEmail() -> EmailFilter {
    EmailFilter(type: .hasEmail)
}

func noEmail() -> EmailFilter {
    EmailFilter(type: .noEmail)
}

func facebookOnly() -> EmailFilter {
    EmailFilter(type: .facebookOnly)
}

func facebookExclusive() -> EmailFilter {
    EmailFilter(type: .facebookExclusive)
}

/// Create score-based filters
func minimumDubiousScore(_ score: Int) -> ScoreFilter {
    ScoreFilter(minimumScore: score)
}

/// Create contact info filters
func noContactInfo() -> ContactInfoFilter {
    ContactInfoFilter(type: .noContactInfo)
}

func allContacts() -> ContactInfoFilter {
    ContactInfoFilter(type: .all)
}

// MARK: - Usage Examples

/*
// Example usage of the filter DSL:

@ContactFilterBuilder
func dubiousContactFilter() -> ContactFilter {
    minimumDubiousScore(3)
    hasEmail()
}

@ContactFilterBuilder
func facebookOnlyFilter() -> ContactFilter {
    facebookExclusive()
}

@ContactFilterBuilder
func conditionalFilter(includeEmail: Bool) -> ContactFilter {
    if includeEmail {
        hasEmail()
    } else {
        noEmail()
    }
}

@ContactFilterBuilder
func complexFilter() -> ContactFilter {
    if someCondition {
        facebookOnly()
    } else {
        minimumDubiousScore(5)
    }
    // This would combine multiple filters in a real implementation
}
*/

// MARK: - Export Configuration Builder

/// Result builder for export configurations
@resultBuilder
struct ExportConfigurationBuilder {
    
    static func buildBlock(_ components: ConfigurationComponent...) -> ExportConfiguration {
        let combined = CombinedConfigurationComponent(components: components)
        return combined.build()
    }
    
    static func buildOptional(_ component: ConfigurationComponent?) -> ConfigurationComponent {
        component ?? EmptyConfigurationComponent()
    }
    
    static func buildEither(first component: ConfigurationComponent) -> ConfigurationComponent {
        component
    }
    
    static func buildEither(second component: ConfigurationComponent) -> ConfigurationComponent {
        component
    }
}

// MARK: - Configuration Components

protocol ConfigurationComponent {
    func build() -> ExportConfiguration
}

struct EmptyConfigurationComponent: ConfigurationComponent {
    func build() -> ExportConfiguration {
        .default
    }
}

struct CombinedConfigurationComponent: ConfigurationComponent {
    let components: [ConfigurationComponent]
    
    func build() -> ExportConfiguration {
        var config = ExportConfiguration.default
        
        for component in components {
            let componentConfig = component.build()
            // Merge configurations (simplified)
            config = ExportConfiguration(
                format: componentConfig.format != .json ? componentConfig.format : config.format,
                imageStrategy: componentConfig.imageStrategy != .none ? componentConfig.imageStrategy : config.imageStrategy,
                includeMetadata: componentConfig.includeMetadata,
                customFields: config.customFields + componentConfig.customFields
            )
        }
        
        return config
    }
}

// MARK: - Specific Configuration Components

struct FormatComponent: ConfigurationComponent {
    let format: ExportFormat
    
    func build() -> ExportConfiguration {
        ExportConfiguration(
            format: format,
            imageStrategy: .none,
            includeMetadata: true,
            customFields: []
        )
    }
}

struct ImageComponent: ConfigurationComponent {
    let strategy: ImageExportStrategy
    
    func build() -> ExportConfiguration {
        ExportConfiguration(
            format: .json,
            imageStrategy: strategy,
            includeMetadata: true,
            customFields: []
        )
    }
}

struct MetadataComponent: ConfigurationComponent {
    let includeMetadata: Bool
    
    func build() -> ExportConfiguration {
        ExportConfiguration(
            format: .json,
            imageStrategy: .none,
            includeMetadata: includeMetadata,
            customFields: []
        )
    }
}

struct CustomFieldsComponent: ConfigurationComponent {
    let fields: [String]
    
    func build() -> ExportConfiguration {
        ExportConfiguration(
            format: .json,
            imageStrategy: .none,
            includeMetadata: true,
            customFields: fields
        )
    }
}

// MARK: - Configuration DSL Functions

func format(_ format: ExportFormat) -> FormatComponent {
    FormatComponent(format: format)
}

func images(_ strategy: ImageExportStrategy) -> ImageComponent {
    ImageComponent(strategy: strategy)
}

func includeMetadata(_ include: Bool = true) -> MetadataComponent {
    MetadataComponent(includeMetadata: include)
}

func customFields(_ fields: String...) -> CustomFieldsComponent {
    CustomFieldsComponent(fields: fields)
}

// MARK: - Analysis Configuration Builder

@resultBuilder
struct AnalysisConfigurationBuilder {
    
    static func buildBlock(_ components: AnalysisComponent...) -> AnalysisConfiguration {
        let combined = CombinedAnalysisComponent(components: components)
        return combined.build()
    }
    
    static func buildOptional(_ component: AnalysisComponent?) -> AnalysisComponent {
        component ?? EmptyAnalysisComponent()
    }
}

protocol AnalysisComponent {
    func build() -> AnalysisConfiguration
}

struct EmptyAnalysisComponent: AnalysisComponent {
    func build() -> AnalysisConfiguration {
        .default
    }
}

struct CombinedAnalysisComponent: AnalysisComponent {
    let components: [AnalysisComponent]
    
    func build() -> AnalysisConfiguration {
        var config = AnalysisConfiguration.default
        
        for component in components {
            let componentConfig = component.build()
            // Merge configurations
            config = AnalysisConfiguration(
                enableCaching: componentConfig.enableCaching,
                scoringWeights: componentConfig.scoringWeights,
                timeoutPerContact: componentConfig.timeoutPerContact
            )
        }
        
        return config
    }
}

struct CachingComponent: AnalysisComponent {
    let enabled: Bool
    
    func build() -> AnalysisConfiguration {
        AnalysisConfiguration(
            enableCaching: enabled,
            scoringWeights: .default,
            timeoutPerContact: 1.0
        )
    }
}

struct ScoringWeightsComponent: AnalysisComponent {
    let weights: ScoringWeights
    
    func build() -> AnalysisConfiguration {
        AnalysisConfiguration(
            enableCaching: true,
            scoringWeights: weights,
            timeoutPerContact: 1.0
        )
    }
}

struct TimeoutComponent: AnalysisComponent {
    let timeout: TimeInterval
    
    func build() -> AnalysisConfiguration {
        AnalysisConfiguration(
            enableCaching: true,
            scoringWeights: .default,
            timeoutPerContact: timeout
        )
    }
}

// MARK: - Analysis DSL Functions

func enableCaching(_ enabled: Bool = true) -> CachingComponent {
    CachingComponent(enabled: enabled)
}

func scoringWeights(_ weights: ScoringWeights) -> ScoringWeightsComponent {
    ScoringWeightsComponent(weights: weights)
}

func timeout(_ seconds: TimeInterval) -> TimeoutComponent {
    TimeoutComponent(timeout: seconds)
}

// MARK: - Usage Examples for Export Configuration

/*
@ExportConfigurationBuilder
func jsonExportConfig() -> ExportConfiguration {
    format(.json)
    images(.inline)
    includeMetadata(true)
}

@ExportConfigurationBuilder
func vcfExportConfig() -> ExportConfiguration {
    format(.vcf)
    images(.none)
    customFields("customField1", "customField2")
}

@AnalysisConfigurationBuilder
func performanceAnalysisConfig() -> AnalysisConfiguration {
    enableCaching(true)
    timeout(2.0)
    scoringWeights(ScoringWeights(
        noName: 3,
        shortName: 2,
        genericName: 4,
        missingInfo: 1,
        facebookOnly: 3,
        suspiciousPhone: 2
    ))
}
*/