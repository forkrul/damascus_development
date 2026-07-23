# Spec: Widget cache

## User Stories

- US1: As a service, I fetch widgets quickly without recomputing them.

## Functional Requirements

- FR-001: The cache returns a stored widget by key. (US1)
- FR-002: An entry is never returned after its TTL has elapsed. (US1)

## Success Criteria

- SC-001: p99 warm lookup under 1 ms, verified by the benchmark test.
- SC-002: Expired entries are never returned, verified by unit test.
