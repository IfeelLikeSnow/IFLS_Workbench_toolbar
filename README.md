# IFLS Workbench Toolbar (ReaPack Repo)

Minimal **IFLS-only** repository for REAPER field recording workflows (PolyWAV / Multichannel), routing + quick mic cleanup.

Enthaltene Scripts (Action List):
- **IFLS Workbench: Slicing Dropdown (auto-categories + fades)**
- **IFLS Workbench: Slice Direct (cursor or time selection)**
- **IFLS Workbench: Toggle Zero-Cross Respect (Slicing)**

- **IFLS Workbench: Explode Fieldrec + Mic FX + Buses**
- **IFLS Workbench: Explode AutoBus Smart + Route (FX/Color/Master)** (standalone, basiert auf DF95)
- **IFLS Workbench: PolyWAV Toolbox (ImGui)** (basiert auf DF95, benötigt ReaImGui)
- **IFLS Workbench: Install helpers** (registriert **ALLE** Scripts + öffnet Toolbar-Customize)

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




## MicFX (neu)

Dieses Repo enthält jetzt auch ein komplettes **MicFX-Pack** (Profile + FXChains + JSFX Meter + ParamMaps), **ohne** dass du das DF95-Repo in REAPER installieren musst.

**Enthaltene MicFX Actions:**
- **IFLS Workbench: MicFX Profile GUI** → wähle Mic-Profil (B1, XM8500, MD400, NTG4+, C2, Geofon, Cortado, CM300, Ether, MCM Telecoil) und setze passende FX auf allen selektierten Tracks (lädt `.fxlist`).
- **IFLS Workbench: Apply MicFX By TrackName v2** → erkennt Mic-Namen im Track-Name und setzt Default-Profil (Gain + ReaEQ + ReaComp + optional ReaFIR/Meter).
- **IFLS Workbench: MicFX ParamApply v3.6** → „LiveAware“ Parameter-Apply anhand Peak/Mapping (nutzt `Data/IFLS Workbench/DF95_ParamMaps_AO_AW.json`).

**Mitgelieferte Assets (werden über ReaPack mitinstalliert):**
- `Scripts/IFLS_Workbench/MicFX/*.fxlist`
- `FXChains/IFLS Workbench/Mic/*.rfxchain`
- `Effects/IFLS Workbench/DF95_Dynamic_Meter_v1.jsfx`
- `Data/IFLS Workbench/DF95_ParamMaps_AO_AW.json`
- `Data/IFLS Workbench/MicFX_Profiles_v3.json`

Tipp: Wenn du bereits Explode Fieldrec nutzt, kannst du MicFX anschließend per Trackname oder GUI mit einem Klick anwenden.


## Tools (neu)

- **IFLS Workbench: Dump All FX Params (EnumInstalledFX, Resume, CSV+NDJSON)**
  - Scannt installierte FX (EnumInstalledFX), instanziert sie auf einem Temp-Track und dump't Parameter.
  - Output liegt unter: `REAPER resource path/Scripts/IFLS_Workbench/_ParamDumps/`
  - Formate: CSV + NDJSON (große Datenmengen friendly)
  - Resume: Fortschritt wird gespeichert, du kannst den Scan später fortsetzen.



## Troubleshooting: Scripts tauchen nicht in der Action List auf?

REAPER lädt neue Scripts nicht immer automatisch als Actions.

1) Starte einmal: **IFLS Workbench: Install helpers (register ALL scripts...)**
2) Alternativ in ReaPack: **Browse packages → Actions… → Add/Remove scripts…**
