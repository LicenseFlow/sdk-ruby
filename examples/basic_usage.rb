require 'licenseflow'

client = LicenseFlow::Client.new(
  base_url: 'https://api.licenseflow.dev/v1',
  api_key: 'test-api-key'
)

puts "--- LicenseFlow Ruby Example ---"

# 1. Activate
puts "Activating license..."
activation = client.activate(
  license_key: 'DEMO-KEY',
  device_name: 'Ruby-App'
)
puts "Result: #{activation}"

# 2. Verify
puts "Verifying license..."
verify = client.verify(license_key: 'DEMO-KEY')
puts "Is Valid: #{verify['valid']}"

# 3. Deactivate
puts "Deactivating license..."
deactivation = client.deactivate(license_key: 'DEMO-KEY')
puts "Result: #{deactivation}"
