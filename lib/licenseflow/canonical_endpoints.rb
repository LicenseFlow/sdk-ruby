# frozen_string_literal: true

require 'faraday'

module LicenseFlow
  # Canonical REST paths (SDK v2.3+). The api.licenseflow.dev gateway serves
  # both these and the legacy /functions/v1/<name> paths indefinitely.
  class CanonicalEndpoints < Faraday::Middleware
    PATHS = {
      'verify-license' => '/v1/licenses/verify',
      'activate-license' => '/v1/licenses/activate',
      'deactivate-license' => '/v1/licenses/deactivate',
      'checkout-license' => '/v1/licenses/checkout',
      'lease-status' => '/v1/licenses/lease-status',
      'generate-offline-license' => '/v1/licenses/offline',
      'record-usage' => '/v1/usage/record',
      'resolve-entitlements' => '/v1/entitlements/resolve',
      'check-entitlement' => '/v1/entitlements/check',
      'authorize' => '/v1/access/authorize'
    }.freeze

    LEGACY_PREFIX = '/functions/v1/'

    def self.canonical_path(host, path)
      return nil unless host == 'api.licenseflow.dev'

      i = path.index(LEGACY_PREFIX)
      return nil unless i

      PATHS[path[(i + LEGACY_PREFIX.length)..]]
    end

    def call(env)
      target = self.class.canonical_path(env.url.host, env.url.path)
      return @app.call(env) unless target

      legacy_url = env.url.dup
      body = env.request_body
      env.url = env.url.dup.tap { |u| u.path = target }
      response = @app.call(env)
      # A 404 from the gateway itself has no X-LicenseFlow-Route header: fall back once.
      return response unless response.status == 404 && response.headers['x-licenseflow-route'].nil?

      env.url = legacy_url
      env.request_body = body
      @app.call(env)
    end
  end
end
