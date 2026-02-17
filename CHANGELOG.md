# Changelog

All notable changes to the LicenseFlow Ruby SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-02-17

### Added
- Environment scoping support: `environment_id` parameter now supported in all license operations
- Cache isolation between environments to prevent cross-environment cache collisions

### Changed
- Updated `verify()` method to include `environment_id` in cache key generation
- Cache key format now: `"verify:#{license_key}:#{device_id}:#{environment_id}"`
- Defaults to `'default'` environment when `environment_id` is not provided

### Technical Details
- **Breaking Change**: None - fully backward compatible
- **Migration**: No code changes required for existing implementations
- **Usage**: Pass `environment_id` parameter in method calls to scope licenses to specific environments

## [2.0.0] - Previous Release

Initial release with core license management features.
