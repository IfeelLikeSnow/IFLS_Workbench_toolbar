# V43: Sonicake Portal A/B + Pedal FX loops (Attack Decay, Deluxe Memory Boy)

Generated: 2026-02-04T15:26:50Z

## Added to schema (v1.4)
- `hardware_parallel` at preset level:
  - device: sonicake_portal
  - loopA.steps, loopB.steps
- `fx_loop` at step level:
  - type: send_return
  - insert_steps: nested chain inside the pedal

## Wizard changes
- Shows Hardware Parallel (Portal) with Loop A/Loop B step lists and mix hints.
- Shows Pedal FX Loop (Send/Return) for any step that includes `fx_loop`.

## New presets
- preset_portal_metallic_perc_ab
- preset_attack_decay_fxloop_grains
- preset_memory_boy_fxloop_living_delay
