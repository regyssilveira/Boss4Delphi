$ErrorActionPreference = 'Stop'
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$validator = Join-Path $PSScriptRoot 'validate-registry-pages.ps1'
$workflowPath = Join-Path $workspace '.github\workflows\registry-pages.yml'

& $validator -Root $workspace

$workflow = Get-Content -LiteralPath $workflowPath -Raw
foreach ($required in @(
    'actions/upload-pages-artifact@v4',
    'actions/deploy-pages@v4',
    'pages: write',
    'id-token: write',
    'contents: read',
    './scripts/validate-registry-pages.ps1')) {
  if (-not $workflow.Contains($required)) {
    throw "Registry Pages workflow is missing: $required"
  }
}

$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) (
  'boss4d-registry-pages-' + [Guid]::NewGuid().ToString('N'))
try {
  $fixtureRegistry = Join-Path $fixtureRoot 'registry'
  New-Item -ItemType Directory -Path $fixtureRegistry | Out-Null
  Copy-Item -Path (Join-Path $workspace 'registry\*') `
    -Destination $fixtureRegistry -Recurse
  $searchPath = Join-Path $fixtureRegistry 'search-index.json'
  $search = Get-Content -LiteralPath $searchPath -Raw | ConvertFrom-Json
  $search.packageCount = [int]$search.packageCount + 1
  $search | ConvertTo-Json -Depth 30 |
    Set-Content -LiteralPath $searchPath -Encoding UTF8

  $failed = $false
  try {
    & $validator -Root $fixtureRoot
  } catch {
    $failed = $_.Exception.Message -like '*count does not match*'
  }
  if (-not $failed) {
    throw 'Registry Pages validator accepted a stale search index.'
  }
} finally {
  if (Test-Path -LiteralPath $fixtureRoot) {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
  }
}

Write-Output 'Registry Pages validation contract: OK'
