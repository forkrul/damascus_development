# PRD 001: Widget cache

**Status:** Approved (forge)
**Sequence:** 001

## Requirements

### Functional
- The cache stores widgets by key and returns them on demand.

### Non-Functional
- Warm lookups complete in under a millisecond.

## Entities

| Name | Description | Key fields |
|------|-------------|------------|
| Widget | A cached item | key, value, expires_at |

## Approach

An in-process map with TTL bookkeeping, wrapped in a small API.

## Structure

```
src/cache.py
tests/test_cache.py
```

## Operations

| Operation | Input | Output | Notes |
|-----------|-------|--------|-------|
| get | key | widget or none | |
| put | key, widget, ttl | — | |

## Norms

- TDD throughout; small pure functions.

## Safeguards

- Must-not: unbounded memory growth.
- Failure modes considered: clock skew on expiry checks.

## Assumptions (all confirmed before anvil)

- (none remaining)
