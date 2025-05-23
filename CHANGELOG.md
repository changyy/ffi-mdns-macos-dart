# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-05-23

### Changed
- **Native callback now uses JSON string**: All device and error information is returned as a single JSON string from native code, enabling richer and more extensible data exchange.
- **Debug mode with multiple levels**: Both native and Dart layers now support debug levels (0=quiet, 1=error/result, 2=normal, 3=verbose). CLI and examples allow fine-grained debug control via `--debug[=<level>]`.
- **Dart FFI bindings updated**: All FFI bindings and callback signatures updated to support JSON callback, with correct type safety and error handling.
- **CLI tool (`mdns_cli.dart`)**: All scan commands now use the new JSON callback interface. Debug option is fully documented and supports levels. Usage/help is now fully in English.
- **Examples and tests updated**: All example and test files now use the JSON callback interface and support debug level control. All comments and output are in English.
- **Error reporting improved**: Native and Dart errors are now reported in a unified JSON format, and CLI displays them clearly.
- **Resource management**: Improved cleanup and disposal logic in FFI and CLI.

### Fixed
- Fixed type errors in FFI and CLI caused by debug parameter type changes (now always `int`).
- Fixed class/method structure issues in FFI binding layer.
- Fixed example/test code to match new API and debug conventions.

### Added
- Support for debug level 0 (quiet mode): only final device results are shown by default.
- CLI and API now allow setting debug level from 0 to 3 for granular control.
- All output, comments, and documentation are now in English for international use.

## [1.0.2] - 2025-05-23

### Fixed
- Fixed example file name to `native_mdns_scanner_example.dart`

## [1.0.1] - 2025-05-23

### Fixed
- Fixed example file name to `*_example.dart`

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
