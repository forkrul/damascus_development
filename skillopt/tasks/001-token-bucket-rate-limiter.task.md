split: train
---
We need a rate limiter for our HTTP API. Token bucket, tracked per client
id, with configurable capacity and refill rate, and a way for callers to
know how long to wait before retrying when they are limited.
