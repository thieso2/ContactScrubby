# ContactsCLI

A powerful command-line tool for managing, analyzing, and exporting macOS contacts with advanced filtering and dubious contact detection capabilities.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
  - [Basic Commands](#basic-commands)
  - [Filtering Options](#filtering-options)
  - [Export Formats](#export-formats)
  - [Contact Analysis](#contact-analysis)
  - [Group Management](#group-management)
- [Examples](#examples)
- [Architecture](#architecture)
- [Development](#development)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

## Overview

ContactsCLI is a Swift-based command-line application that provides comprehensive contact management capabilities for macOS. It offers advanced filtering, export functionality, and intelligent analysis to help identify incomplete or suspicious contacts in your address book.

The tool is particularly useful for:
- Cleaning up contact databases
- Identifying suspicious or incomplete contacts
- Exporting contacts in various formats
- Organizing contacts into groups
- Analyzing contact data quality

## Features

### 🔍 **Advanced Filtering**
- Filter by email presence/absence
- Facebook-specific contact filtering
- Dubious contact detection with configurable scoring
- All contacts view with detailed information

### 📊 **Contact Analysis**
- Intelligent dubious contact detection
- Configurable scoring system (1-10 scale)
- Identifies suspicious patterns:
  - Generic names (e.g., "Facebook User")
  - Very short names
  - Numeric email addresses
  - No-reply email addresses
  - Missing basic information
  - Suspicious phone numbers

### 📤 **Export Capabilities**
- JSON export with pretty formatting
- XML export with proper escaping
- Image handling (inline base64 or separate folder)
- Configurable export options

### 👥 **Group Management**
- Add filtered contacts to specified groups
- Bulk operations with detailed results
- Error handling and reporting

### 🖥️ **Display Options**
- Compact contact listing
- Full contact details dump
- Structured output with clear formatting

## Installation

### Prerequisites
- macOS 10.15 or later
- Swift 5.8 or later
- Xcode 14.0 or later (for development)

### Build from Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/ContactsCLI.git
cd ContactsCLI
```

2. Build the project:
```bash
swift build -c release
```

3. Copy the executable to your PATH:
```bash
cp .build/release/ContactsCLI /usr/local/bin/
```

### Using Swift Package Manager

Add to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/yourusername/ContactsCLI.git", from: "1.0.0")
]
```

## Usage

### Basic Commands

```bash
# Display all contacts with email addresses
ContactsCLI

# Show help
ContactsCLI --help

# Show version
ContactsCLI --version
```

### Filtering Options

The `--filter` (or `-f`) option supports these modes:

| Filter | Description |
|--------|-------------|
| `with-email` | Contacts with email addresses (default) |
| `no-email` | Contacts without email addresses |
| `facebook` | Contacts with @facebook.com email addresses |
| `facebook-exclusive` | Contacts with ONLY @facebook.com emails and no phone numbers |
| `dubious` | Contacts identified as suspicious or incomplete |
| `all` | All contacts |

```bash
# Show contacts without email addresses
ContactsCLI --filter no-email

# Show dubious contacts with minimum score of 5
ContactsCLI --filter dubious --dubious-score 5

# Show all Facebook contacts
ContactsCLI --filter facebook
```

### Export Formats

Export contacts to JSON or XML files:

```bash
# Export to JSON
ContactsCLI --backup contacts.json

# Export to XML with images as base64
ContactsCLI --backup contacts.xml --include-images inline

# Export with images in separate folder
ContactsCLI --backup contacts.json --include-images folder

# Export filtered contacts
ContactsCLI --filter dubious --backup suspicious.json
```

### Contact Analysis

The dubious contact detection system uses a scoring algorithm to identify problematic contacts:

```bash
# Show dubious contacts (default threshold: 3)
ContactsCLI --filter dubious

# Show highly dubious contacts (threshold: 5)
ContactsCLI --filter dubious --dubious-score 5

# Export all dubious contacts
ContactsCLI --filter dubious --backup dubious.json
```

#### Scoring Criteria

| Issue | Score | Category |
|-------|-------|----------|
| No name provided | +2 | Incomplete |
| Generic/suspicious name | +3 | Suspicious |
| Very short name | +2 | Suspicious |
| All caps/lowercase name | +1 | Suspicious |
| Facebook-only email, no phone | +3 | Suspicious |
| Numeric email username | +2 | Suspicious |
| No-reply email address | +2 | Suspicious |
| Missing 2+ basic fields | +1 | Incomplete |
| Only name + email | +2 | Incomplete |
| Suspicious phone pattern | +2 | Suspicious |

### Group Management

Add filtered contacts to groups:

```bash
# Add dubious contacts to "Suspicious" group
ContactsCLI --filter dubious --add-to-group "Suspicious"

# Add Facebook contacts to "Facebook" group
ContactsCLI --filter facebook --add-to-group "Facebook"
```

### Advanced Options

```bash
# Show all contact fields for debugging
ContactsCLI --dump

# Combine multiple options
ContactsCLI --filter dubious --dubious-score 2 --backup suspicious.json --include-images folder
```

## Examples

### Example 1: Clean Up Your Contacts

```bash
# 1. Identify dubious contacts
ContactsCLI --filter dubious

# 2. Export them for review
ContactsCLI --filter dubious --backup review.json

# 3. Add them to a group for manual review
ContactsCLI --filter dubious --add-to-group "Review"
```

### Example 2: Export Facebook Contacts

```bash
# 1. See how many Facebook contacts you have
ContactsCLI --filter facebook

# 2. Export them with images
ContactsCLI --filter facebook --backup facebook_contacts.json --include-images folder

# 3. Export only Facebook-exclusive contacts
ContactsCLI --filter facebook-exclusive --backup facebook_only.xml
```

### Example 3: Contact Database Analysis

```bash
# 1. Show all contacts
ContactsCLI --filter all

# 2. Show contacts without emails
ContactsCLI --filter no-email

# 3. Export comprehensive report
ContactsCLI --filter dubious --dubious-score 1 --backup full_analysis.json
```

## Architecture

ContactsCLI follows a modular architecture with clear separation of concerns:

```
Sources/ContactsCLI/
├── ContactsCLI.swift         # Main CLI entry point and ArgumentParser setup
├── CommandHandlers.swift     # Command operation handlers
├── ContactsManager.swift     # Core contact management and analysis
├── DisplayUtilities.swift    # Contact formatting and display
├── ExportUtilities.swift     # File export functionality
├── FilterUtilities.swift     # Contact filtering logic
├── MessageUtilities.swift    # User messaging and text generation
└── Models.swift             # Data models and enums
```

### Key Components

- **ContactsCLI**: Main entry point using Swift ArgumentParser
- **CommandHandlers**: Orchestrates different operations (export, display, group management)
- **ContactsManager**: Core business logic for contact analysis and management
- **ExportUtilities**: Handles JSON/XML export and image processing
- **DisplayUtilities**: Contact formatting and pretty printing
- **FilterUtilities**: Contact filtering algorithms
- **MessageUtilities**: User-facing messages and help text

## Development

### Project Setup

1. Clone the repository
2. Open in Xcode or use command line tools
3. Install dependencies (handled automatically by Swift Package Manager)

### Dependencies

- [Swift ArgumentParser](https://github.com/apple/swift-argument-parser) - Command-line argument parsing
- Foundation - Core Swift functionality
- Contacts - macOS Contacts framework integration

### Code Style

- Follow Swift conventions
- Use meaningful variable names
- Add documentation for public APIs
- Maintain test coverage above 90%

### Adding New Features

1. Create feature branch: `git checkout -b feature/your-feature`
2. Implement feature with tests
3. Run test suite: `swift test`
4. Update documentation if needed
5. Submit pull request

## Testing

The project includes comprehensive test coverage:

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter ContactsManagerTests

# Run tests with coverage
swift test --enable-code-coverage
```

### Test Structure

```
Tests/ContactsCLITests/
├── CLIIntegrationTests.swift      # Command-line integration tests
├── ContactsManagerTests.swift     # Core logic unit tests
└── ModelsTests.swift             # Data model tests
```

### Test Coverage

- **51 tests** covering all major functionality
- **100% pass rate** with comprehensive edge case testing
- Integration tests for CLI argument parsing
- Unit tests for contact analysis algorithms
- Performance tests for large contact lists

## Contributing

Contributions are welcome! Please follow these guidelines:

1. **Issues**: Use GitHub issues for bug reports and feature requests
2. **Pull Requests**: 
   - Follow the existing code style
   - Include tests for new functionality
   - Update documentation as needed
   - Ensure all tests pass

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add/update tests
5. Run the test suite
6. Submit a pull request

## Security and Privacy

ContactsCLI respects user privacy and follows macOS security guidelines:

- **Permission Requests**: Explicitly requests contact access
- **Local Processing**: All analysis happens locally on your machine
- **No Network**: No data is sent to external servers
- **Secure Export**: Exported files are saved with appropriate permissions

## Troubleshooting

### Common Issues

**Permission Denied**
```bash
# Grant contacts permission in System Preferences > Security & Privacy > Privacy > Contacts
```

**Build Errors**
```bash
# Clean build directory
swift package clean
swift build
```

**Test Failures**
```bash
# Run tests in verbose mode
swift test --verbose
```

### Getting Help

- Check the [Issues](https://github.com/yourusername/ContactsCLI/issues) page
- Review the [Documentation](https://github.com/yourusername/ContactsCLI/wiki)
- Contact the maintainers

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [Swift ArgumentParser](https://github.com/apple/swift-argument-parser)
- Inspired by the need for better contact management tools
- Thanks to the Swift community for excellent tooling

---

**ContactsCLI** - Making contact management simple and powerful.