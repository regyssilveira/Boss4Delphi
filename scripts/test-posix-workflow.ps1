[CmdletBinding()]
param(
  [string]$Path = (Join-Path $PSScriptRoot '..\.github\workflows\posix-ci.yml')
)

$ErrorActionPreference = 'Stop'
$content = Get-Content -LiteralPath $Path -Raw
$required = @(
  'pull_request:',
  'ubuntu-24.04',
  'macos-15',
  'brew install fpc',
  'Boss4DPosixTests --all --format=plain',
  'boss4d platform',
  "uname -s",
  "grep -q '^OK sha256:'",
  'fail-fast: false'
)

foreach ($value in $required) {
  if (-not $content.Contains($value)) {
    throw "POSIX workflow contract is missing: $value"
  }
}

if ($content.Contains('continue-on-error: true')) {
  throw 'POSIX CI must not hide platform failures.'
}

Write-Output 'POSIX workflow contract: OK'
