param(
  [Parameter(Mandatory=$true)]
  [string]$RepoRoot,

  [string]$DefaultVersion = "0.0.1",

  [switch]$RemoveAboutIfNoPandoc
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function Has-Pandoc {
  try { $null = Get-Command pandoc -ErrorAction Stop; return $true } catch { return $false }
}

function New-Backup([string]$repo) {
  $stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $b = Join-Path $repo ".iflswb_reapack_backup_$stamp"
  New-Item -ItemType Directory -Force $b | Out-Null
  return $b
}

function RelPath([string]$base, [string]$full) {
  $base = [IO.Path]::GetFullPath($base).TrimEnd('\') + '\'
  $full = [IO.Path]::GetFullPath($full)
  if ($full.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) { return $full.Substring($base.Length) }
  return $full
}

function Backup-File([string]$repo, [string]$backup, [string]$file) {
  $rel = RelPath $repo $file
  $dst = Join-Path $backup $rel
  New-Item -ItemType Directory -Force (Split-Path $dst -Parent) | Out-Null
  Copy-Item -LiteralPath $file -Destination $dst -Force
}

$AllowedTags = @("description","version","author","about","provides","link","screenshot","changelog","donation","metapackage","noindex","reaper","website","license")
$Allowed = @{}
foreach ($t in $AllowedTags) { $Allowed[$t.ToLowerInvariant()] = $true }

function Is-CommentLine([string]$line, [string]$prefix) {
  $t = $line.TrimStart()
  return $t.StartsWith($prefix)
}

function CommentText([string]$line, [string]$prefix) {
  $t = $line.TrimStart()
  if (-not $t.StartsWith($prefix)) { return $null }
  return $t.Substring($prefix.Length).TrimStart()
}

function Fix-OneFile {
  param(
    [string]$FilePath,
    [string]$DefaultVersion,
    [string]$Prefix,
    [bool]$RemoveAbout
  )

  $lines = Get-Content -LiteralPath $FilePath -Encoding UTF8

  # Header: leading blanks + comment lines with Prefix
  $hEnd = 0
  while ($hEnd -lt $lines.Count) {
    $l = $lines[$hEnd]
    if ($l.Trim().Length -eq 0) { $hEnd++; continue }
    if (Is-CommentLine $l $Prefix) { $hEnd++; continue }
    break
  }

  $header = @()
  $body   = @()
  if ($hEnd -gt 0) {
    $header = $lines[0..($hEnd-1)]
    if ($hEnd -lt $lines.Count) { $body = $lines[$hEnd..($lines.Count-1)] }
  } else {
    $body = $lines
  }

  $changed = $false

  if ($header.Count -eq 0) {
    $header = @(
      "$Prefix @description $(Split-Path $FilePath -Leaf)",
      "$Prefix @version $DefaultVersion",
      ""
    )
    $changed = $true
  }

  # optional: strip @about blocks
  if ($RemoveAbout) {
    $new = New-Object System.Collections.Generic.List[string]
    for ($i=0; $i -lt $header.Count; $i++) {
      $ct = CommentText $header[$i] $Prefix
      if ($ct -ne $null -and $ct.StartsWith("@about")) {
        $changed = $true
        $i++
        while ($i -lt $header.Count) {
          $ct2 = CommentText $header[$i] $Prefix
          if ($ct2 -eq $null) { break }
          if ($ct2.Length -ge 2 -and $ct2.Substring(0,2) -eq "  ") { $i++; continue }
          break
        }
        $i--
        continue
      }
      $new.Add($header[$i])
    }
    $header = $new.ToArray()
  }

  # unknown @tags -> rewrite into @about
  $newHeader = New-Object System.Collections.Generic.List[string]
  foreach ($l in $header) {
    $ct = CommentText $l $Prefix
    if ($ct -ne $null -and $ct.StartsWith("@")) {
      $rest = $ct.Substring(1).Trim()
      $tag = ($rest.Split(" ")[0]).ToLowerInvariant()
      if (-not $Allowed.ContainsKey($tag)) {
        $newHeader.Add("$Prefix @about")
        $newHeader.Add("$Prefix   $rest")
        $changed = $true
        continue
      }
    }
    $newHeader.Add($l)
  }
  $header = $newHeader.ToArray()

  # ensure @version exists
  $hasVersion = $false
  foreach ($l in $header) {
    $ct = CommentText $l $Prefix
    if ($ct -ne $null -and $ct.StartsWith("@version")) { $hasVersion = $true; break }
  }
  if (-not $hasVersion) {
    $ins = 0
    for ($i=0; $i -lt $header.Count; $i++) {
      $ct = CommentText $header[$i] $Prefix
      if ($ct -ne $null -and $ct.StartsWith("@description")) { $ins = $i+1; break }
    }
    $before = if ($ins -gt 0) { $header[0..($ins-1)] } else { @() }
    $after  = if ($ins -lt $header.Count) { $header[$ins..($header.Count-1)] } else { @() }
    $header = $before + @("$Prefix @version $DefaultVersion") + $after
    $changed = $true
  }

  # ensure blank line after header (JSFX safety)
  if ($header.Count -gt 0 -and $header[$header.Count-1].Trim().Length -ne 0) {
    $header = $header + @("")
    $changed = $true
  }

  if ($changed) {
    Set-Content -LiteralPath $FilePath -Value (@($header) + @($body)) -Encoding UTF8
  }
  return $changed
}

$repo = [IO.Path]::GetFullPath($RepoRoot)
if (-not (Test-Path $repo)) { throw "RepoRoot not found: $repo" }

$backup = New-Backup $repo
Write-Host "Backup created: $backup"

$removeAbout = $false
if ($RemoveAboutIfNoPandoc -and -not (Has-Pandoc)) {
  Write-Host "pandoc not found -> stripping @about blocks."
  $removeAbout = $true
}

$targets = Get-ChildItem -Path $repo -Recurse -File -Include *.lua,*.eel,*.py,*.jsfx
$changedCount = 0

foreach ($f in $targets) {
  $full = $f.FullName
  $prefix = if ($f.Extension.ToLowerInvariant() -eq ".jsfx") { "//" } else { "--" }
  Backup-File $repo $backup $full
  if (Fix-OneFile -FilePath $full -DefaultVersion $DefaultVersion -Prefix $prefix -RemoveAbout:$removeAbout) { $changedCount++ }
}

Write-Host "Done. Files modified: $changedCount"
Write-Host "Next: reapack-index --check --strict ."
