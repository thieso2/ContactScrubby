# Architecture Guide

Understanding ContactScrubby's modern protocol-oriented architecture.

## Overview

ContactScrubby v3.0 features a complete architectural redesign based on modern Swift principles including protocol-oriented programming, dependency injection, and structured concurrency.

## Three-Layer Architecture

### Core Layer (`Sources/ContactScrubby/Core/`)

The foundation layer containing:

- **Types and Enums**: Type-safe identifiers, export formats, filter modes
- **Protocols**: Service contracts defining behavior
- **Error Handling**: Comprehensive error types with recovery suggestions
- **Property Wrappers**: Data validation and sanitization

#### Key Files
- `Foundation.swift`: Core types, enums, and property wrappers
- `Protocols.swift`: Service protocols and data models
- `Errors.swift`: Error hierarchy with localized descriptions

### Services Layer (`Sources/ContactScrubby/Services/`)

Business logic implementations:

- **Contact Management**: Thread-safe contact operations using `@MainActor`
- **Analysis Engine**: Sophisticated contact scoring algorithms
- **Import/Export**: Multi-format data serialization
- **Dependency Injection**: Service container with factory methods

#### Key Files
- `ModernContactsManager.swift`: Actor-based contact operations
- `DefaultImplementations.swift`: Protocol implementations
- `DependencyContainer.swift`: Service factory and coordination

### CLI Layer (`Sources/ContactScrubby/CLI/`)

User interface with full backward compatibility:

- **Modern Commands**: Structured subcommands with ArgumentParser
- **Legacy Support**: Seamless compatibility with v2.x syntax
- **Help System**: Comprehensive documentation and examples

#### Key Files
- `ModernCLI.swift`: Complete CLI implementation

## Design Principles

### Protocol-Oriented Programming

Every major component is defined by a protocol:

```swift
@MainActor
public protocol ContactManaging: Sendable {
    func requestAccess() async throws -> Bool
    func loadContacts(filter: ContactFilter) async -> Result<[Contact], ContactError>
    func createContact(_ contact: Contact) async -> Result<ContactID, ContactError>
}
```

Benefits:
- **Testability**: Easy to mock services for unit testing
- **Flexibility**: Swap implementations without changing clients
- **Composition**: Combine services through dependency injection

### Dependency Injection

The `DependencyContainer` manages service creation and relationships:

```swift
public final class DependencyContainer: ObservableObject {
    @MainActor
    public func makeContactManager() -> ContactManaging {
        ModernContactsManager(
            analyzer: contactAnalyzer,
            filter: contactFilter,
            configuration: configuration.contacts,
            logger: logger
        )
    }
}
```

Benefits:
- **Decoupling**: Services don't create their own dependencies
- **Configuration**: Single place to wire up the application
- **Testing**: Easy to inject test doubles

### Modern Concurrency

All async operations use Swift's structured concurrency:

```swift
@MainActor
public final class ModernContactsManager: ContactManaging {
    public func loadContacts(filter: ContactFilter) async -> Result<[Contact], ContactError> {
        // Thread-safe contact operations
    }
}
```

Benefits:
- **Safety**: `@MainActor` ensures thread-safe contact operations
- **Performance**: Structured concurrency prevents data races
- **Simplicity**: No manual thread management

### Comprehensive Error Handling

Structured error hierarchy with recovery suggestions:

```swift
public enum ContactError: LocalizedError, Equatable, Sendable {
    case analysis(AnalysisError)
    case export(ExportError)
    case importing(ImportError)
    case permission(PermissionError)
    case configuration(ConfigurationError)
    case system(SystemError)
}
```

Benefits:
- **User Experience**: Clear error messages with actionable suggestions
- **Debugging**: Detailed error context for troubleshooting
- **Localization**: Built-in support for multiple languages

## Data Flow

### Contact Loading Flow

1. **CLI Command**: User executes `contactscrub list --filter dubious`
2. **Argument Parsing**: ArgumentParser validates and converts arguments
3. **Service Creation**: DependencyContainer creates required services
4. **Permission Check**: ContactManager requests Contacts access
5. **Data Loading**: CNContactStore enumerates contacts
6. **Conversion**: CNContact objects converted to internal Contact model
7. **Filtering**: ContactFilter applies the dubious filter
8. **Analysis**: ContactAnalyzer scores contacts for dubious behavior
9. **Display**: CLI formats and displays results

### Export Operation Flow

1. **Configuration**: ExportConfiguration specifies format and options
2. **Validation**: Exporter validates configuration and destination
3. **Contact Loading**: ContactManager loads filtered contacts
4. **Serialization**: Format-specific serialization (JSON/XML/VCF)
5. **Image Processing**: Handle images according to strategy
6. **File Writing**: Write data to destination with error handling
7. **Reporting**: Return ExportResult with metrics and warnings

## Testing Strategy

### Unit Testing

Each protocol has dedicated test implementations:

```swift
class MockContactManager: ContactManaging {
    var mockContacts: [Contact] = []
    
    func loadContacts(filter: ContactFilter) async -> Result<[Contact], ContactError> {
        .success(mockContacts.filter { /* apply filter */ })
    }
}
```

### Integration Testing

CLI integration tests verify end-to-end functionality:

```swift
func testExportCommand() async throws {
    let result = await ContactScrubby.ExportCommand.run(/* args */)
    XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath))
}
```

### Performance Testing

Large dataset tests ensure scalability:

```swift
func testLargeContactListPerformance() async throws {
    let contacts = generateMockContacts(count: 10000)
    let result = await analyzer.analyzeContacts(contacts)
    // Verify performance characteristics
}
```

## Extension Points

The architecture is designed for extensibility:

### Adding New Export Formats

1. Extend `ExportFormat` enum
2. Implement format-specific serialization in `DefaultContactExporter`
3. Add CLI argument support

### Custom Analysis Algorithms

1. Implement `ContactAnalyzing` protocol
2. Register in `DependencyContainer`
3. Configure scoring weights and thresholds

### Additional Contact Sources

1. Implement `ContactManaging` protocol
2. Add source detection in CLI
3. Support new authentication methods

## Migration Path

The modular architecture enables gradual migration:

1. **Legacy Compatibility**: Existing scripts continue to work
2. **Feature Parity**: All v2.x functionality preserved
3. **Modern Syntax**: New features use modern command structure
4. **Gradual Adoption**: Teams can migrate incrementally

## Performance Considerations

### Memory Management

- **Lazy Loading**: Services created only when needed
- **Batch Processing**: Large contact lists processed in chunks
- **Resource Cleanup**: Automatic resource management with actors

### Concurrency

- **Main Actor**: Contact operations isolated to main thread
- **Structured Concurrency**: No manual thread management
- **Cancellation**: Operations can be cancelled gracefully

### Caching

- **Contact Cache**: In-memory cache for frequently accessed contacts
- **Metadata Cache**: Analysis results cached to avoid recomputation
- **Configuration Cache**: Settings cached for performance

## Best Practices

### Service Implementation

- Keep protocols focused and cohesive
- Use dependency injection for all external dependencies
- Implement comprehensive error handling
- Add logging for debugging and monitoring

### Testing

- Mock all external dependencies
- Test both success and failure paths
- Include performance tests for large datasets
- Verify error messages and recovery suggestions

### CLI Design

- Maintain backward compatibility
- Provide helpful error messages
- Include usage examples in help text
- Support both interactive and scripted usage