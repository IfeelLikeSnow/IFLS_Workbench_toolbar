param(
  [Parameter(Mandatory=$true)][string]$Zip,
  [string]$ResourcePath = "$env:APPDATA\REAPER"
)

function Die($msg) { Write-Host $msg -ForegroundColor Red; exit 1 }

if (!(Test-Path $Zip)) { Die "ZIP not found: $Zip" }
if (!(Test-Path $ResourcePath)) { Die "ResourcePath not found: $ResourcePath" }

$tmp = Join-Path $env:TEMP "iflswb_install_unpack"
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory -Path $tmp | Out-Null

Write-Host "Unpacking to $tmp..."
Expand-Archive -Force $Zip $tmp

# Detect top folder that contains Scripts/Effects/FXChains/Data
$top = Get-ChildItem $tmp | Where-Object { $_.PSIsContainer } | Select-Object -First 1
if (!$top) { Die "No folder found inside ZIP." }

$probe = $top.FullName
if (Test-Path (Join-Path $probe "IFLS_Workbench_toolbar")) {
  $probe = Join-Path $probe "IFLS_Workbench_toolbar"
}

Write-Host "Installing to ResourcePath: $ResourcePath"
$folders = @("Scripts","Effects","FXChains","Data","MenuSets","DOCS")
foreach ($n in $folders) {
  $src = Join-Path $probe $n
  if (Test-Path $src) {
    $dst = Join-Path $ResourcePath $n
    Write-Host "  -> $n"
    robocopy $src $dst /E /NFL /NDL /NJH /NJS /NP | Out-Null
  }
}

Write-Host ""
Write-Host "Done. Restart REAPER." -ForegroundColor Green
