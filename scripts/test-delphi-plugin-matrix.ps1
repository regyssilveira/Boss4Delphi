[CmdletBinding()]
param(
  [string]$OutputRoot = (Join-Path $PSScriptRoot '..\.codex-build\plugin-matrix'),
  [string[]]$Versions = @('10', '10.1', '11', '12', '13'),
  [string[]]$RequiredVersions = @('10', '13')
)

$ErrorActionPreference = 'Stop'
$versionMap = [ordered]@{
  '10'   = @{ Bds = '17.0'; Legacy = $true }
  '10.1' = @{ Bds = '18.0'; Legacy = $true }
  '11'   = @{ Bds = '22.0'; Legacy = $false }
  '12'   = @{ Bds = '23.0'; Legacy = $false }
  '13'   = @{ Bds = '37.0'; Legacy = $false }
}
$ideRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\src\IDE')).Path
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
$builtVersions = [Collections.Generic.List[string]]::new()

foreach ($version in $Versions) {
  if (-not $versionMap.Contains($version)) {
    throw "Unsupported Delphi plugin version: $version."
  }
  $bds = $versionMap[$version].Bds
  $root = (Get-ItemProperty -Path "HKCU:\Software\Embarcadero\BDS\$bds" `
    -Name RootDir -ErrorAction SilentlyContinue).RootDir
  if ([string]::IsNullOrWhiteSpace($root)) {
    if ($RequiredVersions -contains $version) {
      throw "Delphi $version (BDS $bds) is required for the plugin matrix."
    }
    Write-Warning "Skipping optional Delphi $version (BDS $bds): not installed."
    continue
  }
  $output = Join-Path $OutputRoot $version
  New-Item -ItemType Directory -Force $output | Out-Null
  $defines = if ($versionMap[$version].Legacy) {
    '-DIDE_PLUGIN -DLEGACY_IDE'
  } else {
    '-DIDE_PLUGIN'
  }
  $compilerCommand = "dcc32 -B -Q -LUrtl -LUvcl -LUdesignide $defines -U`"$($root.TrimEnd('\'))\lib\Win32\release`" -LE`"$output`" -N0`"$output`" Boss4D.IDE.Plugin.dpk"
  $command = @(
    "call `"$($root.TrimEnd('\'))\bin\rsvars.bat`" >nul",
    'brcc32 Boss4D.IDE.Plugin.rc >nul',
    $compilerCommand
  ) -join ' && '
  Push-Location $ideRoot
  try {
    & cmd.exe /d /c $command
    if ($LASTEXITCODE -ne 0) {
      throw "Plugin compilation failed for Delphi $version."
    }
  } finally {
    Pop-Location
  }
  if (-not (Test-Path -LiteralPath (Join-Path $output 'Boss4D.IDE.Plugin.bpl'))) {
    throw "Plugin output is missing for Delphi $version."
  }
  $builtVersions.Add($version)
}

Write-Output "Delphi plugin matrix $($builtVersions -join '/'): OK"
