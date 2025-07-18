# ContactScrubby

> [!NOTE]
> **AI-Generated Project**: This entire project was created using [Claude Code](https://claude.ai/code) through conversational programming. The code was written through natural language interactions without traditional coding - a process known as "vibe-coding" where the AI generated all source code, tests, documentation, and CI/CD configuration based on high-level requirements and iterative feedback.

[![AI Generated](https://img.shields.io/badge/AI%20Generated-Claude%20Code-blue?style=for-the-badge&logo=anthropic)](https://claude.ai/code)
[![Swift](https://img.shields.io/badge/Swift-5.8-orange?style=for-the-badge&logo=swift)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS-lightgrey?style=for-the-badge&logo=apple)](https://developer.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

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

ContactScrubby is a Swift-based command-line application that provides comprehensive contact management capabilities for macOS. It offers advanced filtering, export functionality, and intelligent analysis to help identify incomplete or suspicious contacts in your address book.

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
git clone https://github.com/yourusername/ContactScrubby.git
cd ContactScrubby
```

2. Build the project:
```bash
swift build -c release
```

3. Copy the executable to your PATH:
```bash
cp .build/release/contactscrub /usr/local/bin/
```

### Using Swift Package Manager

Add to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/yourusername/ContactScrubby.git", from: "1.0.0")
]
```

## Usage

### Basic Commands

```bash
# Display all contacts with email addresses
contactscrub

# Show help
contactscrub --help

# Show version
contactscrub --version
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
contactscrub --filter no-email

# Show dubious contacts with minimum score of 5
contactscrub --filter dubious --dubious-score 5

# Show all Facebook contacts
contactscrub --filter facebook
```

### Export Formats

Export contacts to JSON or XML files:

```bash
# Export to JSON
contactscrub --backup contacts.json

# Export to XML with images as base64
contactscrub --backup contacts.xml --include-images inline

# Export with images in separate folder
contactscrub --backup contacts.json --include-images folder

# Export filtered contacts
contactscrub --filter dubious --backup suspicious.json
```

### Contact Analysis

The dubious contact detection system uses a scoring algorithm to identify problematic contacts:

```bash
# Show dubious contacts (default threshold: 3)
contactscrub --filter dubious

# Show highly dubious contacts (threshold: 5)
contactscrub --filter dubious --dubious-score 5

# Export all dubious contacts
contactscrub --filter dubious --backup dubious.json
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
contactscrub --filter dubious --add-to-group "Suspicious"

# Add Facebook contacts to "Facebook" group
contactscrub --filter facebook --add-to-group "Facebook"
```

### Advanced Options

```bash
# Show all contact fields for debugging
contactscrub --dump

# Combine multiple options
contactscrub --filter dubious --dubious-score 2 --backup suspicious.json --include-images folder
```

## Examples

### Example 1: Clean Up Your Contacts

```bash
# 1. Identify dubious contacts
contactscrub --filter dubious

# 2. Export them for review
contactscrub --filter dubious --backup review.json

# 3. Add them to a group for manual review
contactscrub --filter dubious --add-to-group "Review"
```

### Example 2: Export Facebook Contacts

```bash
# 1. See how many Facebook contacts you have
contactscrub --filter facebook

# 2. Export them with images
contactscrub --filter facebook --backup facebook_contacts.json --include-images folder

# 3. Export only Facebook-exclusive contacts
contactscrub --filter facebook-exclusive --backup facebook_only.xml
```

### Example 3: Contact Database Analysis

```bash
# 1. Show all contacts
contactscrub --filter all

# 2. Show contacts without emails
contactscrub --filter no-email

# 3. Export comprehensive report
contactscrub --filter dubious --dubious-score 1 --backup full_analysis.json
```

## Architecture

contactscrub follows a modular architecture with clear separation of concerns:

```
Sources/ContactScrubby/
├── ContactScrubby.swift       # Main CLI entry point and ArgumentParser setup
├── CommandHandlers.swift     # Command operation handlers
├── ContactsManager.swift     # Core contact management and analysis
├── DisplayUtilities.swift    # Contact formatting and display
├── ExportUtilities.swift     # File export functionality
├── FilterUtilities.swift     # Contact filtering logic
├── MessageUtilities.swift    # User messaging and text generation
└── Models.swift             # Data models and enums
```

### Key Components

- **ContactScrubby**: Main entry point using Swift ArgumentParser
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
Tests/ContactScrubbyTests/
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

> [!IMPORTANT]
> **AI-Generated Codebase**: This project was entirely created through conversational programming with Claude Code. All source code, tests, documentation, and CI/CD configuration were generated through natural language interactions. Contributors should be aware that the codebase reflects AI-generated patterns and architectural decisions.

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

contactscrub respects user privacy and follows macOS security guidelines:

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

- Check the [Issues](https://github.com/yourusername/ContactScrubby/issues) page
- Review the [Documentation](https://github.com/yourusername/ContactScrubby/wiki)
- Contact the maintainers

## AI Generation Process

This project demonstrates the capabilities of modern AI-assisted development:

### Development Methodology
- **Conversational Programming**: All code was generated through natural language interactions with Claude Code
- **Vibe-Coding**: Development driven by high-level requirements and iterative feedback rather than traditional coding
- **Zero Manual Coding**: No traditional text editing or IDE usage - purely AI-generated implementation

### Generated Components
- ✅ **Source Code**: Complete Swift implementation with modular architecture
- ✅ **Test Suite**: 51 comprehensive tests covering all functionality
- ✅ **Documentation**: README, inline comments, and developer guides
- ✅ **CI/CD Pipeline**: GitHub Actions with testing, linting, and automated releases
- ✅ **Code Quality**: SwiftLint configuration and violation fixes
- ✅ **Package Management**: Swift Package Manager configuration
- ✅ **Release Automation**: Automated binary builds and Homebrew formula generation

### Development Timeline
The entire project was created in a single AI conversation session, demonstrating rapid prototyping and full-stack development capabilities through conversational programming.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [Swift ArgumentParser](https://github.com/apple/swift-argument-parser)
- Inspired by the need for better contact management tools
- Thanks to the Swift community for excellent tooling

---

**ContactScrubby** - Making contact management simple and powerful.