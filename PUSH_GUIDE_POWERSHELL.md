# IFLS Workbench Toolbar – ZIP → GitHub Push (PowerShell)

> Ziel-Repo lokal:
`C:\Users\ifeel\Documents\GitHub\IFLS_Workbench_toolbar`
> Remote:
`https://github.com/IfeelLikeSnow/IFLS_Workbench_toolbar`

## 1) ZIP entpacken (Variante B: "Repo komplett ersetzen")

**Wichtig:** `Expand-Archive -Force` überschreibt Dateien, löscht aber NICHT automatisch alte Dateien.
Darum: vorher `git clean -fdx` (nur wenn du sicher bist, dass nichts Wichtiges uncommitted ist).

```powershell
$repo = "C:\Users\ifeel\Documents\GitHub\IFLS_Workbench_toolbar"
$zip  = "C:\Users\ifeel\Downloads\IFLS_Workbench_toolbar_FULL_FIXED_v0.6.0.zip"   # <-- anpassen!

cd $repo

git checkout main
git pull

# Achtung: löscht untracked Dateien/Ordner im Repo!
git clean -fdx

Expand-Archive -Path $zip -DestinationPath $repo -Force
```

## 2) Version prüfen und committen

```powershell
cd $repo
git status

# Optional: schnell checken, ob index.xml sauber ist
Select-String -Path ".\index.xml" -Pattern "\.\.\."  # sollte NICHTS finden

git add -A
git commit -m "IFLS Workbench v0.6.0 – toolbar generator + fixes"
git push origin main
```

## 3) ReaPack URL

Danach in REAPER/ReaPack:
`https://raw.githubusercontent.com/IfeelLikeSnow/IFLS_Workbench_toolbar/main/index.xml`
