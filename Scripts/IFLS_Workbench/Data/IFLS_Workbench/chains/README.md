# IFLS Workbench Chains

Files:
- `chain_presets.json` (combined)
- `use_cases.json`
- `presets.json`

Concept:
- A Use-Case groups one or more Presets.
- A Preset is an ordered list of steps with `role` + optional `device_id` + `knob_hints`.

`knob_hints`:
- Percent values 0..100
- UI can display as clock via pct_to_clock() (see Chain Builder Wizard).


## Reaper FX after hardware
Presets may include `reaper_fx_chain`: an ordered list of FX (VST/JSFX/ReaPlugs) to insert **after** ReaInsert/hardware return.
Each entry has `fx_name` and a `params` map (human-readable).

## V40: Pre/Post VST chains (no Rea* FX)
Presets may include:
- `pre_fx_chain`: FX to place **before** ReaInsert / hardware send
- `post_fx_chain`: FX to place **after** hardware return

Each FX entry includes:
- `fx_name`, `fx_ident`, `format`, `vendor`
- `params` (human-readable starting points)

Pedal steps include:
- `knob_hints_clock` and `pedal_settings_de`

## V43: Hardware Parallel + Pedal FX Loops
Presets may include:
- `hardware_parallel`: parallel hardware routing (e.g. Sonicake Portal Loop A/Loop B).
- Step-level `fx_loop`: pedal internal FX send/return insert point with `insert_steps`.

Wizard displays Loop A/B and nested fx_loop chains.
