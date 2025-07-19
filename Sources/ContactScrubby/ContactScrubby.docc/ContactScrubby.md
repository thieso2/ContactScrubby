# ``ContactScrubby``

A modern, powerful contact management and analysis tool for macOS.

## Overview

ContactScrubby is a Swift-based command-line application that helps you analyze, clean, and manage your macOS Contacts database. It features a modern protocol-oriented architecture with comprehensive contact analysis, multiple export formats, and intelligent filtering capabilities.

### Key Features

- **Contact Analysis**: Intelligent scoring system to identify dubious or incomplete contacts
- **Multiple Formats**: Support for JSON, XML, and VCF (vCard) import/export
- **Advanced Filtering**: Filter contacts by email status, completeness, and quality scores
- **Modern Architecture**: Protocol-oriented design with dependency injection and async/await
- **CLI Interface**: Full backward compatibility with intuitive modern syntax

### Architecture

ContactScrubby is built with a three-layer architecture:

1. **Core Layer**: Foundation types, protocols, and error handling
2. **Services Layer**: Business logic implementations with dependency injection
3. **CLI Layer**: Command-line interface with both modern and legacy syntax support

## Topics

### Core Foundation

- ``ContactID``
- ``ContactLabel``
- ``ExportFormat``
- ``FilterMode``
- ``ImageExportStrategy``

### Protocols and Services

- ``ContactManaging``
- ``ContactAnalyzing`` 
- ``ContactExporting``
- ``ContactImporting``
- ``ContactFiltering``

### Error Handling

- ``ContactError``
- ``AnalysisError``
- ``ExportError``
- ``ImportError``
- ``PermissionError``

### Property Wrappers

- ``Sanitized``
- ``Validated``

### Data Models

- ``Contact``
- ``ContactAnalysis``
- ``ExportConfiguration``
- ``ContactFilter``

## Getting Started

### Installation

```bash
swift build -c release
```

### Basic Usage

#### Analyze Dubious Contacts

```bash
contactscrub analyze --filter dubious --show-details
```

#### Export Contacts

```bash
contactscrub export --destination backup.json --filter with-email
```

#### Import VCF File

```bash
contactscrub import --source contacts.vcf --create-in-contacts
```

### Legacy Compatibility

ContactScrubby maintains full backward compatibility with previous versions:

```bash
# Legacy syntax still works
contactscrub --filter dubious --backup contacts.vcf
contactscrub --filter all --all-fields
```

## Advanced Usage

### Custom Filtering

You can combine multiple filtering criteria:

```bash
contactscrub analyze --filter dubious --dubious-score 5 --show-details
```

### Image Export Strategies

Choose how to handle contact images during export:

```bash
contactscrub export --destination backup.json --images inline
contactscrub export --destination backup.xml --images folder
```

### Performance Monitoring

Enable verbose logging to monitor operation performance:

```bash
contactscrub export --destination backup.json --verbose
```

## API Documentation

### Core Types

The foundation types provide type-safe identifiers and enums for all contact operations.

### Service Protocols

All business logic is implemented through protocols, enabling easy testing and dependency injection.

### Error Handling

Comprehensive error types with recovery suggestions help users understand and resolve issues.