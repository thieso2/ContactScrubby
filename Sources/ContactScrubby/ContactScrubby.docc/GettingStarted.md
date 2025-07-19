# Getting Started with ContactScrubby

Learn how to install, configure, and use ContactScrubby for contact management.

## Installation

### Build from Source

Clone the repository and build the project:

```bash
git clone https://github.com/your-repo/ContactScrubby.git
cd ContactScrubby
swift build -c release
```

The executable will be available at `.build/release/contactscrub`.

### System Requirements

- macOS 10.15 or later
- Swift 6.0 or later
- Xcode 16.0 or later (for development)

## First Steps

### Grant Contacts Permission

Before using ContactScrubby, you'll need to grant permission to access your Contacts:

1. Run any ContactScrubby command
2. macOS will prompt for Contacts access
3. Click "OK" to grant permission

Alternatively, you can pre-authorize in System Preferences:
- Go to System Preferences → Security & Privacy → Privacy → Contacts
- Add ContactScrubby to the allowed applications

### Basic Commands

#### View All Contacts

```bash
contactscrub list --filter all
```

#### Find Dubious Contacts

```bash
contactscrub analyze --filter dubious
```

#### Export Contacts

```bash
contactscrub export --destination my-contacts.json --filter all
```

## Understanding Contact Analysis

ContactScrubby uses a sophisticated scoring system to identify potentially problematic contacts:

### Scoring Criteria

- **Missing Information**: Contacts without names, emails, or phone numbers
- **Generic Names**: Common placeholder names like "Test" or "Sample"
- **Suspicious Patterns**: Sequential phone numbers, numeric emails
- **Facebook-Only Contacts**: Contacts with only Facebook-generated emails

### Dubious Score Thresholds

- **1-2**: Minor issues (incomplete information)
- **3-5**: Moderate concerns (suspicious patterns)
- **6+**: High probability of being fake or unwanted

## Export and Import

### Supported Formats

ContactScrubby supports three file formats:

#### JSON
- **Pros**: Human-readable, widely supported, preserves all data
- **Cons**: Larger file size
- **Use Case**: Data analysis, backup, integration with other tools

#### XML
- **Pros**: Hierarchical structure, self-documenting
- **Cons**: Verbose, larger file size
- **Use Case**: Enterprise systems, web services

#### VCF (vCard)
- **Pros**: Industry standard, widely compatible
- **Cons**: Limited metadata support
- **Use Case**: Contact exchange between different applications

### Image Handling

Choose how to handle contact profile images:

- **none**: Skip images entirely (fastest, smallest files)
- **inline**: Embed as Base64 data (portable but larger files)
- **folder**: Save to separate directory (organized but multiple files)

## Filtering Options

ContactScrubby provides powerful filtering to work with specific contact subsets:

### Email-Based Filters

```bash
# Contacts with email addresses
contactscrub list --filter with-email

# Contacts without email addresses  
contactscrub list --filter no-email

# Contacts with only Facebook emails
contactscrub list --filter facebook-exclusive
```

### Quality-Based Filters

```bash
# All dubious contacts
contactscrub analyze --filter dubious

# Dubious contacts with custom threshold
contactscrub analyze --filter dubious --dubious-score 4

# Contacts with no contact information
contactscrub list --filter no-contact
```

## Configuration

### Command Line Options

Most behavior can be customized through command-line flags:

```bash
# Verbose output for debugging
contactscrub export --destination backup.json --verbose

# Include metadata in exports
contactscrub export --destination backup.json --include-metadata

# Limit number of results
contactscrub list --filter all --limit 10
```

### Environment Variables

ContactScrubby respects several environment variables:

- `CONTACTSCRUBBY_LOG_LEVEL`: Set logging level (debug, info, warning, error)
- `CONTACTSCRUBBY_BATCH_SIZE`: Control batch processing size for large contact lists

## Troubleshooting

### Common Issues

#### Permission Denied
```
❌ Access to Contacts was denied
💡 Grant permission in System Preferences > Security & Privacy > Privacy > Contacts
```

#### No Contacts Found
```
❌ No contacts found matching the specified criteria
```
- Try a different filter mode
- Check that you have contacts in your database
- Verify the dubious score threshold isn't too restrictive

#### Export Failed
```
❌ Export failed: Permission denied for path: /protected/folder/
💡 Choose a different location or check file permissions
```

### Getting Help

Use the built-in help system:

```bash
# General help
contactscrub --help

# Command-specific help
contactscrub export --help
contactscrub analyze --help
```

## Next Steps

- Read the [Architecture Guide](ArchitectureGuide) to understand the internal design
- Explore [Advanced Usage](AdvancedUsage) for power-user features
- Check the [API Documentation](api-documentation) for programmatic integration