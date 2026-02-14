param(
  [Parameter(Mandatory=$true)][string]$RepoRoot
)

$ErrorActionPreference = "Stop"

function Ok($m){ Write-Host $m -ForegroundColor Green }
function Info($m){ Write-Host $m -ForegroundColor Cyan }
function Warn($m){ Write-Host $m -ForegroundColor Yellow }

$repo = Resolve-Path $RepoRoot

$target = Join-Path $repo "Scripts\IFLS_Workbench\Slicing\IFLS_Workbench_Slice_Smart_PrintBus_Then_Slice.lua"
$legacy = Join-Path $repo "Scripts\IFLS_Workbench\Slicing\IFLS_Workbench_Slice_Smart_PrintBus_Then_Slice.legacy.lua"

$src = Join-Path $PSScriptRoot "..\Scripts\IFLS_Workbench\Slicing\IFLS_Workbench_Slice_Smart_PrintBus_Then_Slice.lua"
$src = Resolve-Path $src

if (-not (Test-Path $target)) { throw "Target script not found: $target" }

if (-not (Test-Path $legacy)) {
  Copy-Item $target $legacy -Force
  Ok "Legacy backup created:`n$legacy"
} else {
  Warn "Legacy already exists:`n$legacy"
}

Copy-Item $src $target -Force
Ok "Upgraded smart slicer installed:`n$target"

Info "Recommended:"
Info "  cd `"$repo`""
Info "  reapack-index --no-config --check --strict --ignore .iflswb_reapack_backup_ ."
Info "  reapack-index --no-config --scan  --strict --ignore .iflswb_reapack_backup_ --output index.xml --commit ."
