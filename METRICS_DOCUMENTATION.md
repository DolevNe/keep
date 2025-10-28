# Alert Processing Metrics

## New Metric: `keep_alert_db_insert_duration_seconds`

**Type:** Histogram

**Description:** Tracks the time from when an alert is consumed from the Redis queue (or submitted via API) until it's successfully inserted into the database.

### What it Measures

This metric captures the **end-to-end latency** for alert persistence:
- Start: When `process_event()` begins execution (Redis dequeue or API submission)
- End: After `session.commit()` completes in `__save_to_db()`

### Buckets

The histogram uses the following buckets (in seconds):
- `0.01` - 10ms
- `0.05` - 50ms
- `0.1` - 100ms
- `0.25` - 250ms
- `0.5` - 500ms
- `1.0` - 1 second
- `2.5` - 2.5 seconds
- `5.0` - 5 seconds
- `10.0` - 10 seconds

### Usage

This metric helps you:

1. **Monitor alert ingestion performance** at scale
2. **Identify processing bottlenecks** when latency increases
3. **Track improvements** after optimizations (e.g., batching)
4. **Set SLA targets** for alert delivery time

### Example Prometheus Queries

**Average DB insert time (last 5 minutes):**
```promql
rate(keep_alert_db_insert_duration_seconds_sum[5m]) / 
rate(keep_alert_db_insert_duration_seconds_count[5m])
```

**95th percentile insert time:**
```promql
histogram_quantile(0.95, 
  rate(keep_alert_db_insert_duration_seconds_bucket[5m])
)
```

**Alerts taking > 1 second to insert:**
```promql
rate(keep_alert_db_insert_duration_seconds_bucket{le="1.0"}[5m])
```

**Throughput (alerts/sec):**
```promql
rate(keep_alert_db_insert_duration_seconds_count[1m])
```

### Expected Values

With the batching optimizations in place:

| Scenario | Expected Latency | Notes |
|----------|------------------|-------|
| Single alert | 50-100ms | Includes all processing steps |
| Batch (10 alerts) | 100-250ms | Shared transaction overhead |
| Batch (50 alerts) | 200-500ms | Optimal batch size |
| High load (15k/min) | 200-1000ms | With proper connection pool |

### Troubleshooting

**High latency (>2s per alert):**
- Check database connection pool exhaustion
- Review `DATABASE_POOL_SIZE` and `DATABASE_MAX_OVERFLOW`
- Look for long-running transactions or locks
- Check if enrichment rules are slow

**Increasing latency over time:**
- Database may need indexing optimization
- Check for growing table sizes without proper cleanup
- Monitor database disk I/O and CPU

**Spiky latency:**
- May indicate batch size variability
- Check ARQ worker concurrency settings
- Review deduplication rule complexity

## Related Metrics

- `keep_events_in_total` - Total alerts received
- `keep_events_processed_total` - Total alerts successfully processed
- `keep_processing_time_seconds` - Overall processing time (includes workflows, notifications)
- `keep_events_error_total` - Failed alert processing attempts

## Implementation Details

The metric is recorded in `keep/api/tasks/process_event_task.py`:

```python
# After session.commit() completes
if start_time and saved_alerts:
    db_insert_duration = time.time() - start_time
    for _ in saved_alerts:
        alert_db_insert_duration.observe(db_insert_duration)
```

Each alert in the batch gets the same duration value, representing the total time to process and persist the entire batch. This is intentional, as batching means alerts share processing overhead.

