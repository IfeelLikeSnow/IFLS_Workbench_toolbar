# IFLS Workbench Policy

## Plugin policy
### Allowed (default)
- Stable plugins without time limits or audio interruptions
- Freeware / open source / paid-licensed plugins
- JSFX (preferred when possible for determinism)

### Disallowed
- Trial plugins that mute/interrupt audio after time
- Plugins with unreliable state recall or nondeterministic behavior (unless explicitly marked & seeded)
- Any preset that depends on disallowed plugins must be rejected or rewritten.

## Content policy
Every shipped preset must include:
- `use_case_id` + clear intent (what source → what outcome)
- Routing mode: Insert / Portal A/B / Pedal FX loop / Parallel send
- Safety class: `mix_ready` or `resample_only`
- Recall: patch instructions + knob clocks (for hardware)
- Risk notes: feedback / phase / level hazards

## Deprecation
- Never delete user-facing preset IDs without a migration note.
- Mark deprecated presets and provide replacements.
