[CmdletBinding()]
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$BaseRoot = '',
  [string]$BaseRef = '',
  [string[]]$ChangedFiles = @()
)

$ErrorActionPreference = 'Stop'

function Read-JsonObject([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Required JSON file not found: $Path"
  }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-BaseJson([string]$RelativePath) {
  if ($BaseRoot) {
    $path = Join-Path $BaseRoot $RelativePath
    if (Test-Path -LiteralPath $path) {
      return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    }
    return $null
  }
  if ($BaseRef) {
    $normalized = $RelativePath.Replace('\', '/')
    $content = & git -C $Root show "${BaseRef}:$normalized" 2>$null
    if ($LASTEXITCODE -eq 0) {
      return ($content -join "`n") | ConvertFrom-Json
    }
  }
  return $null
}

function Assert-VersionEvidence($Version, [string]$Context) {
  if ($Version.version -notmatch '^\d+\.\d+\.\d+([+-][0-9A-Za-z.-]+)?$') {
    throw "$Context has an invalid semantic version."
  }
  if ([string]::IsNullOrWhiteSpace($Version.artifact) -or
      $Version.sha256 -notmatch '^[0-9a-fA-F]{64}$') {
    throw "$Context requires an artifact and a 64-character SHA-256."
  }
  if ([string]::IsNullOrWhiteSpace($Version.signature) -or
      [string]::IsNullOrWhiteSpace($Version.provenance)) {
    throw "$Context requires signature and provenance evidence."
  }
  foreach ($variant in @($Version.variants | Where-Object { $null -ne $_ })) {
    if ([string]::IsNullOrWhiteSpace($variant.artifact) -or
        $variant.sha256 -notmatch '^[0-9a-fA-F]{64}$') {
      throw "$Context contains a variant without immutable evidence."
    }
  }
}

$publisherDocument = Read-JsonObject (Join-Path $Root 'registry\publishers.json')
$indexDocument = Read-JsonObject (Join-Path $Root 'registry\index-v2.json')
if ($publisherDocument.schemaVersion -ne 1) {
  throw 'Unsupported publishers schema.'
}
$publishers = @{}
foreach ($publisher in @($publisherDocument.publishers)) {
  if ([string]::IsNullOrWhiteSpace($publisher.id) -or
      $publishers.ContainsKey($publisher.id)) {
    throw 'Publisher IDs must be present and unique.'
  }
  $publishers[$publisher.id] = $publisher
}
$sparsePaths = @{}
foreach ($entry in @($indexDocument.sparse)) {
  $path = if ($entry -is [string]) { $entry } else { $entry.path }
  if (-not [string]::IsNullOrWhiteSpace($path)) {
    $sparsePaths[$path.Replace('\', '/')] = $true
  }
}

if ($ChangedFiles.Count -eq 0) {
  if ($BaseRef) {
    $ChangedFiles = @(& git -C $Root diff --name-only "$BaseRef...HEAD" -- 'registry/packages/*.json')
  } else {
    $ChangedFiles = @(Get-ChildItem (Join-Path $Root 'registry\packages') -Filter *.json |
      ForEach-Object { "registry/packages/$($_.Name)" })
  }
}

foreach ($relativePath in $ChangedFiles) {
  $relativePath = $relativePath.Replace('/', '\')
  if ($relativePath -notlike 'registry\packages\*.json') { continue }
  $document = Read-JsonObject (Join-Path $Root $relativePath)
  $indexPath = $relativePath.Replace('\', '/').Substring('registry/'.Length)
  if (-not $sparsePaths.ContainsKey($indexPath)) {
    throw "$relativePath is not referenced by registry/index-v2.json sparse metadata."
  }
  if ($document.schemaVersion -ne 2 -or @($document.packages).Count -ne 1) {
    throw "$relativePath must contain exactly one schema-v2 package."
  }
  $package = @($document.packages)[0]
  if (-not $publishers.ContainsKey($package.publisher)) {
    throw "$relativePath references an unknown publisher."
  }
  $publisher = $publishers[$package.publisher]
  if ($package.signerFingerprint -notmatch '^[0-9a-fA-F]{40}$' -or
      @($publisher.allowedSigners) -notcontains $package.signerFingerprint) {
    throw "$relativePath signer fingerprint is not authorized for the publisher."
  }
  $repositoryAllowed = $false
  foreach ($prefix in @($publisher.repositories)) {
    if ($package.repository.StartsWith($prefix,
        [System.StringComparison]::OrdinalIgnoreCase)) {
      $repositoryAllowed = $true
    }
  }
  if (-not $repositoryAllowed) {
    throw "$relativePath repository is outside the publisher scope."
  }
  $seenVersions = @{}
  foreach ($version in @($package.versions)) {
    Assert-VersionEvidence $version "$($package.name)@$($version.version)"
    if ($seenVersions.ContainsKey($version.version)) {
      throw "$relativePath contains a duplicate version."
    }
    $seenVersions[$version.version] = $version
  }

  $baseDocument = Get-BaseJson $relativePath
  if ($null -ne $baseDocument) {
    $basePackage = @($baseDocument.packages)[0]
    foreach ($baseVersion in @($basePackage.versions)) {
      if (-not $seenVersions.ContainsKey($baseVersion.version)) {
        throw "$relativePath removes immutable version $($baseVersion.version)."
      }
      $before = $baseVersion | ConvertTo-Json -Depth 20 -Compress
      $after = $seenVersions[$baseVersion.version] | ConvertTo-Json -Depth 20 -Compress
      if ($before -cne $after) {
        throw "$relativePath modifies immutable version $($baseVersion.version)."
      }
    }
  }
}

Write-Output "Registry submissions validated: $($ChangedFiles.Count)"
