# Patchbay PX3000 – Wiring + Front Patch Cheatsheet (v1 fixed)

Generated: 2026-02-09T07:00:37.641724Z

## Sources
- Your PDF set (A4) indicates channels 3–8 are **HALF-NORMAL** (always-on synth bank) and outboard channels are **THRU**.
- Behringer PX3000 documentation confirms three modes: NORMAL, HALF NORMAL, THRU. In HALF NORMAL, inserting a plug in the **top/front** splits (tap) without breaking the rear-normal; inserting in the **bottom/front** breaks/overrides. citeturn0search5turn0search3turn0search1

## Rear wiring (summary)
This package’s matrix represents rear wiring for a PX3000 feeding a PreSonus Studio 1824c.

### Synth bank (HALF-NORMAL recommendation)
- MicroFreak → Interface IN 3
- Neutron → Interface IN 4
- PSS-580 **L→IN5 / R→IN6** (fixed)
- FB-01 L/R → Interface IN 7/8

## Front patch logic (HALF-NORMAL)
### Tap without breaking the default (parallel pick-off)
- Patch **TOP/front** to wherever you want the tap signal.
- Default rear TOP→BOTTOM stays connected (signal still arrives at interface).

### Override / insert processing (break the default)
- Patch **BOTTOM/front** to inject return signal.
- This breaks rear TOP→BOTTOM and replaces what reaches the destination.

## Insert recipe (stereo) – “S / Rin / Rout”
1) **TOP S(L/R)** → **BOTTOM Rin(L/R)**  (send synth to rack/FX chain)
2) **TOP Rout(L/R)** → **BOTTOM S(L/R)** (return from rack replaces default path)

## Data exports
- `exports/patchbay_px3000.json` – parsed mapping (inputs/outputs and patchbay channels)
- `exports/patchbay_px3000.schema.json` – JSON schema

## Known fixes applied
- Corrected **PSS-580 L** mapping in the stereo matrix:
  - was incorrectly marked as **Input 8**
  - now: **PSS-580 L → Input 6** (matches your PDF v1_6 wiring)
