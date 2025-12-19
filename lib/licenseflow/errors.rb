module LicenseFlow
  class Error < StandardError; end
  class NetworkError < Error; end
  class RateLimitError < Error; end
  class InvalidLicenseError < Error; end
end
