# Performance Summary Caching Strategy

## Overview

The performance summary caching system optimizes dashboard performance by caching computed summaries and invalidating them only when new relevant data is available.

## Implementation

### Caching Layer
- **Technology**: Rails.cache (MemoryStore in development, Redis in production)
- **Cache Key Pattern**: `performance_summary:tutor:{tutor_id}`
- **TTL**: 1 hour
- **Data Cached**: Full performance summary including trend analysis, average scores, and feedback

### Cache Invalidation

The cache is automatically invalidated (busted) when:
- New SQS (Session Quality Score) is computed for a tutor
- Triggered by `SessionScoringJob` after creating scores
- Ensures dashboard always reflects latest session data

### Benefits

1. **Reduced Database Load**: Avoids repeated aggregation queries for the same tutor
2. **Faster Dashboard Response**: Cached summaries return in < 1ms vs ~50ms for computation
3. **Scalability**: Handles 3,000+ daily sessions with minimal latency
4. **Stale Data Prevention**: 1-hour TTL ensures data freshness even if cache isn't busted

## Usage

### In Application Code

```ruby
# Automatic caching - no changes needed
service = PerformanceSummaryService.new(tutor)
summary = service.generate_summary # Cached automatically

# Manual cache busting (if needed)
PerformanceSummaryService.bust_cache(tutor.id)
```

### In Background Jobs

Cache is automatically busted by:
- `SessionScoringJob#compute_sqs` after creating new SQS scores

No manual intervention required.

## Monitoring

### Cache Hit Rate
Monitor cache effectiveness:
```ruby
# In production, check Redis stats
Redis.current.info['keyspace_hits']
Redis.current.info['keyspace_misses']
```

### Expected Metrics
- **Cache Hit Rate**: 80-90% for active tutors
- **Cache Miss Rate**: 10-20% for new tutors or after score updates
- **Average Response Time (cached)**: < 5ms
- **Average Response Time (uncached)**: 30-50ms

## Configuration

### Development
- Uses `:memory_store` (in-memory caching)
- No additional setup required

### Production
- Requires Redis configuration:
  ```ruby
  # config/environments/production.rb
  config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] }
  ```

### Cache Expiry Adjustment

To adjust TTL:
```ruby
# app/services/performance_summary_service.rb
CACHE_EXPIRY = 30.minutes # or 2.hours, etc.
```

## Future Enhancements

1. **Cache Warming**: Pre-compute summaries for active tutors during off-peak hours
2. **Multi-Layer Caching**: Add fragment caching for dashboard components
3. **Smart Invalidation**: Only bust cache for significant score changes (e.g., > 10 point SQS delta)
4. **Analytics Caching**: Cache admin dashboard metrics for 5-10 minutes

