# V34 Research Workflow (resolve tag=?)

Timestamp: 2026-02-03T04:35:29Z

## Goal
Bring every effect pedal profile to at least WV (web-verified), ideally VV/PV/MR.

## Inputs
- Reports/V34_unknown_pedals_tasklist.xlsx (task list)
- Each profile JSON path is listed per device.

## Process (recommended)
1. Start with manuals (PDF) if available -> mark `meta.manual_sources[]` + set `meta.manual_verified=true` (MR).
2. If no manual: verify from reliable listings (Reverb/eBay/manufacturer) -> add `meta.web_sources[]` (WV).
3. If a demo explains hidden functions/mappings: add transcript evidence -> `meta.video_sources[]` + `meta.video_verified=true` (VV).
4. If you have panel photos: set PV and lock down all labels.

## Acceptance criteria for "complete"
- Every control has `function_de` or `notes_de`.
- Power specs present in `controls_contextual.specs`.
- At least one source field populated (manual/video/web).
