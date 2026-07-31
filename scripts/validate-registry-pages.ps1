[CmdletBinding()]
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'
$registryRoot = [IO.Path]::GetFullPath((Join-Path $Root 'registry'))
$entryPath = Join-Path $registryRoot 'index-v2.json'
$portalPath = Join-Path $registryRoot 'index.html'
$searchPath = Join-Path $registryRoot 'search-index.json'
$publishersPath = Join-Path $registryRoot 'publishers.json'

foreach ($path in @($entryPath, $portalPath, $searchPath, $publishersPath)) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Required Registry Pages artifact not found: $path"
  }
}

$visited = @{}
$catalog = [Collections.Generic.List[object]]::new()

function Resolve-RegistryReference([string]$SourcePath, [string]$Reference) {
  if ($Reference -match '^https?://') {
    throw "Registry Pages requires materialized local references: $Reference"
  }
  $resolved = [IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $SourcePath) $Reference))
  $prefix = $registryRoot + [IO.Path]::DirectorySeparatorChar
  if (-not $resolved.StartsWith($prefix,
      [StringComparison]::OrdinalIgnoreCase)) {
    throw "Registry reference escapes the publication root: $Reference"
  }
  return $resolved
}

function Read-RegistryDocument([string]$Path) {
  $fullPath = [IO.Path]::GetFullPath($Path)
  if ($visited.ContainsKey($fullPath)) { return }
  $visited[$fullPath] = $true
  if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
    throw "Registry reference not found: $fullPath"
  }
  $document = Get-Content -LiteralPath $fullPath -Raw | ConvertFrom-Json
  if ($document.schemaVersion -notin @(1, 2)) {
    throw "Unsupported registry schema in $fullPath"
  }
  foreach ($package in @($document.packages)) {
    if ($null -ne $package) { $catalog.Add($package) }
  }
  foreach ($field in @('includes', 'sparse')) {
    foreach ($entry in @($document.$field)) {
      if ($null -eq $entry) { continue }
      $reference = if ($entry -is [string]) { $entry } else { $entry.path }
      if ([string]::IsNullOrWhiteSpace($reference)) {
        throw "Empty $field reference in $fullPath"
      }
      Read-RegistryDocument (Resolve-RegistryReference $fullPath $reference)
    }
  }
}

Read-RegistryDocument $entryPath
$searchRaw = Get-Content -LiteralPath $searchPath -Raw
$search = $searchRaw | ConvertFrom-Json
if ($search.schemaVersion -ne 1 -or
    $search.sourceProtocol -ne 'boss4d-registry-v2') {
  throw 'Unsupported consolidated search index.'
}
$searchPackages = @($search.packages)
if ($search.packageCount -ne $searchPackages.Count -or
    $searchPackages.Count -ne $catalog.Count) {
  throw "Search index count does not match composed registry catalog."
}
if ($searchRaw.Contains('"_publisher')) {
  throw 'Search index exposes private projection fields.'
}

$portal = Get-Content -LiteralPath $portalPath -Raw
foreach ($marker in @(
    'Protocol v2',
    'id="package-search"',
    'id="trust-filter"',
    'id="migration-filter"',
    'id="platform-filter"',
    'id="compiler-filter"',
    'id="visible-count"',
    'id="community-submit"',
    'issues/new?template=registry-package-submission.yml',
    'automated checks and explicit maintainer approval',
    'verified packages',
    'legacy packages',
    'verified migration')) {
  if (-not $portal.Contains($marker)) {
    throw "Registry portal is missing required marker: $marker"
  }
}

for ($index = 0; $index -lt $catalog.Count; $index++) {
  $expected = [string]$catalog[$index].name
  $actual = [string]$searchPackages[$index].name
  if ($expected -cne $actual) {
    throw "Search index order/content mismatch at package $index."
  }
  $encoded = [Net.WebUtility]::HtmlEncode($expected)
  if (-not $portal.Contains("<strong>$encoded</strong>")) {
    throw "Registry portal does not contain package: $expected"
  }
}

$publishers = Get-Content -LiteralPath $publishersPath -Raw |
  ConvertFrom-Json
if ($publishers.schemaVersion -ne 1) {
  throw 'Unsupported publishers schema.'
}

Write-Output "Registry Pages artifacts validated: $($catalog.Count) packages."
