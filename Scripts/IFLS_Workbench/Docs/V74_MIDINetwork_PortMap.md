# V74 MIDINetwork Port Map Update (mioXM)

Generated: 2026-02-07T20:31:09.648150Z

## New in schema_version 1.1.0
`Workbench/MIDINetwork/Data/midinet_profile.json` now includes a `port_map` block with physical wiring hints.

### Target wiring (as requested)
- MicroFreak → **DIN/TRS** via **mioXM DIN A**
- PSS-580 → **DIN** via **mioXM DIN B**
- FB-01 → **DIN** via **mioXM DIN C**
- EDGE → **USB host #1** on mioXM
- Neutron → **USB host #2** on mioXM

Notes:
- `port_map` is informational for now. Next step (V75) can use it to auto-select MIDI devices in REAPER by name matching.

## Routing/Filter policy reminders
- DAW is the only clock master.
- DAW→OXI: allow clock + transport.
- OXI→devices: block clock/start-stop unless needed.
- SysEx only on dedicated DAW→FB01 and DAW→PSS580 routes.
