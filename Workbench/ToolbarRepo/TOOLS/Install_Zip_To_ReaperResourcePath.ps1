param(
  [Parameter(Mandatory=$true)][string]$Zip,
  [string]$ResourcePath = "$env:APPDATA\REAPER"
)

$ErrorActionPreference = "Stop"

function Resolve-RepoRoot([string]$UnpackedPath) {
  # If the ZIP contains exactly one top-level folder, step into it.
  $top = Get-ChildItem -LiteralPath $UnpackedPath
  if ($top.Count -eq 1 -and $top[0].PSIsContainer) {
    return $top[0].FullName
  }
  return $UnpackedPath
}

function Test-HasLayout([string]$Path) {
  return (Test-Path -LiteralPath (Join-Path $Path "Scripts")) -or
         (Test-Path -LiteralPath (Join-Path $Path "Effects")) -or
         (Test-Path -LiteralPath (Join-Path $Path "Data"))
}

Write-Host "IFLS Workbench - ZIP installer" -ForegroundColor Cyan
Write-Host "ZIP:          $Zip"
Write-Host "ResourcePath: $ResourcePath"

if (!(Test-Path -LiteralPath $Zip)) { throw "ZIP not found: $Zip" }
if (!(Test-Path -LiteralPath $ResourcePath)) { throw "ResourcePath not found: $ResourcePath" }

$tmp = Join-Path $env:TEMP ("ifls_zip_" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp | Out-Null

try {
  Expand-Archive -Force -LiteralPath $Zip -DestinationPath $tmp
  $root = Resolve-RepoRoot $tmp

  if (!(Test-HasLayout $root)) {
    # Some zips are packaged with an extra folder (e.g. IFLS_Workbench_toolbar/...). Try 1 level deeper.
    $sub = Get-ChildItem -LiteralPath $root -Directory | Where-Object { Test-HasLayout $_.FullName } | Select-Object -First 1
    if ($sub) { $root = $sub.FullName }
  }

  if (!(Test-HasLayout $root)) {
    throw "Unrecognized ZIP layout. Expected to find Scripts/Effects/Data near: $root"
  }

  Write-Host "Detected ZIP root: $root" -ForegroundColor Green
  Write-Host ""
  Write-Host "Copying into ResourcePath (merge/overwrite):" -ForegroundColor Yellow

  $folders = @("Scripts","Effects","FXChains","Data","MenuSets","DOCS")
  $installed = New-Object System.Collections.Generic.List[string]

  foreach ($f in $folders) {
    $src = Join-Path $root $f
    if (Test-Path -LiteralPath $src) {
      $dst = Join-Path $ResourcePath $f
      New-Item -ItemType Directory -Force -Path $dst | Out-Null
      Copy-Item -Recurse -Force -LiteralPath (Join-Path $src "*") -Destination $dst
      $installed.Add("$f -> $dst")
    }
  }

  Write-Host ""
  Write-Host "Installed/updated:" -ForegroundColor Green
  $installed | ForEach-Object { Write-Host "  $_" }

  Write-Host ""
  Write-Host "Done. Restart REAPER." -ForegroundColor Green
}
finally {
  Remove-Item -Recurse -Force -LiteralPath $tmp -ErrorAction SilentlyContinue
}
