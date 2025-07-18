# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Building and Testing
```bash
# Build the project
swift build

# Build for release
swift build -c release

# Run all tests
swift test

# Run specific test suite
swift test --filter ContactsManagerTests
swift test --filter CLIIntegrationTests
swift test --filter ModelsTests

# Run executable directly
swift run contactscrub --help
swift run contactscrub --filter dubious
```

### Testing Individual Components
```bash
# Test a specific test method
swift test --filter testAnalyzeContactWithShortName

# Test with verbose output
swift test --verbose

# Run performance tests
swift test --filter testLargeContactListPerformance
```

## Architecture Overview

ContactScrubby is a Swift-based macOS command-line tool built with a modular architecture that separates concerns across distinct utility modules.

### Core Architecture Pattern

The application follows a **command-handler pattern** with the main `ContactScrubby` struct serving as an entry point that delegates to specialized handlers:

1. **Main Entry Point**: `ContactScrubby.swift` - AsyncParsableCommand that orchestrates operations
2. **Command Handlers**: `CommandHandlers.swift` - Static methods that handle different operations (export, display, group, dump)
3. **Core Business Logic**: `ContactsManager.swift` - Manages contact access, analysis, and data conversion
4. **Specialized Utilities**: Separate modules for export, display, filtering, and messaging

### Key Components

**ContactsManager** - The core business logic component that:
- Handles CNContactStore access and permissions
- Implements the contact analysis algorithm with scoring heuristics
- Manages contact data conversion between CNContact and SerializableContact
- Provides filtered contact retrieval methods

**Contact Analysis System** - Intelligent scoring system that identifies dubious contacts:
- Analyzes contact completeness and authenticity
- Assigns scores based on multiple heuristics (missing info, suspicious patterns, etc.)
- Categorizes contacts as incomplete, suspicious, or both
- Configurable scoring thresholds

**Modular Utilities Architecture**:
- `ExportUtilities`: JSON/XML export, image handling, filename sanitization
- `DisplayUtilities`: Contact formatting, label processing, full detail printing
- `FilterUtilities`: Contact filtering logic based on FilterMode
- `MessageUtilities`: User-facing message generation

### Data Flow

1. **ContactScrubby.run()** → Permission check → Command routing
2. **CommandHandlers** → Business logic delegation → ContactsManager
3. **ContactsManager** → CNContactStore operations → Data analysis/conversion
4. **Utility Modules** → Specialized processing → Output generation

### Contact Analysis Algorithm

The `analyzeContact()` method implements a sophisticated scoring system:

```swift
// Core heuristics (examples):
// - No name: +2 points, incomplete
// - Generic names: +3 points, suspicious  
// - Short names: +2 points, suspicious
// - Facebook-only email: +3 points, suspicious
// - Missing 2+ basic fields: +1 point, incomplete
```

The algorithm maintains two flags (`isIncomplete`, `isSuspicious`) alongside the numeric score, allowing for nuanced categorization.

### Testing Strategy

The test suite follows a three-tier approach:
- **Integration Tests**: CLI argument parsing and end-to-end workflows
- **Unit Tests**: Business logic (contact analysis, utilities, data conversion)
- **Model Tests**: Data structure validation and enum behavior

Static method preservation in the main struct ensures backwards compatibility for existing tests while enabling the modular architecture.

### Static Method Pattern

The main `ContactScrubby` struct maintains static wrapper methods for key utilities, enabling:
- Test compatibility without refactoring
- Clean API for external consumers
- Gradual migration path for future changes

### Development Notes

- The application requires macOS 10.15+ and integrates with the Contacts framework
- All async operations use modern Swift concurrency (async/await)
- The dubious contact detection algorithm is the core differentiator - modifications should preserve existing scoring patterns
- Export functionality supports both embedded and external image storage
- Permission handling is critical - the app gracefully handles denied contact access