# Device list integration strategy

## Current state
- `SourceData/Geraeteliste.xlsx` is the source of truth for gear inventory.
- GitHub Action generates `Data/IFLS_Workbench/gear.json`.

## Recommended: add stable IDs + patchbay mapping
Add two columns to the Excel (and therefore to gear.json):
- `id` (stable slug) OR keep generator's slug but store it back to Excel for stability
- `patchbay_name` (string): exact name as used in Patchbay matrix headers.

Why:
- Patchbay headers often contain shorthand or suffixes; gear list may be full model name.
- A dedicated mapping avoids brittle fuzzy matching.

## Optional: include templates per device
Repo additions:
- `FXChains/IFLS/<id>.RfxChain` (optional)
- `TrackTemplates/IFLS/<id>.RTrackTemplate` (optional)

Wizard behavior:
- If an FXChain exists for selected device -> load it automatically.
- If a TrackTemplate exists -> build a complete insert+return+bus structure.

## Normalization & validation in CI
Add a CI step:
- ensure every patchbay device header has a corresponding gear entry (by patchbay_name)
- ensure every gear entry mapped to patchbay has valid OUT+IN marks

This keeps data + automation in sync.
