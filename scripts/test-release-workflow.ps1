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
  '-RequiredVersions 10,13',
  'boss4d-linux-x86_64.tar.gz',
  'macos-15',
  'brew install fpc',
  'boss4d-macos-*.tar.gz',
  'archive_path="$PWD/.release/$archive"',
  'tar -C "$PWD/.release/macos" -czf "$archive_path" boss4d',
  'shasum -a 256',
  'boss4d-windows.zip',
  'Boss4D_Setup.exe',
  'dist\bin\boss4d.exe pack',
  '*.b4dpkg',
  '*.b4dpkg.intoto.json',
  'Inno Setup 6\ISCC.exe',
  'SHA256SUMS.txt',
  'artifact-matrix.json',
  'actions/attest-build-provenance@v2',
  'id-token: write',
  'needs: [linux, macos, windows]',
  "startsWith(github.ref, 'refs/tags/v')"
)

foreach ($value in $required) {
  if (-not $content.Contains($value)) {
    throw "Release workflow contract is missing: $value"
  }
}

$hiddenArtifactUploads = [regex]::Matches(
  $content,
  '(?m)^\s+include-hidden-files:\s+true\s*$'
).Count
if ($hiddenArtifactUploads -ne 3) {
  throw 'Every release artifact upload must include the hidden staging directory.'
}

$windowsPowerShellSteps = [regex]::Matches(
  $content,
  '(?m)^\s+shell:\s+powershell\s*$'
).Count
if ($windowsPowerShellSteps -ne 4 -or $content.Contains('shell: pwsh')) {
  throw 'Windows release steps must use the PowerShell available on the runner.'
}

if ($content -match 'pull_request:\s*[\r\n]') {
  throw 'Release publishing must not run for pull requests.'
}

$root = Join-Path $PSScriptRoot '..'
$manifest = Get-Content -LiteralPath (Join-Path $root 'boss.json') -Raw |
  ConvertFrom-Json
$version = [string]$manifest.version
$resourceVersion = $version.Replace('.', ',') + ',0'
$versionContracts = @{
  'boss-lock.json' = '"version": "' + $version + '"'
  'sonar-project.properties' = 'sonar.projectVersion=' + $version
  'installer\Boss4D.iss' = 'AppVersion=' + $version
  'src\CLI\Boss4D.CLI.Parser.pas' = 'v' + $version + '-delphi-native'
  'src\Core\Services\Boss4D.Core.Services.DependencySubmission.pas' =
    "LDetector.AddPair('version', '$version');"
  'src\Core\Services\Boss4D.Core.Services.Pack.pas' =
    "'builder', 'boss4d/' + '$version'"
  'src\Core\Services\Boss4D.Core.Services.Sbom.pas' =
    "Result.ToolVersion := '$version';"
  'src\Posix\Boss4D.Posix.Core.pas' = "Result := '$version';"
  'src\IDE\Boss4D.IDE.Plugin.rc' = '"' + $version + '.0"'
  'src\IDE\Boss4D.IDE.Plugin.rc#numeric' =
    'FILEVERSION ' + $resourceVersion
  'src\IDE\Boss4D.IDE.Wizard.pas' = "'$version'"
  'CHANGELOG.md' = '## ' + $version + ' -'
}
foreach ($entry in $versionContracts.GetEnumerator()) {
  $relativePath = $entry.Key.Split('#')[0]
  $contract = Get-Content -LiteralPath (Join-Path $root $relativePath) -Raw
  if (-not $contract.Contains($entry.Value)) {
    throw "Release version $version is not synchronized in $($entry.Key)."
  }
}

$installer = Get-Content -LiteralPath (Join-Path $root 'installer\Boss4D.iss')
$pluginSources = @($installer | Where-Object {
  $_ -match '^Source: ".+dist\\plugins\\'
})
$optionalPluginSources = @($pluginSources | Where-Object {
  $_ -match 'Flags: [^;]*skipifsourcedoesntexist'
})
if ($pluginSources.Count -ne 5 -or
    $optionalPluginSources.Count -ne $pluginSources.Count) {
  throw 'Every IDE plugin source must tolerate an unavailable optional compiler.'
}

Write-Output 'Release workflow contract: OK'
