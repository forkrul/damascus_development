split: val
---
We need an in-memory cache library with per-entry TTL expiry, a max-size
bound with LRU eviction, and hooks so the host app can record hit/miss
metrics.
