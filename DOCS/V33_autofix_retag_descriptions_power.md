# V33 Auto-fix: retag + fill descriptions + power spec TODOs

Timestamp: 2026-02-03T04:33:51Z

## Changes
- `meta.controls_completeness` normalized for all effect pedals.
- Missing control descriptions filled with GENERIC_MAP + note to verify.
- Power specs:
  - If evidence text mentions power, added defaults `power_v_dc=9`, `polarity=center_negative` with warning to verify.
  - Otherwise added warning "Power-Specs fehlen (To-do)".

Reports:
- Reports/V33_pedal_coverage_report.xlsx
- Reports/V33_pedal_coverage_gaps.csv
