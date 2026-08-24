# frozen_string_literal: true

module LicenseFlow
  # Thread-safe, TTL-based local entitlement cache for zero-network-request validation.
  #
  # Strategies:
  #   'cache-first'            — Return cache if valid, else network.
  #   'stale-while-revalidate' — Return cache immediately, revalidate in background.
  #   'network-first'          — Always hit network, cache as fallback.
  #
  # @example
  #   cache = LicenseFlow::EntitlementCache.new(ttl_seconds: 300)
  #   cached = cache.get('LF-XXXX-XXXX')
  #   if cached
  #     # Zero network I/O
  #     puts cached[:data]
  #   end
  class EntitlementCache
    CachedEntry = Struct.new(:data, :cached_at, :expires_at, :source, keyword_init: true)

    def initialize(ttl_seconds: 300, offline_grace_hours: 72.0, strategy: 'stale-while-revalidate')
      @entries = {}
      @mutex = Mutex.new
      @ttl = ttl_seconds
      @grace_seconds = offline_grace_hours * 3600
      @strategy = strategy
    end

    # Get cached entitlements. Returns nil on miss or full expiry.
    def get(key)
      @mutex.synchronize do
        entry = @entries[key]
        return nil unless entry

        now = Time.now.to_f

        # Within normal TTL
        if now < entry.expires_at
          return CachedEntry.new(data: entry.data, cached_at: entry.cached_at,
                                 expires_at: entry.expires_at, source: 'cache')
        end

        # Within offline grace period
        if now < entry.cached_at + @grace_seconds
          return CachedEntry.new(data: entry.data, cached_at: entry.cached_at,
                                 expires_at: entry.expires_at, source: 'offline')
        end

        # Fully expired
        @entries.delete(key)
        nil
      end
    end

    # Store entitlement decision in cache.
    def set(key, data)
      now = Time.now.to_f
      @mutex.synchronize do
        @entries[key] = CachedEntry.new(
          data: data,
          cached_at: now,
          expires_at: now + @ttl,
          source: 'network'
        )
      end
    end

    # Remove a specific cached entry.
    def invalidate(key)
      @mutex.synchronize { @entries.delete(key) }
    end

    # Clear all cached entries.
    def flush
      @mutex.synchronize { @entries.clear }
    end

    # Determine cache action: 'use_cache', 'use_cache_revalidate', or 'use_network'.
    def get_strategy(key)
      entry = get(key)
      return 'use_network' unless entry

      case @strategy
      when 'cache-first'
        entry.source == 'offline' ? 'use_cache_revalidate' : 'use_cache'
      when 'stale-while-revalidate'
        entry.source == 'cache' ? 'use_cache' : 'use_cache_revalidate'
      else
        'use_network'
      end
    end

    # Number of cached entries.
    def size
      @mutex.synchronize { @entries.size }
    end
  end
end
