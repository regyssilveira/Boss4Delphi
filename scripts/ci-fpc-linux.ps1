param(
  [string]$Image = 'fpc-test:latest'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$linuxScript = @'
set -eu
mkdir -p .fpc-build
fpc -B -Fu./src/Posix -FE./.fpc-build -FU./.fpc-build ./src/Posix/boss4d.lpr
fpc -B -Fu./src/Posix -Fu./tests/posix -FE./.fpc-build -FU./.fpc-build ./tests/posix/Boss4DPosixTests.lpr
./.fpc-build/Boss4DPosixTests --all --format=plain
./.fpc-build/boss4d version
./.fpc-build/boss4d platform | grep -qx linux
./.fpc-build/boss4d search Dext --registry=./registry/index-v2.json | grep -q Dext
./.fpc-build/boss4d info Horse --registry=./registry/index-v2.json | grep -q 'name: Horse'
'@
$linuxScript = $linuxScript.Replace("`r`n", "`n")
docker run --rm -v "${root}:/work" -w /work $Image sh -lc $linuxScript
if ($LASTEXITCODE -ne 0) {
  throw "FPC Linux CI failed with exit code $LASTEXITCODE."
}
