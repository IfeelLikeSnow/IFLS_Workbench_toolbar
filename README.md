<<<<<<< HEAD
# IFLS_Workbench_toolbar

Minimal REAPER Workbench Toolbar Repo für **Field Recordings → automatisch Samples bauen (später)**.

## Hauptfeature (jetzt):
**IFLSWB: Explode + MicFX + AutoBuses (non-destructive)**

Workflow:
1. Importiere WAV oder Polywave (z.B. Zoom F6) auf einen Track.
2. Selektiere das Item.
3. Trigger das Script:
   `Scripts/IFLSWB_Explode_Workbench.lua`

Ergebnis:
- Polywave/Multi-Channel wird **non-destructive** auf Tracks darunter gesplittet (je Channel ein Mono-Item).
- Mic-FX (ReaEQ-Startkurven) wird **direkt** auf jedem Mic-Track eingefügt.
- Routing wird gebaut:
  **Mic Tracks → IFLSWB FX Bus → IFLSWB Coloring Bus → IFLSWB Master Bus**

## Installation in REAPER
1. REAPER: `Actions → Show action list…`
2. `ReaScript: Load…`
3. Datei auswählen: `Scripts/IFLSWB_Explode_Workbench.lua`
4. Optional: In Toolbar legen.

## Anpassung
- Mic-Profile: `Scripts/IFLSWB_MicProfiles.lua`
- Bus-Namen & Verhalten: `Scripts/IFLSWB_Explode_Workbench.lua` (CFG-Block)

## Notes
- Default ist **non-destructive** (keine Render/Glue Actions).
- Späteres Slicing/Commit kann als separates Script ergänzt werden.
=======
# IFLS Workbench Toolbar (ReaPack)

This repository is meant to be installed **as its own ReaPack repository** (no DF95 installation required).

## Install (ReaPack)

1. In REAPER: **Extensions > ReaPack > Import repositories…**
2. Add this URL:

`https://github.com/IfeelLikeSnow/IFLS_Workbench_toolbar/raw/main/index.xml`

Then: **Extensions > ReaPack > Synchronize packages** and install the packages you want.

(If you don’t see new actions immediately, restart REAPER once.)

## First run: generate a toolbar file

After installing the scripts, run:

- **IFLS Workbench: Install / Generate Toolbar file**

It will create:

`REAPER/ResourcePath/MenuSets/IFLS_Workbench.Toolbar.ReaperMenuSet`

Then import it via:

**Options > Customize toolbars… > Import…**

## Scripts included

- **IFLS Workbench: Explode Fieldrec**  
  Explode polywav/multichannel items, create a simple bus chain, and apply mic EQ based on track names.

- **IFLS Workbench: Explode AutoBus + Route**  
  Creates/ensures FX/Coloring/Master busses and routes source tracks through them.

- **IFLS Workbench: PolyWAV Toolbox (ImGui)**  
  ImGui toolbox for PolyWAV/fieldrec workflows (requires ReaImGui).

## Mic profiles

The mic presets live in:

`Scripts/IFLS Workbench/lib/ifls_workbench_mic_profiles.lua`

Edit it to add/adjust profiles.

## Notes on DF95

A couple of scripts in this repository are adapted from a DF95 source snapshot you provided. They have been adjusted to work as a standalone IFLS repository.
>>>>>>> c7aa947 (IFLS Workbench Toolbar)
