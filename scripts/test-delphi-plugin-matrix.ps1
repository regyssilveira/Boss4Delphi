[CmdletBinding()]
param(
  [string]$OutputRoot = (Join-Path $PSScriptRoot '..\.codex-build\plugin-matrix')
)

$ErrorActionPreference = 'Stop'
$versions = [ordered]@{
  '10.1' = @{ Bds = '17.0'; Legacy = $true }
  '11'   = @{ Bds = '22.0'; Legacy = $false }
  '12'   = @{ Bds = '23.0'; Legacy = $false }
  '13'   = @{ Bds = '37.0'; Legacy = $false }
}
$ideRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\src\IDE')).Path

foreach ($version in $versions.Keys) {
  $bds = $versions[$version].Bds
  $root = (Get-ItemProperty -Path "HKCU:\Software\Embarcadero\BDS\$bds" `
    -Name RootDir -ErrorAction SilentlyContinue).RootDir
  if ([string]::IsNullOrWhiteSpace($root)) {
    throw "Delphi $version (BDS $bds) is required for the plugin matrix."
  }
  $output = Join-Path $OutputRoot $version
  New-Item -ItemType Directory -Force $output | Out-Null
  $defines = if ($versions[$version].Legacy) {
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
}

Write-Output 'Delphi plugin matrix 10.1/11/12/13: OK'
