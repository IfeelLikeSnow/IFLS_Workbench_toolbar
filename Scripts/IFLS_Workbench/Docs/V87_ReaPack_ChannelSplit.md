# V87: ReaPack channel split (Stable + Nightly)

Generated: 2026-02-07T22:06:49.571473Z

## What changed vs V86
- Added a nightly channel index at `nightly/index.xml`.
- CI now generates:
  - stable: `index.xml`
  - nightly: `nightly/index.xml`

## Workflows
- `reapack-nightly-channel.yml`: updates nightly index on push (commits file)
- `reapack-stable-release.yml`: builds stable index on tags (uploads artifact)
- `ci-reapack-validate.yml`: validates both indexes on PRs

## Import URLs
Stable:
`.../raw/<branch>/index.xml`

Nightly:
`.../raw/<branch>/nightly/index.xml`
