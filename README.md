# IFLS Workbench Toolbar (ReaPack Repo)

Minimal **IFLS-only** repository for REAPER field recording workflows (PolyWAV / Multichannel), routing + quick mic cleanup.

Enthaltene Scripts (Action List):
- **IFLS Workbench: Explode Fieldrec + Mic FX + Buses**
- **IFLS Workbench: Explode AutoBus Smart + Route (FX/Color/Master)** (standalone, basiert auf DF95)
- **IFLS Workbench: PolyWAV Toolbox (ImGui)** (basiert auf DF95, benötigt ReaImGui)
- **IFLS Workbench: Install helpers** (registriert Scripts + öffnet Toolbar-Customize)

## Installation (ReaPack)

1. REAPER → **Extensions → ReaPack → Import repositories...**
2. Import-URL (diese Repo-`index.xml`):

```
https://github.com/IfeelLikeSnow/IFLS_Workbench_toolbar/raw/main/index.xml
```

3. **Extensions → ReaPack → Synchronize packages**
4. Im Browser nach **IFLS Workbench** suchen und installieren.

Hinweis: So sieht die Import-URL typischerweise aus (GitHub `.../raw/<branch>/index.xml`).
ReaPack Bedienung: Extensions → ReaPack → Browse packages / Synchronize.

## Installation (manuell / ZIP)

- Repo-ZIP herunterladen, entpacken
- REAPER → **Actions → Show action list…**
- **ReaScript: Load…** → die `.lua` Scripts aus `Scripts/IFLS_Workbench/` laden

## Quick Start (Explode Fieldrec)

1. PolyWAV/Multichannel WAV auf einen Track importieren
2. Item selektieren
3. Action: **IFLS Workbench: Explode Fieldrec + Mic FX + Buses**
4. Ergebnis: Spuren werden erstellt, Routing zu IFLSWB Bussen gebaut, Mic-EQ presetweise gesetzt.

## Abhängigkeiten

- **PolyWAV Toolbox**: benötigt **ReaImGui** (über ReaPack installierbar).
- Sonst: REAPER Standard-Funktionen (Explode-Action wird über bekannte Command-IDs versucht).

## Repo-Entwicklung / Index (optional)

Wenn du später einen „richtigen“ versionsicheren Index generieren willst, nutze **reapack-index** (Ruby gem).
Grundprinzip: Files müssen in Subfolders liegen (nicht im Repo-Root), dann scannt `reapack-index` korrekt.

