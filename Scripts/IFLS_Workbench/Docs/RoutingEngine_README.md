# IFLS Workbench Routing Engine (MVP)

This adds an External Hardware Insert Wizard driven by `Data/IFLS_Workbench/patchbay.json`.

## Features
- Device + Mode (mono/stereo) selection
- Suggested HW OUT/HW IN channels from patchbay matrices
- Conflict check vs per-project recall (ProjExtState)
- Apply creates:
  - **tracks** method: Insert+Return tracks with hardware out send and record input set
  - **reainsert** method: adds ReaInsert FX and opens UI (channel dropdowns may need manual selection)
  - **both** method: does both

## Where recall is stored
Project ExtState:
- section: `IFLS_WORKBENCH`
- key: `HW_ROUTING`
