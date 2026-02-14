# IFLS_Workbench — Install + Test Checklist

## A) Clean install (recommended)

### 1) Remove old installs (only if you have duplicates)
Close REAPER first.

Delete or rename these folders if they exist:
- `%APPDATA%\REAPER\Scripts\IFLS Workbench Toolbar\`
- `%APPDATA%\REAPER\Scripts\IFLS Workbench\`
- `%APPDATA%\REAPER\Scripts\IFLS\`

Optional PowerShell (run as normal user):

```powershell
$rp = Join-Path $env:APPDATA "REAPER"
$bad = @(
  Join-Path $rp "Scripts\IFLS Workbench Toolbar",
  Join-Path $rp "Scripts\IFLS Workbench",
  Join-Path $rp "Scripts\IFLS"
)
foreach ($p in $bad) {
  if (Test-Path $p) { 
    Write-Host "Removing: $p"
    Remove-Item -Recurse -Force $p
  }
}
```

### 2) ReaPack repo
In REAPER: **Extensions → ReaPack → Manage repositories**  
If you already imported the old repo name, remove it and import the new `index.xml`:

```text
https://raw.githubusercontent.com/IfeelLikeSnow/IFLS_Workbench_toolbar/main/index.xml
```

Then **Synchronize packages** and install the four IFLS_Workbench packages.

## B) Verify installed folders

Open REAPER → Options → Show REAPER resource path…

Check these exist:
- `Scripts\IFLS_Workbench\`
- `Effects\IFLS_Workbench\`
- `Data\IFLS_Workbench\`

## C) One-time setup actions

Open Actions → Show action list…

Run:
1) **IFLS_Workbench: Install helpers**
2) **IFLS_Workbench: Install assets from Data/_assets**
3) **IFLS_Workbench: Install toolbar icons**

Expected results:
- Toolbar icons appear in the toolbar icon picker (filter: `IFLSWB`).
- FXChains appear in the FX Chain browser under `IFLS_Workbench`.
- MenuSets (toolbar files) are generated/imported.

## D) Functional tests

### Slicing
1) Select an audio item.
2) Run: `IFLS_Workbench: Smart Slice (PrintBus → Slice → Fill gaps)`
3) Confirm: items are split and post-fades/zerocross options work.

If you use transients slicing, install **SWS** and run:
- `IFLS_Workbench: Test SWS "Split items at transients"`

### JSFX
1) Add FX on a track.
2) Search for `IFLS Workbench` or `DF95`.
3) Load:
   - Drone/Granular
   - Euclid Slicer
   - IDM Chopper / BusTone
   - Analyzer / Meter
Confirm audio passes and controls move.

### MicFX
1) Run `IFLS_Workbench: MicFX Profile GUI`
2) Apply a profile to a track by name.
3) Confirm chain loads / parameters apply.

## E) Troubleshooting quick checks

- ReaPack: right-click repo → **Synchronize packages**
- Restart REAPER after install.
- If icons missing: run the **Install toolbar icons** action again.
