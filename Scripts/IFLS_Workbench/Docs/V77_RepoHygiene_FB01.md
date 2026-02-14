# V77 Repo Hygiene: FB-01 "Current" entry points

Generated: 2026-02-07T21:01:33.710100Z

## What changed
- Added `Workbench/FB01/Current/` folder with canonical entry scripts.
- Updated Hub to launch FB-01 from `Current/` instead of a hard Pack path.

## Detected historical packs
Found packs: Pack_v2, Pack_v3, Pack_v5, Pack_v7, Pack_v8

## Why this matters
- Toolbars / actions / docs often hard-link to `Pack_vX/...` scripts.
- Keeping old packs is fine, but you need a stable *current* launch target.
- `Current/` lets you update the underlying pack later without breaking user actions.

## Next recommended steps (optional, V78)
- Move older packs into `Workbench/FB01/Archive/Pack_vX/` **only after** generating redirect stubs, so nothing breaks.
- Add a "Pack Selector" dropdown to the FB-01 Toolkit UI (advanced).
