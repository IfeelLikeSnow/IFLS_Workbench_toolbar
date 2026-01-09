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