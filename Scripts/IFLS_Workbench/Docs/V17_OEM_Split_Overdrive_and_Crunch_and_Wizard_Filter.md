# V17 OEM Split: Overdrive + Crunch + Wizard Filter

## New panel-verified OEM profiles (from user images)
- `oem_mini_overdrive_3knob_green` — OEM Mini Vintage Overdrive (Green), 3 knobs: DRIVE/TONE/VOLUME
- `oem_mini_crunch_distortion_3knob_blue` — OEM Mini Crunch Distortion (Blue), 3 knobs: VOLUME/GAIN/TONE

Both include:
- `controls_verified_by_image=true`
- `meta.panel_verified=true` @ 2026-02-01T21:35:15Z

## Existing profiles
Existing "Vintage Overdrive" / "Crunch Distortion" profiles are left intact but marked:
- `meta.variant_may_differ=true`
- `variant_notes_de` warns to prefer the OEM panel profiles for the user's units.

## Chain Builder Wizard
Added checkbox:
- **Only panel-verified devices**
When enabled, role suggestions filter out devices without `controls_verified_by_image` or `meta.panel_verified`.

Generated at: 2026-02-01T21:35:15Z
