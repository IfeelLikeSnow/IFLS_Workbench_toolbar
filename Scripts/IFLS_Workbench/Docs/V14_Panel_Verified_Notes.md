# V14 Panel-Verified Lock

This release marks selected OEM/mini pedals as **panel-verified** based on user-provided images.
Updated devices:
- Amuzik Ocean Verb
- Mini Vintage Overdrive (3-knob, no toggles)
- Dolamo D-10 Mixing Boost
- M-VAVE Mini Universe
- M-VAVE Elemental

Changes:
- `controls[]` rewritten to match the front panel exactly
- `controls_verified_by_image=true`
- `meta.panel_verified=true` + timestamp
- Added/updated `variant_notes_de`
- Set `controls_contextual=true` where PARAM knobs depend on TYPE/algorithm

Next:
- Extend this to remaining OEM minis (tremolo/crunch/ABY) when their profile ids are confirmed in the repo.
