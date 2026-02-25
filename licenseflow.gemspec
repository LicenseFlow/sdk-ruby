Gem::Specification.new do |s|
  s.name        = 'licenseflow'
  s.version     = '2.1.0'
  s.summary     = "Official Ruby SDK for LicenseFlow"
  s.description = "Complete licensing, activation, entitlements, floating licenses, and software distribution for Ruby applications."
  s.authors     = ["LicenseFlow"]
  s.email       = ['hello@licenseflow.dev']
  s.files       = Dir["lib/**/*.rb"]
  s.homepage    = 'https://github.com/licenseflow/ruby-sdk'
  s.license     = 'MIT'
  s.required_ruby_version = '>= 2.7'

  s.metadata = {
    "homepage_uri"      => "https://licenseflow.dev",
    "source_code_uri"   => "https://github.com/licenseflow/ruby-sdk",
    "bug_tracker_uri"   => "https://github.com/licenseflow/ruby-sdk/issues",
    "documentation_uri" => "https://docs.licenseflow.dev",
    "changelog_uri"     => "https://github.com/licenseflow/ruby-sdk/blob/main/CHANGELOG.md"
  }

  s.add_dependency 'faraday', '~> 2.0'
  s.add_dependency 'json', '~> 2.0'
  s.add_dependency 'jwt', '~> 2.0'
  s.add_dependency 'ed25519', '~> 1.3'
end
