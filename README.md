# licenseflow-ruby

Official Ruby SDK for LicenseFlow.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'licenseflow'
```

And then execute:

```bash
bundle install
```

## Quick Start

```ruby
require 'licenseflow'

client = LicenseFlow::Client.new(
  base_url: 'https://your-project.supabase.co',
  api_key: 'lf_live_xxxxxxxxxxxx', # Generated from the SaaS platform
  jwt_secret: 'your-jwt-secret'
)

begin
  # 1. Activate License
  activation = client.activate(
    license_key: 'XXXX-YYYY-ZZZZ-AAAA',
    device_name: 'Production Server'
  )
  puts "Activated: #{activation['success']}"

  # 2. Verify License (Uses internal memory cache)
  verification = client.verify(license_key: 'XXXX-YYYY-ZZZZ-AAAA')
  puts "Valid: #{verification['valid']}"

rescue LicenseFlow::RateLimitError
  puts "Rate limit exceeded"
rescue LicenseFlow::Error => e
  puts "Error: #{e.message}"
end
```

## Features

- **Hardware ID**: Built-in hostname identification.
- **Faraday Based**: Flexible HTTP client support.
- **Thread Safe Caching**: Basic in-memory caching.
- **JWT Support**: Secure offline validation.

## Phase 5: Entitlements

Check access to specific features:

```ruby
# Check boolean feature
if client.has_feature(verification, 'ai_features')
  enable_ai_features
end

# Get entitlement value
limit = client.get_entitlement(verification, 'max_users')
puts "User limit: #{limit}"
```

## Phase 5: Release Management

Check for updates and download artifacts:

```ruby
# Check for updates
update = client.check_for_updates(
  product_id: 'prod_123',
  current_version: 'v1.0.0',
  channel: 'stable'
)

if update
  puts "New version: #{update['version']}"
  
  # Get download link
  download = client.download_artifact(
    license_key: 'LF-KEY-123',
    release_id: update['id'],
    platform: 'linux',
    architecture: 'arm64'
  )
  
  puts "Download URL: #{download['url']}"
end
```

## Phase 5: Offline Licensing

Verify a license file without internet access:

```ruby
license_content = File.read('license.lic')
public_key = 'YOUR_ORG_PUBLIC_KEY_HEX'

begin
  license = client.verify_offline_license(license_content, public_key)
  puts "Offline license valid!"
rescue StandardError => e
  puts "Invalid license: #{e.message}"
end
```
