# IFLS_Workbench JSFX Pack (0.7.8)

This repo ships a small set of DSP-focused JSFX effects.

## Where they install
REAPER loads JSFX from the Resource Path `Effects/` folder (and subfolders).  

This repo installs them to:
- `Effects/IFLS_Workbench/*.jsfx`

## Naming convention
Files are unified as `IFLS_Workbench_*.jsfx`.
In the FX browser they appear under the JS category as:
- `IFLS_Workbench - ...`

## Quick test
1. REAPER: **Options -> Show REAPER resource path...**
2. Confirm you have: `Effects/IFLS_Workbench/IFLS_Workbench_Dynamic_Meter_v1.jsfx`
3. Open FX Browser, search for **"IFLS_Workbench - Dynamic"**
4. Insert to a track and confirm it runs.

## Actions / Toolbar
Scripts are provided in:
- `Scripts/IFLS_Workbench/Tools/JSFX/`

Use:
- `IFLS_Workbench: JSFX Menu (DSP Tools)` to pick and insert any JSFX
- or the dedicated insert scripts for Meter/FFT/Euclid/IDM/Drone.
