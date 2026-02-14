# Patchbay (PX3000) – Workbench Integration

Generated: 2026-02-09T07:03:53.463284Z

This folder integrates the PX3000 patchbay wiring package into IFLS Workbench.

## Data
- `../Data/patchbay_px3000.json` – parsed matrix mapping (channels, inputs, outputs)
- `../Schemas/patchbay_px3000.schema.json` – JSON schema

## Docs
- `PATCHBAY_PX3000_CHEATSHEET.md` – half-normal tap/override and insert recipes

## Assets
- Original PDFs and Excel sheets from the package are archived in `../Assets/` for reference.

## Intended usage in Workbench
- Viewer: Patchbay table can load `patchbay_px3000.json`
- Routing engine: can reference channel numbers for inserts / conflict checks.
