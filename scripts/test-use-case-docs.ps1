[CmdletBinding()]
param(
  [string]$RepositoryRoot = (Join-Path $PSScriptRoot '..')
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$hubPairs = @(
  @('docs\use-cases.md', 'docs\use-cases.pt-BR.md'),
  @('docs\use-cases-project-lifecycle.md',
    'docs\use-cases-project-lifecycle.pt-BR.md'),
  @('docs\use-cases-registry-security.md',
    'docs\use-cases-registry-security.pt-BR.md')
)
$knownCommands = @(
  'add', 'audit', 'build', 'cache', 'ci', 'config', 'doctor', 'getit',
  'ide', 'init', 'install', 'license', 'outdated', 'plugin', 'publish',
  'registry', 'remove', 'run', 'sbom', 'spec', 'tool', 'tree', 'update',
  'version', 'why'
)

foreach ($pair in $hubPairs) {
  $englishPath = Join-Path $root $pair[0]
  $portuguesePath = Join-Path $root $pair[1]
  foreach ($path in @($englishPath, $portuguesePath)) {
    if (-not (Test-Path -LiteralPath $path)) {
      throw "Required use-case document is missing: $path"
    }
    $content = Get-Content -Raw -LiteralPath $path
    if ($content -notmatch '(?m)^## ') {
      throw "Use-case document has no sections: $path"
    }
    foreach ($match in [regex]::Matches(
      $content, '(?m)^\s*boss4d\s+([a-z][a-z0-9-]*)')) {
      $command = $match.Groups[1].Value
      if ($knownCommands -notcontains $command) {
        throw "Unknown Boss4D command '$command' in $path"
      }
    }
  }

  $englishCases = ([regex]::Matches(
    (Get-Content -Raw -LiteralPath $englishPath), '(?m)^## \d+\.')).Count
  $portugueseCases = ([regex]::Matches(
    (Get-Content -Raw -LiteralPath $portuguesePath), '(?m)^## \d+\.')).Count
  if ($englishCases -ne $portugueseCases) {
    throw "Use-case parity mismatch for $($pair[0]): " +
      "EN=$englishCases PT-BR=$portugueseCases"
  }
}

$missingLinks = @()
Get-ChildItem -LiteralPath (Join-Path $root 'docs') -Filter 'use-cases*.md' |
  ForEach-Object {
    $document = $_
    $content = Get-Content -Raw -LiteralPath $document.FullName
    foreach ($match in [regex]::Matches(
      $content, '\[[^\]]+\]\((?!https?://|mailto:|#)([^)]+)\)')) {
      $target = $match.Groups[1].Value.Split('#')[0].Trim('<', '>')
      if ($target -and -not (Test-Path -LiteralPath (
        Join-Path $document.DirectoryName $target))) {
        $missingLinks += "$($document.Name): $target"
      }
    }
  }
if ($missingLinks.Count -gt 0) {
  throw "Broken use-case links:`n$($missingLinks -join "`n")"
}

Write-Output 'Use-case documentation contract: OK'
