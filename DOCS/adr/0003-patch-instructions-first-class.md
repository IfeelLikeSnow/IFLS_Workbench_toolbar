# ADR-0003: Patch instructions are first-class preset data

Date: 2026-02-04
Status: Accepted

## Context
Hybrid setups fail when cables/routing are not reproducible.

## Decision
Presets that involve hardware must include patch instructions in data (`patch_instructions_de`) and knob clocks.

## Consequences
- Wizard can copy/show patch instructions.
- Presets without patch/knob clocks fail review.

## Alternatives considered
- Keep patch notes only in docs (rejected: not portable; easy to miss).
