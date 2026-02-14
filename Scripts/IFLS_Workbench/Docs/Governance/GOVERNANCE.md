# Governance

## Roles
- **Maintainer (you)**: final decision, releases, policy enforcement.
- **Contributors**: propose changes via SIP/RFC/PR.

## Decision system
- **SIP**: proposal for product/process changes (features, workflows, policies).
- **RFC**: design exploration for significant technical changes.
- **ADR**: record of decisions made (what/why/tradeoffs).

## When to use what
- Minor preset additions: PR only (must pass checklist).
- Schema/routing/recall changes: RFC + ADR.
- New capability/feature track: SIP (may reference RFC/ADR).

## Review gates (must pass)
- Policy compliance (no time-bomb plugins)
- Recall completeness (patch + knob clocks)
- Safety tagging (mix_ready vs resample_only)
- Backward compatibility or documented migration

## Releases
- Content releases: additive presets/chains (no breaking schema)
- Schema releases: include migration notes + version bump
