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

      begin
        response = @conn.post('/functions/v1/verify-license', params.to_json)
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
