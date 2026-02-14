# V39 Exact FX selection from installed sync + expanded pedal settings

Timestamp: 2026-02-03T16:26:11Z

## What changed
- Chains schema bumped to v1.2.
- `reaper_fx_chain` now uses exact installed FX names from:
  IFLS_ALWAYS_LATEST_v11_7_20260201_090621_SINGLE_TRUTH_WITH_INSTALLED_SYNC.csv
  and adds `fx_ident` so future automation can insert the right FX reliably.
- Each pedal step with `knob_hints` now includes:
  - `knob_hints_clock` (pct + clock)
  - `pedal_settings_de` (human-readable summary)

## Notes
- If a FX cannot be matched, entry is kept as-is.
