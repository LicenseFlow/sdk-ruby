require 'fileutils'
require 'time'
require 'json'
require 'faraday'

module LicenseFlow
  class AuditLog < Faraday::Middleware
    def self.mask(key)
      key.to_s.empty? ? '-' : (key.to_s.length <= 4 ? '****' : "****-#{key.to_s[-4, 4]}")
    end

    def call(env)
      return @app.call(env) unless %w[1 true yes].include?(ENV.fetch('LICENSEFLOW_AUDIT_LOG', '').downcase)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      action = env.url.path.sub(%r{^/(functions/)?v1/}, '').split('/').first
      body = begin JSON.parse(env.request_body.to_s); rescue; {}; end
      key = body['license_key'] || body['licenseKey']
      status = 0
      rid = '-'
      begin
        response = @app.call(env)
        status = response.status
        rid = response.headers['x-request-id'] || '-'
        response
      ensure
        write(action, key, status, ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).to_i, rid)
      end
    end

    private

    def write(action, key, status, duration, rid)
      dir = ENV['LICENSEFLOW_AUDIT_DIR'] || (Gem.win_platform? ? File.join(ENV['LOCALAPPDATA'] || Dir.home, 'LicenseFlow', 'logs') : File.join(Dir.home, '.licenseflow', 'logs'))
      FileUtils.mkdir_p(dir, mode: 0700)
      File.open(File.join(dir, '.audit.lock'), File::RDWR | File::CREAT, 0600) do |lock|
        lock.flock(File::LOCK_EX)
        now = Time.now.utc
        stem = File.join(dir, "licenseflow-audit-#{now.strftime('%Y-%m-%d')}")
        file = "#{stem}.txt"
        i = 0
        while File.exist?(file) && File.size(file) >= 10 * 1024 * 1024
          i += 1
          file = "#{stem}.#{i}.txt"
        end
        safe = ->(s) { s.to_s.gsub(/[^A-Za-z0-9._-]/, '_')[0, 120] }
        line = "#{now.iso8601(3)} | actor=app | action=#{safe.call(action)} | license=#{self.class.mask(key)} | result=#{status >= 200 && status < 400 ? 'ok' : 'error'} | status=#{status.zero? ? '-' : status} | duration_ms=#{duration} | request_id=#{safe.call(rid)}\n"
        File.open(file, File::WRONLY | File::APPEND | File::CREAT, 0600) { |f| f.write(line) }
        Dir.glob(File.join(dir, 'licenseflow-audit-*.txt')).each { |old| File.delete(old) if File.mtime(old) < now - 14 * 86400 }
      end
    rescue StandardError
      # Never break the host application.
      nil
    end
  end
end