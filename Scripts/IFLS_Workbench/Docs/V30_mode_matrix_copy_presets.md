# V30 Mode Matrix: Copy + Preset Hints

Timestamp: 2026-02-03T04:24:42Z

## Mode Matrix channel upgrades
- Copy-to-clipboard:
  - "Copy (filtered)" copies the currently filtered table as TSV.
  - "Copy (all)" copies the whole matrix.
- Preset Hints:
  - Preset dropdown: none / idm_shimmer_pad / lofi_drift_drone / glitch_chop_ice
  - Generates device-aware suggestions for Mini Universe (shimmer/lofi) and Elemental (ice/pattern).
  - "Copy preset hints" copies the hint list to clipboard.
- Toggle to hide/show preset hints.

Notes:
- Uses ReaImGui clipboard API: ImGui_SetClipboardText.
