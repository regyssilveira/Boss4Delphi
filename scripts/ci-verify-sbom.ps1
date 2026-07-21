[CmdletBinding()]
param(
  [string]$BdsRoot = $env:BOSS4D_BDS_ROOT,
  [string]$BuildDirectory = '.ci-build'
)

$ErrorActionPreference = 'Stop'
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$buildRoot = [IO.Path]::GetFullPath((Join-Path $workspace $BuildDirectory))

if (-not $buildRoot.StartsWith($workspace + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase)) {
  throw "BuildDirectory deve permanecer dentro do workspace: $buildRoot"
}
if ([IO.Path]::GetFileName($buildRoot) -notin @('.ci-build', '.codex-build')) {
  throw "Diretório de build não autorizado para limpeza: $buildRoot"
}
if (-not (Test-Path -LiteralPath (Join-Path $workspace 'boss.json'))) {
  throw "Workspace Boss4D inválido: $workspace"
}

if ([string]::IsNullOrWhiteSpace($BdsRoot)) {
  $BdsRoot = (Get-ItemProperty -Path 'HKCU:\Software\Embarcadero\BDS\37.0' `
    -Name RootDir -ErrorAction SilentlyContinue).RootDir
}
if ([string]::IsNullOrWhiteSpace($BdsRoot) -or
    -not (Test-Path -LiteralPath (Join-Path $BdsRoot 'bin\rsvars.bat'))) {
  throw 'Delphi 13 não encontrado. Defina BOSS4D_BDS_ROOT ou configure BDS 37.0 no registro.'
}

if (Test-Path -LiteralPath $buildRoot) {
  Remove-Item -LiteralPath $buildRoot -Recurse -Force
}
$null = New-Item -ItemType Directory -Path $buildRoot

function Invoke-DelphiCommand {
  param([Parameter(Mandatory)][string]$Command, [Parameter(Mandatory)][string]$WorkingDirectory)
  Push-Location $WorkingDirectory
  try {
    & cmd.exe /d /c "call `"$BdsRoot\bin\rsvars.bat`" && $Command"
    if ($LASTEXITCODE -ne 0) { throw "Comando Delphi falhou ($LASTEXITCODE): $Command" }
  } finally {
    Pop-Location
  }
}

$win32 = Join-Path $buildRoot 'win32'
$win64 = Join-Path $buildRoot 'win64'
$sbom32 = Join-Path $buildRoot 'sbom-win32'
$sbom64 = Join-Path $buildRoot 'sbom-win64'
@($win32, $win64, $sbom32, $sbom64) | ForEach-Object {
  $null = New-Item -ItemType Directory -Path $_
}

Invoke-DelphiCommand -WorkingDirectory (Join-Path $workspace 'tests') `
  -Command "dcc32 -B -E`"$win32`" -N0`"$win32`" -N1`"$win32`" Boss4DTests.dpr"
& (Join-Path $win32 'Boss4DTests.exe')
if ($LASTEXITCODE -ne 0) { throw 'Testes Win32 falharam.' }

Invoke-DelphiCommand -WorkingDirectory (Join-Path $workspace 'tests') `
  -Command "dcc64 -B -E`"$win64`" -N0`"$win64`" -N1`"$win64`" Boss4DTests.dpr"
& (Join-Path $win64 'Boss4DTests.exe')
if ($LASTEXITCODE -ne 0) { throw 'Testes Win64 falharam.' }

Invoke-DelphiCommand -WorkingDirectory (Join-Path $workspace 'src') `
  -Command "dcc32 -B -E`"$win32`" -N0`"$win32`" -N1`"$win32`" Boss4D.dpr"
Invoke-DelphiCommand -WorkingDirectory (Join-Path $workspace 'src') `
  -Command "dcc64 -B -E`"$win64`" -N0`"$win64`" -N1`"$win64`" Boss4D.dpr"

foreach ($target in @(
  @{ Exe = Join-Path $win32 'Boss4D.exe'; Dir = $sbom32 },
  @{ Exe = Join-Path $win64 'Boss4D.exe'; Dir = $sbom64 }
)) {
  & $target.Exe sbom --format cyclonedx --strict --validate --lock-only `
    --reproducible --output (Join-Path $target.Dir 'boss4d.cdx.json') `
    --attestation-output (Join-Path $target.Dir 'boss4d.cdx.intoto.json')
  if ($LASTEXITCODE -ne 0) { throw 'Geração CycloneDX falhou.' }
  & $target.Exe sbom --format spdx --strict --validate --lock-only `
    --reproducible --output (Join-Path $target.Dir 'boss4d.spdx.json') `
    --attestation-output (Join-Path $target.Dir 'boss4d.spdx.intoto.json')
  if ($LASTEXITCODE -ne 0) { throw 'Geração SPDX falhou.' }
}

foreach ($name in @('boss4d.cdx.json', 'boss4d.spdx.json',
    'boss4d.cdx.intoto.json', 'boss4d.spdx.intoto.json')) {
  $hash32 = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $sbom32 $name)).Hash
  $hash64 = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $sbom64 $name)).Hash
  if ($hash32 -ne $hash64) { throw "SBOM não reproduzível entre Win32/Win64: $name" }
}

& (Join-Path $win32 'Boss4D.exe') sbom --format cyclonedx --strict --validate `
  --lock-only --reproducible --output (Join-Path $sbom32 'boss4d.cdx.json') `
  --verify-attestation (Join-Path $sbom32 'boss4d.cdx.intoto.json')
if ($LASTEXITCODE -ne 0) { throw 'Verificação da atestação CycloneDX falhou.' }
& (Join-Path $win32 'Boss4D.exe') sbom --format spdx --strict --validate `
  --lock-only --reproducible --output (Join-Path $sbom32 'boss4d.spdx.json') `
  --verify-attestation (Join-Path $sbom32 'boss4d.spdx.intoto.json')
if ($LASTEXITCODE -ne 0) { throw 'Verificação da atestação SPDX falhou.' }

& (Join-Path $win32 'Boss4D.exe') sbom --format cyclonedx --strict --validate `
  --lock-only --reproducible --vex (Join-Path $workspace 'tests\fixtures\sbom\security.vex.json') `
  --output (Join-Path $sbom32 'boss4d.vex.cdx.json')
if ($LASTEXITCODE -ne 0) { throw 'Geração CycloneDX com VEX falhou.' }

docker run --rm -v "${sbom32}:/work" cyclonedx/cyclonedx-cli:latest validate `
  --input-file /work/boss4d.cdx.json --fail-on-errors
if ($LASTEXITCODE -ne 0) { throw 'Validação externa CycloneDX falhou.' }
docker run --rm -v "${sbom32}:/work" cyclonedx/cyclonedx-cli:latest validate `
  --input-file /work/boss4d.vex.cdx.json --fail-on-errors
if ($LASTEXITCODE -ne 0) { throw 'Validação externa CycloneDX VEX falhou.' }

$spdxTools = Join-Path $buildRoot 'spdx-tools'
$null = New-Item -ItemType Directory -Path $spdxTools
gh release download v2.0.7 --repo spdx/tools-java --pattern 'tools-java-2.0.7.zip' `
  --dir $spdxTools --clobber
if ($LASTEXITCODE -ne 0) { throw 'Download do SPDX tools-java falhou.' }
Expand-Archive -LiteralPath (Join-Path $spdxTools 'tools-java-2.0.7.zip') `
  -DestinationPath (Join-Path $spdxTools 'expanded') -Force
$spdxJar = Get-ChildItem -LiteralPath (Join-Path $spdxTools 'expanded') `
  -Filter '*jar-with-dependencies.jar' | Select-Object -First 1
if (-not $spdxJar) { throw 'JAR do SPDX tools-java não encontrado.' }
java -jar $spdxJar.FullName Verify (Join-Path $sbom32 'boss4d.spdx.json')
if ($LASTEXITCODE -ne 0) { throw 'Validação externa SPDX falhou.' }

Write-Host 'CI SBOM concluída: Win32/Win64, testes, reprodutibilidade e validadores externos.'
