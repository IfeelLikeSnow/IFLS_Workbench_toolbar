# V31 Mode Matrix: knob positions + apply to Track Notes

Timestamp: 2026-02-03T04:27:16Z

## Upgrades
- Preset hints now include approximate knob positions:
  - Each suggestion outputs an approximate clock value and percent.
- Added "Apply to selected track notes" button:
  - Writes preset hint list into selected track notes (fallback: master track).
  - Includes Append toggle.

Implementation:
- Helper pct_to_clock() maps 0..100% to ~7:00..5:00.
- Uses Reaper API: GetSelectedTrack + GetSetMediaTrackInfo_String(P_NOTES).

