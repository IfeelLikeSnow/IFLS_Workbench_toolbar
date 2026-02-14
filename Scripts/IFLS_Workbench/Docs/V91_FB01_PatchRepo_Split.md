# V91: FB-01 patch library split

Generated: 2026-02-09T17:34:53.401684Z

## Why
The full FB-01 patch archive was moved out of the main IFLS Workbench repository to reduce repository size and update friction.

## New external repo
Install `IFLS_FB01_PatchLibrary` into:
`REAPER/ResourcePath/Scripts/IFLS_FB01_PatchLibrary`

## Workbench integration
- Default library path is auto-detected.
- Optional override via ExtState:
  - Namespace: `IFLS_FB01`
  - Key: `LIBRARY_PATH`

Hub now offers: "Set FB-01 Patch Library Path".
