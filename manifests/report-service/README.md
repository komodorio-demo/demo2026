# Report Service Manifests

## Issue Fixed

This directory contains the Kubernetes manifests for the report-service application.

### Problem
The report-service was experiencing severe per-tenant performance degradation:
- Customer `0d0136b9-0dd9-40ca-ac9e-85aaac34451f` had 880ms response time vs 13ms cohort average (~67x slower)
- SQL query was fetching all 50,000+ rows without pagination
- Database query took 136ms + 360ms JSON serialization overhead

### Root Cause
The SQL query in the `/reports/<customer_id>/events` endpoint was missing a `LIMIT` clause:
```sql
SELECT id, customer_id, event_type, payload, created_at 
FROM events WHERE customer_id = %s 
ORDER BY created_at DESC
```

### Solution
Added `LIMIT 100` to the SQL query to paginate results:
```sql
SELECT id, customer_id, event_type, payload, created_at 
FROM events WHERE customer_id = %s 
ORDER BY created_at DESC LIMIT 100
```

### Impact
- Reduces response time from 880ms to ~13ms for high-volume customers
- Prevents database and serialization overhead for large result sets
- Ensures consistent performance across all tenants

### History
This fix was previously applied manually on:
- 2026-06-16 15:46 UTC
- 2026-06-17 02:36 UTC
- 2026-06-17 09:50 UTC
- 2026-07-07 17:47 UTC

But was never committed to Git, causing configuration drift after namespace recreations.

## Files
- `configmap.yaml` - Contains the Python Flask application code with the fixed SQL query

## Deployment
These manifests should be applied during namespace setup to ensure the fix persists across recreations.
