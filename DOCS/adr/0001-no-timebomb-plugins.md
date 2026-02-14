# ADR-0001: Disallow time-limited/muting plugins in shipped presets

Date: 2026-02-04
Status: Accepted

## Context
Presets must be recallable and stable across time. Trial/time-bomb plugins can mute or interrupt audio, breaking sessions and trust.

## Decision
Shipped presets must not depend on time-limited/muting plugins. Known offenders are placed on a denylist (e.g. Melda in trial mode).

## Consequences
- Some chains must be rewritten using stable alternatives.
- Preset QA will check plugin vendor/name against allow/deny lists.

## Alternatives considered
- Allow trials with warnings (rejected: still breaks recall and live use).
