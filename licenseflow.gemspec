Gem::Specification.new do |s|
  s.name        = 'licenseflow'
  s.version     = '0.1.0'
  s.summary     = "Official Ruby SDK for LicenseFlow"
  s.authors     = ["LicenseFlow"]
  s.email       = ['hello@licenseflow.com']
  s.files       = ["lib/licenseflow.rb", "lib/licenseflow/client.rb", "lib/licenseflow/errors.rb"]
  s.homepage    = 'https://github.com/licenseflow/ruby-sdk'
  s.license     = 'MIT'

  s.add_dependency 'faraday', '~> 2.0'
  s.add_dependency 'json', '~> 2.0'
  s.add_dependency 'jwt', '~> 2.0'
end
