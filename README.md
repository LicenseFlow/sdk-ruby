# LicenseFlow Ruby SDK

[![Gem Version](https://img.shields.io/gem/v/licenseflow)](https://rubygems.org/gems/licenseflow)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

**Stop Building Licensing Infrastructure. Start Shipping Software.**

The official Ruby SDK for [LicenseFlow](https://licenseflow.dev). Protect your intellectual property, enforce entitlements, and manage software distribution with enterprise-grade security.

## Installation

```ruby
gem 'licenseflow'
```

```bash
bundle install
```

## Quick Start

```ruby
require 'licenseflow'

client = LicenseFlow::Client.new(
  base_url: 'https://api.licenseflow.dev',
  api_key: 'lf_live_xxxxxxxxxxxx',
  jwt_secret: 'your-jwt-secret'
)

activation = client.activate(
  license_key: 'XXXX-YYYY-ZZZZ-AAAA',
  device_name: 'Production Server'
)
puts "Activated: #{activation['success']}"

verification = client.verify(license_key: 'XXXX-YYYY-ZZZZ-AAAA')
puts "Valid: #{verification['valid']}"
```

---

## Entitlement Caching

`LicenseFlow::Client` includes `EntitlementCache` — a TTL-based in-memory cache with offline grace period.

```ruby
client = LicenseFlow::Client.new(
  base_url:      'https://api.licenseflow.dev',
  api_key:       'lf_live_xxxxxxxxxxxx',
  jwt_secret:    'your-jwt-secret',
  cache_ttl:     300,       # Cache TTL in seconds (default: 5 min)
  offline_grace: 259200    # Offline grace in seconds (default: 72h)
)

# First call: fetches from API, populates cache
result = client.verify(license_key: 'XXXX-YYYY-ZZZZ-AAAA')

# Subsequent calls within TTL: instant, no network
result = client.verify(license_key: 'XXXX-YYYY-ZZZZ-AAAA')

# During network outage within grace: stale cache used
# After grace expires: LicenseFlow::OfflineLicenseError raised
```

---

## API Reference

### Core Methods

| Method | Description |
|--------|-------------|
| `activate(license_key:, device_name:, environment_id: nil)` | Activate on a device |
| `verify(license_key:, environment_id: nil)` | Verify license (cached) |
| `deactivate(license_key:, device_id: nil)` | Deactivate from a device |
| `record_usage(license_key:, metric_name:, value:, increment: true)` | Track usage |
| `get_hardware_id` | Get hostname-based device ID |

### Entitlements

```ruby
if client.has_feature(verification, 'ai_features')
  enable_ai_features
end

limit = client.get_entitlement(verification, 'max_users')
puts "User limit: #{limit}"
```

### Floating Licenses (Leases)

```ruby
lease = client.checkout_license(
  license_key: 'XXXX-XXXX',
  duration_seconds: 3600,
  requester_id: "ci-#{ENV['CI_JOB_ID']}",
  requester_type: 'ci_runner'
)
puts "Lease: #{lease['lease_key']}"

client.checkin_license(lease['lease_key'])
status = client.get_lease_status(lease['lease_key'])
```

### Credits

```ruby
result = client.consume_credits(amount: 100, description: 'AI tokens')
puts "Remaining: #{result['remaining']}"

balance = client.get_credits_balance
```

### Release Management

```ruby
update = client.check_for_updates(
  product_id: 'prod_123',
  current_version: 'v1.0.0',
  channel: 'stable'
)

if update
  download = client.download_artifact(
    license_key: 'XXXX-XXXX',
    release_id: update['id'],
    platform: 'linux',
    architecture: 'arm64'
  )
  puts "Download: #{download['url']}"
end
```

### Offline Licensing

```ruby
license_content = File.read('license.lic')
license = client.verify_offline_license(license_content, 'ORG_PUBLIC_KEY_HEX')
puts "Valid until: #{license['valid_until']}"
```

### Heartbeat

```ruby
client.start_heartbeat('XXXX-XXXX', interval: 60)
# ... later
client.stop_heartbeat
```

---

## Error Handling

```ruby
begin
  client.activate(license_key: 'XXXX', device_name: 'Server')
rescue LicenseFlow::RateLimitError
  puts "Rate limit exceeded"
rescue LicenseFlow::InvalidLicenseError
  puts "Invalid license"
rescue LicenseFlow::NetworkError
  puts "Network error"
end
```

## Features

- **Faraday HTTP** — Flexible, middleware-based HTTP client
- **EntitlementCache** — In-memory TTL cache with configurable offline grace period
- **JWT Validation** — Offline proof verification
- **Ed25519** — Cryptographic offline license verification

## License

MIT

## Links

- 📖 [Documentation](https://docs.licenseflow.dev)
- 🐛 [Issues](https://github.com/LicenseFlow/sdk-ruby/issues)
- 🏠 [Homepage](https://licenseflow.dev)
