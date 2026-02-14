# IFLSWB Smart Slicing Upgrade PatchKit

Installs a new one-click Smart Slicing that:
- pre-analyzes onset start points (peak scan via `GetMediaItemTake_Peaks`)
- computes slice ends via peak-based silence (tail) detection (last slice runs until “silence”)
- then splits/trims (slice lengths match the real sound)

## Install (PowerShell)

```powershell
$zip  = "C:\Users\ifeel\Downloads\IFLSWB_SmartSlicing_Upgrade_PatchKit.zip"
$dest = "C:\Users\ifeel\Downloads\IFLSWB_SmartSlicing_Upgrade_PatchKit"
New-Item -ItemType Directory -Force $dest | Out-Null
Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$dest\tools\Apply-IFLSWB-SmartSlicing-Upgrade.ps1" `
  -RepoRoot "C:\Users\ifeel\Documents\GitHub\IFLS_Workbench_toolbar"
```

## Push to GitHub

```powershell
cd "C:\Users\ifeel\Documents\GitHub\IFLS_Workbench_toolbar"
git add -A
git commit -m "Smart slicing: pre-analyze onsets + peak tail detection"
git fetch origin
git pull --rebase origin main
git push origin main
```

If you previously got “rejected (fetch first)”, the `git pull --rebase` line is the clean fix.
