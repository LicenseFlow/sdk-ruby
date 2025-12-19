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
  api_key: 'your-api-key',
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
