[CmdletBinding()]
param(
  [string]$Path = (Join-Path $PSScriptRoot '..\.github\workflows\release.yml')
)

$ErrorActionPreference = 'Stop'
$content = Get-Content -LiteralPath $Path -Raw
$required = @(
  'tags:',
  'ubuntu-24.04',
  'self-hosted, windows, delphi-13',
  'Boss4DPosixTests',
  'build_release.bat',
  'boss4d-linux-x86_64.tar.gz',
  'boss4d-windows.zip',
  'SHA256SUMS.txt',
  'artifact-matrix.json',
  'actions/attest-build-provenance@v2',
  'id-token: write',
  'needs: [linux, windows]',
  "startsWith(github.ref, 'refs/tags/v')"
)

foreach ($value in $required) {
  if (-not $content.Contains($value)) {
    throw "Release workflow contract is missing: $value"
  }
}

if ($content -match 'pull_request:\s*[\r\n]') {
  throw 'Release publishing must not run for pull requests.'
}

Write-Output 'Release workflow contract: OK'
