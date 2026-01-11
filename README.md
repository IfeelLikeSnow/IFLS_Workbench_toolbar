# IFLS Workbench Toolbar (ReaPack Repo)

IFLS Workbench: **Fieldrec / PolyWAV / Multi‑mic** Workflow für REAPER (Explode + Auto‑Routing + MicFX + Slicing).

## Enthaltene Actions (Auswahl)

**Explode / PolyWAV**
- **IFLS Workbench: Explode Fieldrec + Mic FX + Buses**
- **IFLS Workbench: PolyWAV Toolbox (ImGui)** *(benötigt ReaImGui)*

**Slicing**
- **IFLS Workbench: Slicing Dropdown (auto-categories + fades)**
- **IFLS Workbench: Slice Direct (cursor or time selection)**
- **IFLS Workbench: Slice Smart (print bus mono/stereo → slice direct)**

**Setup / Tools**
- **IFLS Workbench: Install helpers (register scripts …)**
- **IFLS Workbench: Generate toolbar .ReaperMenu (floating toolbar import file)**
- **IFLS: Diagnostics**
- **IFLS: Cleanup duplicates**

## Installation (ReaPack)

1. **Extensions → ReaPack → Import repositories…**
2. `https://raw.githubusercontent.com/IfeelLikeSnow/IFLS_Workbench_toolbar/main/index.xml`
3. **ReaPack → Synchronize packages**
4. In **Browse packages** nach **IFLS Workbench Toolbar Suite** suchen und installieren.

## Toolbar-Setup (empfohlen)

1. Starte einmal: **IFLS Workbench: Install helpers …**
2. Wähle **Yes**, um eine Toolbar-Datei zu generieren (oder starte später: **Generate toolbar .ReaperMenu**).
3. Import:
   - **Options → Customize toolbars…**
   - oben die gewünschte **Floating toolbar** auswählen
   - **Import…** und die erzeugte Datei aus `REAPER/ResourcePath/MenuSets/` auswählen (z.B. `IFLS_Workbench_TB16.ReaperMenu`)

## Installation (manuell / ZIP)

- ZIP entpacken nach REAPER Resource Path (oder ReaPack verwenden)
- REAPER → **Actions → Show action list…**
- **ReaScript: Load…** → Scripts aus `Scripts/IFLS_Workbench/` laden
- Danach **Install helpers** laufen lassen (registriert alles automatisch)

## Quick Start (Explode → Slice Smart)

1. PolyWAV/Multichannel WAV auf einen Track importieren
2. Item selektieren
3. Action: **Explode Fieldrec + Mic FX + Buses**
4. Cursor/Time selection setzen
5. Action: **Slice Smart (print bus → slice)**

