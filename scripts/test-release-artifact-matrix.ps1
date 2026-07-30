[CmdletBinding()]
param(
  [string]$MatrixPath = (Join-Path $PSScriptRoot '..\release\artifact-matrix.json')
)

$ErrorActionPreference = 'Stop'
$matrix = Get-Content -LiteralPath $MatrixPath -Raw | ConvertFrom-Json
if ($matrix.schemaVersion -ne 1) {
  throw 'Unsupported release artifact matrix schema.'
}

$names = @{}
$targets = @{}
foreach ($artifact in @($matrix.artifacts)) {
  if ([string]::IsNullOrWhiteSpace($artifact.name) -or
      $names.ContainsKey($artifact.name)) {
    throw 'Release artifact names must be present and unique.'
  }
  $names[$artifact.name] = $true
  foreach ($target in @($artifact.targets)) {
    $key = "$($target.os)/$($target.architecture)/$($target.compiler.family)/$($target.compiler.version)"
    if ($targets.ContainsKey($key)) {
      throw "Duplicate release target: $key"
    }
    $targets[$key] = $true
  }
}

foreach ($required in @(
  'windows/x86/delphi/37.0',
  'windows/x86_64/delphi/37.0',
  'linux/x86_64/fpc/3.2.2'
)) {
  if (-not $targets.ContainsKey($required)) {
    throw "Release matrix is missing target: $required"
  }
}

$windows = @($matrix.artifacts | Where-Object name -eq 'boss4d-windows.zip')[0]
$pluginVersions = @($windows.components |
  Where-Object kind -eq 'ide-plugin' |
  ForEach-Object delphi)
foreach ($required in @('10.1', '11', '12', '13')) {
  if ($pluginVersions -notcontains $required) {
    throw "Release matrix is missing Delphi plugin: $required"
  }
}
$expectedBds = @{
  '10.1' = '18.0'
  '11' = '22.0'
  '12' = '23.0'
  '13' = '37.0'
}
foreach ($component in @($windows.components |
  Where-Object kind -eq 'ide-plugin')) {
  if ($expectedBds[$component.delphi] -ne $component.bds) {
    throw "Invalid BDS mapping for Delphi $($component.delphi): $($component.bds)"
  }
}

$updateSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\src\Posix\Boss4D.Posix.Update.pas') -Raw
if (-not $updateSource.Contains('boss4d-linux-x86_64.tar.gz')) {
  throw 'Linux matrix artifact no longer matches the self-update contract.'
}

Write-Output 'Release artifact matrix: OK'
