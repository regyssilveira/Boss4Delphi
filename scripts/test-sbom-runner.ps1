[CmdletBinding()]
param(
  [string]$BdsRoot = $env:BOSS4D_BDS_ROOT,
  [switch]$RequireDockerDaemon
)

$ErrorActionPreference = 'Stop'

if (-not $IsWindows -and $PSVersionTable.PSEdition -eq 'Core') {
  throw 'O runner SBOM precisa executar no Windows.'
}

if ([string]::IsNullOrWhiteSpace($BdsRoot)) {
  $BdsRoot = (Get-ItemProperty -Path 'HKCU:\Software\Embarcadero\BDS\37.0' `
    -Name RootDir -ErrorAction SilentlyContinue).RootDir
}
$rsvars = if ([string]::IsNullOrWhiteSpace($BdsRoot)) { $null } else {
  Join-Path $BdsRoot 'bin\rsvars.bat'
}
if (-not $rsvars -or -not (Test-Path -LiteralPath $rsvars)) {
  throw 'Delphi 13 nao encontrado. Defina BOSS4D_BDS_ROOT ou configure BDS 37.0 no registro do usuario do runner.'
}

foreach ($tool in @('docker', 'gh', 'java')) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    throw "Ferramenta obrigatoria ausente no runner: $tool"
  }
}

& cmd.exe /d /c "call `"$rsvars`" && where dcc32 && where dcc64"
if ($LASTEXITCODE -ne 0) {
  throw 'dcc32/dcc64 nao ficaram disponiveis depois de executar rsvars.bat.'
}

if ($RequireDockerDaemon) {
  docker info --format '{{.ServerVersion}}' | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Docker esta instalado, mas o daemon nao esta acessivel.' }
}

Write-Host "Runner SBOM pronto. BDS_ROOT=$BdsRoot"
java -version
docker --version
gh --version | Select-Object -First 1
