require 'minitest/autorun'
require 'tmpdir'
require 'ostruct'
require_relative '../lib/licenseflow/audit_log'

class AuditLogTest < Minitest::Test
  def test_masking
    assert_equal '****-9A2C', LicenseFlow::AuditLog.mask('LF-SECRET-9A2C')
    assert_equal '****', LicenseFlow::AuditLog.mask('tiny')
  end

  def test_file_writes_and_retention
    Dir.mktmpdir('lf-ruby-') do |dir|
      original = ENV['LICENSEFLOW_AUDIT_DIR']
      ENV['LICENSEFLOW_AUDIT_DIR'] = dir
      begin
        logger = LicenseFlow::AuditLog.new(nil)
        logger.send(:write, 'verify', 'LF-SECRET-9A2C', 200, 4, 'request-123')
        files = Dir.glob(File.join(dir, 'licenseflow-audit-*.txt'))
        assert_equal 1, files.length
        text = File.read(files.first)
        refute_includes text, 'SECRET'
        assert_includes text, 'request_id=request-123'
        old = File.join(dir, 'licenseflow-audit-2000-01-01.txt')
        File.write(old, 'old'); File.utime(Time.at(0), Time.at(0), old)
        logger.send(:write, 'verify', nil, 0, 4, '-')
        refute File.exist?(old)
      ensure
        ENV['LICENSEFLOW_AUDIT_DIR'] = original
      end
    end
  end
end