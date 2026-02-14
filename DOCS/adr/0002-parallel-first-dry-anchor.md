# ADR-0002: Parallel-first routing with Dry anchor in REAPER

Date: 2026-02-04
Status: Accepted

## Context
IDM sound design benefits from destructive processing while preserving transient integrity. Parallel hardware (Portal A/B) and DAW dry anchors enable mix-safe workflows.

## Decision
Prefer parallel routing by default: keep dry signal in REAPER; treat hardware returns as wet/character layers.

## Consequences
- Presets include routing mode and mix hints.
- Wizard surfaces dry strategy and phase warnings.

## Alternatives considered
- Serial-only insert chains (rejected: less controllable, more mix risk).
