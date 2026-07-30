[CmdletBinding()]
param(
  [string]$Path = (Join-Path $PSScriptRoot '..\.github\workflows\release.yml')
)

$ErrorActionPreference = 'Stop'
$content = Get-Content -LiteralPath $Path -Raw
$required = @(
  'tags:',
  'ubuntu-24.04',
  'build-essential',
  'fp-units-fcl',
  'fp-units-net',
  'self-hosted, windows, delphi-13',
  'Boss4DPosixTests',
  'build_release.bat',
  'test-delphi-plugin-matrix.ps1',
  'boss4d-linux-x86_64.tar.gz',
  'boss4d-windows.zip',
  'Boss4D_Setup.exe',
  'Inno Setup 6\ISCC.exe',
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

$root = Join-Path $PSScriptRoot '..'
$manifest = Get-Content -LiteralPath (Join-Path $root 'boss.json') -Raw |
  ConvertFrom-Json
$version = [string]$manifest.version
$versionContracts = @{
  'boss-lock.json' = '"version": "' + $version + '"'
  'sonar-project.properties' = 'sonar.projectVersion=' + $version
  'installer\Boss4D.iss' = 'AppVersion=' + $version
  'src\CLI\Boss4D.CLI.Parser.pas' = 'v' + $version + '-delphi-native'
  'src\Posix\Boss4D.Posix.Core.pas' = "Result := '$version';"
  'src\IDE\Boss4D.IDE.Plugin.rc' = '"' + $version + '.0"'
  'CHANGELOG.md' = '## ' + $version + ' -'
}
foreach ($entry in $versionContracts.GetEnumerator()) {
  $contract = Get-Content -LiteralPath (Join-Path $root $entry.Key) -Raw
  if (-not $contract.Contains($entry.Value)) {
    throw "Release version $version is not synchronized in $($entry.Key)."
  }
}

Write-Output 'Release workflow contract: OK'
