# ADR-001: Modular Flutter client

## Status

Accepted

## Context

One person uses Windows and Android clients. Business rules are substantial, but independent service scaling is not required.

## Decision

Use one feature-based Flutter modular monolith. Keep domain and sync engine platform-neutral inside the client package.

## Trade-offs

- Positive: one implementation, simple debugging, offline operation.
- Negative: native background behavior still needs thin platform adapters.
- Mitigation: platform services trigger the same coordinator contract.
