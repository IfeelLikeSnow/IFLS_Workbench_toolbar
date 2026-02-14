# V78: FB-01 Archive + Redirect Stubs

Generated: 2026-02-07T21:15:41.191855Z

## What changed
- Moved historical packs into `Workbench/FB01/Archive/Pack_vX/`:
  - Pack_v2, Pack_v3, Pack_v5, Pack_v7
- Recreated `Workbench/FB01/Pack_vX/` folders as **redirect stubs**:
  - Each stub contains:
    - `README.md`
    - `IFLS_FB01_Toolkit.lua` forwarding to the archived pack

## Why
- Keeps the repo tidy without breaking existing REAPER Actions / toolbar buttons / documentation links.
- Provides a stable "current" entry point via `Workbench/FB01/Current/`.

## Notes
- Pack_v8 remains in place (current pack).
