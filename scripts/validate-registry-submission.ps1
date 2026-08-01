[CmdletBinding()]
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$BaseRoot = '',
  [string]$BaseRef = '',
  [string[]]$ChangedFiles = @(),
  [string]$Submitter = $env:GITHUB_ACTOR
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
    $previousErrorActionPreference = $ErrorActionPreference
    try {
      $ErrorActionPreference = 'SilentlyContinue'
      $content = & git -C $Root show "${BaseRef}:$normalized" 2>$null
      $gitExitCode = $LASTEXITCODE
    } finally {
      $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($gitExitCode -eq 0) {
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

function Get-EntriesById($Document, [string]$PropertyName) {
  $result = @{}
  if ($null -eq $Document) { return $result }
  foreach ($entry in @($Document.$PropertyName)) {
    if (-not [string]::IsNullOrWhiteSpace($entry.id)) {
      $result[$entry.id] = $entry
    }
  }
  return $result
}

function ConvertTo-StableJson($Value) {
  return $Value | ConvertTo-Json -Depth 20 -Compress
}

function Assert-AuthorizedSubmitter($Publisher, [string]$Context) {
  if ([string]::IsNullOrWhiteSpace($Submitter)) {
    throw "$Context requires -Submitter (the GitHub login opening the change)."
  }
  $registeredOwners = @($Publisher.githubOwners | Where-Object {
    -not [string]::IsNullOrWhiteSpace($_)
  })
  if ($registeredOwners -contains $Submitter) {
    return
  }
  if ($registeredOwners.Count -eq 0) {
    $personalPrefix = "github.com/$Submitter/"
    foreach ($repository in @($Publisher.repositories)) {
      if ($repository.StartsWith($personalPrefix,
          [StringComparison]::OrdinalIgnoreCase)) {
        return
      }
    }
  }
  throw "$Context is not authorized for GitHub submitter '$Submitter'."
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
  if ($publisher.id -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
    throw "Publisher ID '$($publisher.id)' must be a normalized lowercase slug."
  }
  if ([string]::IsNullOrWhiteSpace($publisher.displayName) -or
      @($publisher.githubOwners).Count -eq 0 -or
      @($publisher.repositories).Count -eq 0) {
    throw "Publisher '$($publisher.id)' requires displayName, githubOwners, and repositories."
  }
  foreach ($owner in @($publisher.githubOwners)) {
    if ($owner -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$') {
      throw "Publisher '$($publisher.id)' contains an invalid GitHub owner."
    }
  }
  foreach ($signer in @($publisher.allowedSigners)) {
    if ($signer -notmatch '^[0-9a-fA-F]{40}$') {
      throw "Publisher '$($publisher.id)' contains an invalid OpenPGP fingerprint."
    }
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
    $ChangedFiles = @(& git -C $Root diff --name-only "$BaseRef...HEAD" -- `
      'registry/packages/*.json' 'registry/publishers.json' `
      'registry/index-v1.json' 'registry/index-v2.json')
  } else {
    $packageDirectory = Join-Path $Root 'registry\packages'
    if (Test-Path -LiteralPath $packageDirectory -PathType Container) {
      $ChangedFiles = @(Get-ChildItem $packageDirectory -Filter *.json |
        ForEach-Object { "registry/packages/$($_.Name)" })
    } else {
      $ChangedFiles = @()
    }
  }
}

$normalizedChanges = @($ChangedFiles | ForEach-Object {
  $_.Replace('\', '/')
})
$basePublishersDocument = Get-BaseJson 'registry/publishers.json'
$basePublishers = Get-EntriesById $basePublishersDocument 'publishers'
if ($normalizedChanges -contains 'registry/publishers.json') {
  foreach ($baseId in $basePublishers.Keys) {
    if (-not $publishers.ContainsKey($baseId)) {
      throw "Publisher '$baseId' cannot be removed."
    }
    $before = ConvertTo-StableJson $basePublishers[$baseId]
    $after = ConvertTo-StableJson $publishers[$baseId]
    if ($before -cne $after) {
      Assert-AuthorizedSubmitter $basePublishers[$baseId] "Publisher '$baseId' update"
    }
  }
  foreach ($publisherId in $publishers.Keys) {
    if (-not $basePublishers.ContainsKey($publisherId)) {
      Assert-AuthorizedSubmitter $publishers[$publisherId] "Publisher '$publisherId' onboarding"
    }
  }
}

$baseIndex = Get-BaseJson 'registry/index-v2.json'
if (($normalizedChanges -contains 'registry/index-v2.json') -and
    ($null -ne $baseIndex)) {
  $currentSparse = @($indexDocument.sparse | ForEach-Object {
    if ($_ -is [string]) { $_ } else { $_.path }
  })
  foreach ($baseEntry in @($baseIndex.sparse)) {
    $basePath = if ($baseEntry -is [string]) { $baseEntry } else { $baseEntry.path }
    if ($currentSparse -notcontains $basePath) {
      throw "Registry index cannot remove sparse entry '$basePath'."
    }
  }
  if ((ConvertTo-StableJson @($baseIndex.includes)) -cne
      (ConvertTo-StableJson @($indexDocument.includes))) {
    throw 'Registry submissions cannot modify root includes.'
  }
}

$changedPackageIdentities = @{}
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
  $packageIdentity = ($package.name.ToLowerInvariant() + '|' +
    $package.repository.ToLowerInvariant())
  $changedPackageIdentities[$packageIdentity] = $true
  $slug = ($package.name.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
  if (([IO.Path]::GetFileNameWithoutExtension($relativePath)) -cne $slug) {
    throw "$relativePath must use normalized package filename '$slug.json'."
  }
  if (-not $publishers.ContainsKey($package.publisher)) {
    throw "$relativePath references an unknown publisher."
  }
  $publisher = $publishers[$package.publisher]
  Assert-AuthorizedSubmitter $publisher "$($package.name) submission"
  if ($package.signerFingerprint -notmatch '^[0-9a-fA-F]{40}$' -or
      @($publisher.allowedSigners) -notcontains $package.signerFingerprint) {
    throw "$relativePath signer fingerprint is not authorized for the publisher."
  }
  $repositoryAllowed = $false
  $scopeRepository = $package.distributionRepository
  if ([string]::IsNullOrWhiteSpace($scopeRepository)) {
    $scopeRepository = $package.repository
  }
  foreach ($prefix in @($publisher.repositories)) {
    if ($scopeRepository.StartsWith($prefix,
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

if ($normalizedChanges -contains 'registry/index-v1.json') {
  $baseLegacy = Get-BaseJson 'registry/index-v1.json'
  $currentLegacy = Read-JsonObject (
    Join-Path $Root 'registry\index-v1.json')
  if ($null -eq $baseLegacy -or $baseLegacy.schemaVersion -ne 1 -or
      $currentLegacy.schemaVersion -ne 1) {
    throw 'Legacy migration requires schema-v1 base and current indexes.'
  }
  $baseLegacyEntries = @{}
  foreach ($legacyPackage in @($baseLegacy.packages)) {
    $identity = ($legacyPackage.name.ToLowerInvariant() + '|' +
      $legacyPackage.repository.ToLowerInvariant())
    $baseLegacyEntries[$identity] = ConvertTo-StableJson $legacyPackage
  }
  $currentLegacyEntries = @{}
  foreach ($legacyPackage in @($currentLegacy.packages)) {
    $identity = ($legacyPackage.name.ToLowerInvariant() + '|' +
      $legacyPackage.repository.ToLowerInvariant())
    if (-not $baseLegacyEntries.ContainsKey($identity)) {
      throw "Legacy Registry cannot add package '$($legacyPackage.name)'."
    }
    if ($baseLegacyEntries[$identity] -cne
        (ConvertTo-StableJson $legacyPackage)) {
      throw "Legacy Registry cannot modify package '$($legacyPackage.name)'."
    }
    $currentLegacyEntries[$identity] = $true
  }
  $removedLegacyCount = 0
  foreach ($identity in $baseLegacyEntries.Keys) {
    if (-not $currentLegacyEntries.ContainsKey($identity)) {
      $removedLegacyCount++
      if (-not $changedPackageIdentities.ContainsKey($identity)) {
        throw "Legacy Registry package '$identity' can only be removed " +
          'when matching schema-v2 metadata is submitted.'
      }
    }
  }
  if ($removedLegacyCount -eq 0) {
    throw 'Legacy Registry changes must migrate at least one package.'
  }
}

Write-Output "Registry submissions validated: $($ChangedFiles.Count)"
