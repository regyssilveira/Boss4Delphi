[CmdletBinding()]
param([string]$Image = 'fpc-test:latest')

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$script = @'
set -eu
rm -rf .release-test
mkdir -p .release-test/build .release-test/extracted
fpc -B -Fu./src/Posix -FE./.release-test/build -oboss4d ./src/Posix/boss4d.lpr
chmod 755 .release-test/build/boss4d
tar -C .release-test/build -czf .release-test/boss4d-linux-x86_64.tar.gz boss4d
(cd .release-test && sha256sum boss4d-linux-x86_64.tar.gz > SHA256SUMS.txt)
(cd .release-test && sha256sum -c SHA256SUMS.txt)
tar -C .release-test/extracted -xzf .release-test/boss4d-linux-x86_64.tar.gz
test -x .release-test/extracted/boss4d
.release-test/extracted/boss4d version | grep -q '^v'
.release-test/extracted/boss4d platform | grep -qx linux
tar -tzf .release-test/boss4d-linux-x86_64.tar.gz | grep -qx boss4d
tar -tzf .release-test/boss4d-linux-x86_64.tar.gz | wc -l | grep -qx 1
'@
$script = $script.Replace("`r`n", "`n")
docker run --rm -v "${root}:/work" -w /work $Image sh -lc $script
if ($LASTEXITCODE -ne 0) {
  throw "Linux release artifact test failed with exit code $LASTEXITCODE."
}
Write-Output 'Linux release artifact: OK'
