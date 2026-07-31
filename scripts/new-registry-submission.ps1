[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$PackageName,
  [Parameter(Mandatory)][string]$Publisher,
  [Parameter(Mandatory)][string]$Repository,
  [Parameter(Mandatory)][string]$SignerFingerprint,
  [Parameter(Mandatory)][string]$Version,
  [Parameter(Mandatory)][string]$Artifact,
  [Parameter(Mandatory)][string]$Sha256,
  [Parameter(Mandatory)][string]$Signature,
  [Parameter(Mandatory)][string]$Provenance,
  [string]$Description = '',
  [string]$License = '',
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Read-Json([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Required Registry file not found: $Path"
  }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-Utf8([string]$Path, [string]$Content) {
  [IO.File]::WriteAllText($Path, $Content + [Environment]::NewLine,
    [Text.UTF8Encoding]::new($false))
}

$slug = ($PackageName.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
if ([string]::IsNullOrWhiteSpace($slug)) {
  throw 'PackageName must contain letters or digits.'
}
if ($Publisher -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
  throw 'Publisher must be a normalized lowercase ID.'
}
if ($Repository -notmatch '^[A-Za-z0-9.-]+/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
  throw 'Repository must use the host/owner/name form.'
}
if ($SignerFingerprint -notmatch '^[0-9a-fA-F]{40}$') {
  throw 'SignerFingerprint must contain 40 hexadecimal characters.'
}
if ($Version -notmatch '^\d+\.\d+\.\d+([+-][0-9A-Za-z.-]+)?$') {
  throw 'Version must be a semantic version.'
}
if ($Sha256 -notmatch '^[0-9a-fA-F]{64}$') {
  throw 'Sha256 must contain 64 hexadecimal characters.'
}
foreach ($uriValue in @($Artifact, $Signature, $Provenance)) {
  $parsed = $null
  if (-not [Uri]::TryCreate($uriValue, [UriKind]::Absolute, [ref]$parsed) -or
      $parsed.Scheme -ne 'https') {
    throw 'Artifact, Signature, and Provenance must use absolute HTTPS URLs.'
  }
}

$publisherPath = Join-Path $Root 'registry\publishers.json'
$indexPath = Join-Path $Root 'registry\index-v2.json'
$packageDirectory = Join-Path $Root 'registry\packages'
$packagePath = Join-Path $packageDirectory "$slug.json"
$publishers = Read-Json $publisherPath
$publisherEntry = @($publishers.publishers |
  Where-Object { $_.id -ceq $Publisher })
if ($publisherEntry.Count -ne 1) {
  throw "Publisher '$Publisher' is not registered."
}
if (@($publisherEntry[0].allowedSigners) -notcontains $SignerFingerprint) {
  throw "SignerFingerprint is not authorized for publisher '$Publisher'."
}
$repositoryAllowed = $false
foreach ($prefix in @($publisherEntry[0].repositories)) {
  if ($Repository.StartsWith($prefix,
      [StringComparison]::OrdinalIgnoreCase)) {
    $repositoryAllowed = $true
  }
}
if (-not $repositoryAllowed) {
  throw "Repository is outside publisher '$Publisher' scope."
}
if (Test-Path -LiteralPath $packagePath) {
  throw "Package metadata already exists: $packagePath"
}

$index = Read-Json $indexPath
$sparsePath = "packages/$slug.json"
$existingSparse = @($index.sparse | ForEach-Object {
  if ($_ -is [string]) { $_ } else { $_.path }
})
if ($existingSparse -contains $sparsePath) {
  throw "Sparse entry already exists: $sparsePath"
}

$versionEntry = [ordered]@{
  version = $Version
  artifact = $Artifact
  sha256 = $Sha256.ToLowerInvariant()
  signature = $Signature
  provenance = $Provenance
}
$packageEntry = [ordered]@{
  name = $PackageName
  publisher = $Publisher
  repository = $Repository
  signerFingerprint = $SignerFingerprint.ToUpperInvariant()
  description = $Description
  license = $License
  versions = @($versionEntry)
}
$packageDocument = [ordered]@{
  schemaVersion = 2
  packages = @($packageEntry)
}
$newSparse = @($existingSparse + $sparsePath | Sort-Object -Unique)
$index.sparse = $newSparse
$packageJson = $packageDocument | ConvertTo-Json -Depth 20
$indexJson = $index | ConvertTo-Json -Depth 20
$originalIndex = Get-Content -LiteralPath $indexPath -Raw

New-Item -ItemType Directory -Force $packageDirectory | Out-Null
try {
  Write-Utf8 $packagePath $packageJson
  Write-Utf8 $indexPath $indexJson
} catch {
  if (Test-Path -LiteralPath $packagePath) {
    Remove-Item -LiteralPath $packagePath -Force
  }
  [IO.File]::WriteAllText($indexPath, $originalIndex,
    [Text.UTF8Encoding]::new($false))
  throw
}

Write-Output "Registry submission created: registry/packages/$slug.json"
Write-Output "Sparse index updated: registry/index-v2.json"
