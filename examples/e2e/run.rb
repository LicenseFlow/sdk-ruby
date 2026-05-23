require 'licenseflow'

%w[LICENSEFLOW_API_URL LICENSEFLOW_API_KEY LICENSE_KEY REVOKED_LICENSE_KEY].each do |k|
  abort("Missing env: #{k}") unless ENV[k]
end

c = LicenseFlow::Client.new(base_url: ENV['LICENSEFLOW_API_URL'], api_key: ENV['LICENSEFLOW_API_KEY'])
lk, rk = ENV['LICENSE_KEY'], ENV['REVOKED_LICENSE_KEY']

c.activate(license_key: lk, device_name: 'ci-rb')
abort('active must verify')      unless c.verify(license_key: lk).valid
abort('revoked must not verify') if     c.verify(license_key: rk).valid
c.deactivate(license_key: lk)
puts 'Ruby SDK E2E ✓'