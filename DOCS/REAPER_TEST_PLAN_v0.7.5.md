# REAPER Test Plan (v0.7.5)

## 1) Prereqs
- Install **ReaPack**
- Install **SWS Extension** (for Xenakios/SWS actions)
- Restart REAPER after installing extensions

## 2) Install the repo via ReaPack
ReaPack → **Extensions → ReaPack → Import repositories…**

Paste:
```
https://raw.githubusercontent.com/<YOUR_USER>/<YOUR_REPO>/main/index.xml
```

Then:
ReaPack → **Browse packages** → install **IFLS Workbench (bundle)**.

## 3) Import Toolbar + Icons
1. Put the `.ReaperMenu` file in:
   `<resource>/MenuSets/`
2. In REAPER:
   **Options → Customize toolbars…**
   - choose a toolbar (e.g. Toolbar 16)
   - **Import toolbar…** → select `MenuSets/IFLS_Workbench_TB16.ReaperMenu`
3. Ensure icons exist at:
   `<resource>/Data/toolbar_icons/*.png`

## 4) Validate Xenakios/SWS: Split items at transients
### Quick manual check
- Select an item with clear transients (kick/snare loop)
- Run action:
  `Xenakios/SWS: Split items at transients`
- Expected: item splits into multiple items

### Automated check (this repo)
Run:
`IFLS_Workbench_Test_SWS_Split_Items_At_Transients.lua`

If it reports **0 new items**, adjust the SWS transient settings (see script output).

## 5) Validate Smart Slice (Print bus → Slice → Close gaps)
- Select the source track (bus/group is fine)
- Run:
  `IFLS_Workbench_Slice_Smart_PrintBus_Then_Slice.lua`
Expected:
- stem track created
- new track **IFLS Slices**
- items are split and gaps closed
- originals muted

## 6) Export tools
- Run:
  `Tools/IFLS_Export_InstalledFX_List.lua`
- Output:
  `<resource>/IFLS_Exports/`
