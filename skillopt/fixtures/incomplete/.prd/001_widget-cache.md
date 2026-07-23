# PRD 001: Widget cache

**Status:** Draft (forge)

## Requirements

### Functional
- The cache stores widgets by key.

## Entities

| Name | Description | Key fields |
|------|-------------|------------|
| Widget | A cached item | key, value |

## Approach

An in-process map. [ASSUMED — confirm before anvil]

## Structure

```
src/cache.py
```

## Operations

| Operation | Input | Output | Notes |
|-----------|-------|--------|-------|
| get | key | widget or none | |
