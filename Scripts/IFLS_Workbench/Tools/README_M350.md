# M350 Scripts (IFLS Workbench)

## IFLS_M350_Wizard_Create_Insert_or_Aux.lua
Menu-driven wizard that can create:
- **Insert template**: `M350 Insert (Audio)` track with **ReaInsert** + linked `M350 Control` MIDI track
- **Aux template**: `M350 AUX Return` (ReaInsert) + `M350 AUX Send` placeholder + linked `M350 Control`
- **MIDI control only**: just the `M350 Control` track

### What it sets up
- MIDI HW output via Track State Chunk (`MIDIHWOUT`) to a device name containing **"mioXM DIN 4"** (editable)
- Forces M350 MIDI channel (default **16**)
- Creates a tiny MIDI item at the edit cursor with **Program Change**
- Prepares **CC automation lanes** via ReaControlMIDI (best-effort based on parameter names)
- Optional marker/region at cursor using preset name map

### Audio I/O
The wizard asks for:
- Hardware **send out pair start** (e.g. 7 means out 7/8)
- Hardware **return in pair start** (e.g. 7 means in 7/8)

ReaInsert hardware routing varies by system; the script will **insert ReaInsert and open its UI** so you can confirm/adjust.

## Toolbar integration (REAPER)
1. `Actions → Show action list`
2. `ReaScript → Load…` and pick the wizard script.
3. Right-click a toolbar → **Customize toolbar…**
4. `Add…` → search the script/action name → add it.


## Pro features (v1.1)
- Wizard remembers last used menu choice and settings via REAPER ExtState (section `IFLS_M350_WIZARD`).
- Preset names can be loaded from JSON: `Scripts/IFLS_Workbench/Workbench/M350/Data/m350_presets.json`.
- New menu item: **Insert: ReaInsert Ping/Latency Setup** (opens ReaInsert and attempts to trigger Ping/Auto-detect; falls back to manual click).


## Ultra-Pro Tools

Script: `IFLS_M350_UltraPro_Tools.lua`

Includes:
- Preset-name JSON editor (writes to `Scripts/IFLS_Workbench/Workbench/M350/Data/m350_presets.json`)
- Auto-create Regions/Markers from MIDI items containing M350 Program Change
- Project Doctor heuristics (mioXM DIN4 multi-send collisions, likely MIDI feedback, likely double-clock FX)

Toolbar: Load via `Actions > Show action list > ReaScript: Load...` then add to toolbar.


## Ultra-Pro Add-ons

- **ImGui Preset Editor:** `IFLS_M350_PresetEditor_ImGui.lua` (requires ReaImGui). Edit `Workbench/M350/Data/m350_presets.json` with a proper list + text fields.
- **Auto-Regions per PC event:** In `IFLS_M350_UltraPro_Tools.lua` choose mode `subregions` (creates regions between PC events) or `submarkers` (marker per PC).
- **mioXM DIN4 loop check:** Optional file `Workbench/MIDINetwork/Data/mioxm_routes.json` lets Project Doctor warn if a route `DIN IN 4 -> DIN OUT 4` exists.
