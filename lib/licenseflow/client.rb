require 'faraday'
require 'json'
require 'jwt'
require 'socket'
require_relative 'errors'
require 'ed25519'
require 'base64'
require 'time'

module LicenseFlow
  class Client
    attr_reader :api_key, :base_url, :jwt_secret

    def initialize(config)
      @api_key = config[:api_key]
      @base_url = config[:base_url].chomp('/')
      @jwt_secret = config[:jwt_secret]
      @cache = {}
      @timeout = config[:timeout] || 10

      @conn = Faraday.new(url: @base_url) do |f|
        f.headers['x-api-key'] = @api_key
        f.headers['Authorization'] = "Bearer #{@api_key}"
        f.headers['Content-Type'] = 'application/json'
        f.request :json
        f.options.timeout = @timeout
        f.adapter Faraday.default_adapter
      end
    end

    def get_hardware_id
      Socket.gethostname
    end

    def activate(params)
      params[:device_id] ||= get_hardware_id
      
      begin
        response = @conn.post('/functions/v1/activate-license', params.to_json)
        handle_errors!(response)
        JSON.parse(response.body)
      rescue Faraday::Error => e
        raise NetworkError, e.message
      end
    end

    def verify(params)
      params[:device_id] ||= get_hardware_id
      license_key = params[:license_key]
      device_id = params[:device_id]
      environment_id = params[:environment_id] || 'default'
      cache_key = "verify:#{license_key}:#{device_id}:#{environment_id}"

      return @cache[cache_key] if @cache.key?(cache_key)

      # Remap to camelCase field names expected by the verify-license backend
      backend_payload = {
        licenseKey: license_key,
        deviceId: device_id
      }
      backend_payload[:environmentId] = params[:environment_id] if params[:environment_id]

      begin
        response = @conn.post('/functions/v1/verify-license', backend_payload.to_json)
        handle_errors!(response)
        data = JSON.parse(response.body)
        
        @cache[cache_key] = data if data['valid']
        data
      rescue Faraday::Error => e
        raise NetworkError, e.message
      end
    end

    def record_usage(params)
      begin
        response = @conn.post('/functions/v1/record-usage', params.to_json)
        handle_errors!(response)
        { success: true }.merge(JSON.parse(response.body))
      rescue Faraday::Error => e
        raise NetworkError, e.message
      end
    end

    def deactivate(params)
      params[:device_id] ||= get_hardware_id
      
      begin
        response = @conn.post('/functions/v1/deactivate-license', params.to_json)
        handle_errors!(response)
        @cache.clear # Clear cache
        JSON.parse(response.body)
      rescue Faraday::Error => e
        raise NetworkError, e.message
      end
    end

    def validate_proof_offline(proof, secret = nil)
      key = secret || @jwt_secret
      raise Error, "JWT Secret is required for offline validation" unless key

      begin
        decoded = JWT.decode(proof, key, true, { algorithm: 'HS256' })
        {
          valid: true,
          payload: decoded[0]
        }
      rescue JWT::DecodeError => e
        {
          valid: false,
          error: e.message
        }
      end
    end

    def has_feature?(verification, feature_code)
      return false unless verification['valid'] && verification['entitlements']
      
      ent = verification['entitlements'][feature_code]
      return false if ent.nil?

      if ent.is_a?(TrueClass) || ent.is_a?(FalseClass)
        return ent
      elsif ent.is_a?(Hash)
        return ent['enabled'] == true || ent['value'] == true
      end
      
      ent == true
    end

    def get_entitlement(verification, feature_code)
      return nil unless verification['valid'] && verification['entitlements']
      verification['entitlements'][feature_code]
    end

    def check_for_updates(params)
      begin
        response = @conn.get('/functions/v1/release-management/latest', params)
        return nil if response.status == 404
        
        handle_errors!(response)
        data = JSON.parse(response.body)
        
        return nil if data.nil? || data['version'] == params[:currentVersion]
        data
      rescue Faraday::Error => e
        raise NetworkError, e.message
      end
    end

    def download_artifact(params)
      begin
        response = @conn.post('/functions/v1/artifact-download', params.to_json)
        handle_errors!(response)
        JSON.parse(response.body)
      rescue Faraday::Error => e
        raise NetworkError, e.message
      end
    end

    def checkout_license(license_key, duration_seconds: 3600, requester_id: nil, requester_type: 'ci', metadata: nil)
      payload = {
        license_key: license_key,
        duration_seconds: duration_seconds,
        requester_id: requester_id || get_hardware_id,
        requester_type: requester_type
      }
      payload[:metadata] = metadata if metadata

      begin
        response = @conn.post('/functions/v1/checkout-license', payload.to_json)
        handle_errors!(response)
        JSON.parse(response.body)
      rescue Faraday::Error => e
        raise NetworkError, e.message
      end
    end

    def checkin_license(lease_key)
      begin
        response = @conn.post('/functions/v1/checkin-license', { lease_key: lease_key }.to_json)
        handle_errors!(response)
        JSON.parse(response.body)
      rescue Faraday::Error => e
        raise NetworkError, e.message
      end
    end

    def get_lease_status(lease_key)
      begin
        response = @conn.get('/functions/v1/lease-status', { lease_key: lease_key })
        return nil if response.status == 404
        handle_errors!(response)
        JSON.parse(response.body)
      rescue Faraday::Error => e
        raise NetworkError, e.message
      end
    end

    # ── Credits / Usage-Based Billing ──

    def consume_credits(amount, description: nil, product_id: nil, currency: 'credits', reference_id: nil, reference_type: nil, metadata: nil)
      payload = { amount: amount }
      payload[:description] = description if description
      payload[:product_id] = product_id if product_id
      payload[:currency] = currency if currency != 'credits'
      payload[:reference_id] = reference_id if reference_id
      payload[:reference_type] = reference_type if reference_type
      payload[:metadata] = metadata if metadata

      begin
        response = @conn.post('/functions/v1/consume-credits', payload.to_json)
        handle_errors!(response)
        JSON.parse(response.body)
      rescue Faraday::Error => e
        raise NetworkError, e.message
      end
    end

    def get_credits_balance(product_id: nil, currency: nil)
      params = {}
      params[:product_id] = product_id if product_id
      params[:currency] = currency if currency

      begin
        response = @conn.get('/functions/v1/get-credit-balance', params)
        handle_errors!(response)
        JSON.parse(response.body)
      rescue Faraday::Error => e
        raise NetworkError, e.message
      end
    end

    # ── Entitlements Management ──

    def list_entitlements
      begin
        response = @conn.get('/functions/v1/manage-entitlements')
        handle_errors!(response)
        JSON.parse(response.body)
      rescue Faraday::Error => e
        raise NetworkError, e.message
      end
    end

    def create_entitlement(code, name, data_type: 'boolean', description: nil, metadata: nil)
      payload = { code: code, name: name, data_type: data_type }
      payload[:description] = description if description
      payload[:metadata] = metadata if metadata

      begin
        response = @conn.post('/functions/v1/manage-entitlements', payload.to_json)
        handle_errors!(response)
        JSON.parse(response.body)
      rescue Faraday::Error => e
        raise NetworkError, e.message
      end
    end

    def update_entitlement(entitlement_id, updates)
      begin
        response = @conn.patch("/functions/v1/manage-entitlements/#{entitlement_id}", updates.to_json)
        handle_errors!(response)
        JSON.parse(response.body)
      rescue Faraday::Error => e
        raise NetworkError, e.message
      end
    end

    def delete_entitlement(entitlement_id)
      begin
        response = @conn.delete("/functions/v1/manage-entitlements/#{entitlement_id}")
        handle_errors!(response)
        JSON.parse(response.body)
      rescue Faraday::Error => e
        raise NetworkError, e.message
      end
    end

    def assign_entitlement_to_license(entitlement_id, license_id, value)
      begin
        response = @conn.post("/functions/v1/manage-entitlements/#{entitlement_id}/assign-to-license",
          { license_id: license_id, value: value }.to_json)
        handle_errors!(response)
        JSON.parse(response.body)
      rescue Faraday::Error => e
        raise NetworkError, e.message
      end
    end

    def assign_entitlement_to_policy(entitlement_id, policy_id, default_value)
      begin
        response = @conn.post("/functions/v1/manage-entitlements/#{entitlement_id}/assign-to-policy",
          { policy_id: policy_id, default_value: default_value }.to_json)
        handle_errors!(response)
        JSON.parse(response.body)
      rescue Faraday::Error => e
        raise NetworkError, e.message
      end
    end

    def verify_offline_license(license_content, public_key_hex)
      begin
        data = JSON.parse(license_content)
        raise "Invalid license format" unless data['license'] && data['signature']

        message = data['license'].to_json
        signature = Base64.decode64(data['signature'])
        public_key_bytes = [public_key_hex].pack('H*')

        verify_key = Ed25519::VerifyKey.new(public_key_bytes)
        verify_key.verify(signature, message)
        
        # Check expiry
        if data['license']['valid_until']
          expires_at = Time.parse(data['license']['valid_until'])
          raise "License expired" if Time.now > expires_at
        end

        data['license']
      rescue => e
        raise "Offline verification failed: #{e.message}"
      end
    end

    private

    def handle_errors!(response)
      return if [200, 201].include?(response.status)

      begin
        data = JSON.parse(response.body)
        message = data['message'] || data['error'] || "HTTP #{response.status}"
      rescue
        message = response.body
      end

      case response.status
      when 429
        raise RateLimitError, message
      when 400, 404
        raise InvalidLicenseError, message
      else
        raise Error, message
      end
    end
  end
end
