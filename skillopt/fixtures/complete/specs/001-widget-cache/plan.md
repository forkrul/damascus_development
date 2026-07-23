# Plan: Widget cache

## Requirements

Fast keyed lookup with TTL expiry (see spec.md FR-001, FR-002).

## Entities

Widget (key, value, expires_at).

## Approach

In-process map plus expiry bookkeeping.

## Structure

src/cache.py with tests in tests/test_cache.py.

## Operations

get(key), put(key, widget, ttl).

## Norms

TDD, small pure functions.

## Safeguards

Bounded memory; expiry uses injected clock.

## Phases

1. Cache skeleton with get/put (T001)
2. TTL expiry (T002)
