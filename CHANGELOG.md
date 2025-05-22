# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-05-23

### Added
- **Initial release** of native_mdns_scanner for macOS
- **Native mDNS/Bonjour service discovery** using macOS system APIs via FFI
- **Simultaneous multi-service scanning** - scan multiple service types at once
- **Periodic scanning support** with configurable query intervals and duration
- **Rich device information** including IP, port, service type, TXT records, and discovery metadata
- **Timing analysis tools** for analyzing discovery patterns and performance
- **Command-line interface** (`mdns_cli`) for testing and debugging
- **Comprehensive API** with the following classes:
  - `MdnsFfi` - Main scanning functionality
  - `DeviceInfo` - Device/service information model
  - `TimingAnalyzer` - Discovery timing analysis utilities
- **Multiple scanning modes**:
  - Simple single-service scanning
  - Multi-service simultaneous scanning
  - Periodic scanning with custom intervals
- **Flexible library loading** with automatic path detection
- **Full test coverage** with unit and integration tests
- **Example applications** demonstrating various use cases

### Features
- 🔍 **High-performance native implementation** using Objective-C and macOS Bonjour APIs
- 🎯 **Simultaneous scanning** - unlike sequential-only libraries
- ⏱️ **Smart timing analysis** to verify simultaneous discovery
- 🖥️ **CLI tool** with multiple commands and options
- 📊 **Detailed discovery metrics** and statistics
- 🧹 **Proper resource management** with automatic cleanup

### Platform Support
- ✅ macOS (arm64 + x86_64 universal binary)
- ❌ iOS (not supported in this release)
- ❌ Windows/Linux (not supported)

### Dependencies
- Dart SDK: >=3.0.0 <4.0.0
- ffi: ^2.1.4

### Documentation
- Complete README with usage examples
- API documentation for all public classes
- CLI usage guide with examples
- Build instructions for the native library

[1.0.0]: https://github.com/changyy/ffi-mdns-macos-dart/releases/tag/v1.0.0
