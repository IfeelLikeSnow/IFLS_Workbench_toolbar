# IFLS_Workbench (ReaPack)

This repository installs **IFLS Workbench** tools (Slicing, MicFX, JSFX, FXChains, menus, icons) via ReaPack.

## ReaPack install (recommended)

1) Install **ReaPack** and restart REAPER.  
2) REAPER → **Extensions → ReaPack → Import repositories…**  
3) Import this `index.xml` (GitHub raw):

```text
https://raw.githubusercontent.com/IfeelLikeSnow/IFLS_Workbench_toolbar/main/index.xml
```

4) **Synchronize packages**, then install:
- **IFLS_Workbench (Scripts)**
- **IFLS_Workbench (JSFX)**
- **IFLS_Workbench (Data)**
- **IFLS_Workbench (Assets → FXChains/MenuSets)**

### First run (one-time setup inside REAPER)

Open the Action List and run these actions once:
- `IFLS_Workbench: Install helpers (register scripts + open Action List / generate toolbar file)`
- `IFLS_Workbench: Install assets from Data/_assets to FXChains/MenuSets`
- `IFLS_Workbench: Install toolbar icons to Data/toolbar_icons`

This copies FXChains/MenuSets + icons into REAPER’s native folders.

## Important: folder layout (fixed)

ReaPack installs into these **single top folders** (no nested Scripts/Scripts anymore):
- `<ResourcePath>/Scripts/IFLS_Workbench/…`
- `<ResourcePath>/Effects/IFLS_Workbench/…` (JSFX)
- `<ResourcePath>/Data/IFLS_Workbench/…`

If you previously installed older builds, remove legacy folders:
- `<ResourcePath>/Scripts/IFLS Workbench Toolbar/`
- `<ResourcePath>/Scripts/IFLS Workbench/`
- `<ResourcePath>/Scripts/IFLS/`

See `DOCS/INSTALL_AND_TEST.md` for a full cleanup + test checklist.
