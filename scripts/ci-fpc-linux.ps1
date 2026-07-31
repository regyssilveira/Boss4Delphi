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
rm -rf .fpc-build/package-smoke
mkdir -p .fpc-build/package-smoke/project
(cd .fpc-build/package-smoke/project && /work/.fpc-build/boss4d init && /work/.fpc-build/boss4d package install Demo --registry /work/tests/fixtures/package-posix/index.json --platform linux --no-source-fallback)
test -f .fpc-build/package-smoke/project/modules/demo/src/verified.pas
grep -q registry-artifact .fpc-build/package-smoke/project/boss-lock.json
(cd .fpc-build/package-smoke/project && /work/.fpc-build/boss4d dependencies | grep -q 'example.test/demo@1.0.0')
(cd .fpc-build/package-smoke/project && /work/.fpc-build/boss4d why demo | grep -q 'root ->')
(cd .fpc-build/package-smoke/project && /work/.fpc-build/boss4d install --json > progress.json)
grep -q operationId .fpc-build/package-smoke/project/progress.json
grep -q completion .fpc-build/package-smoke/project/progress.json
./.fpc-build/boss4d unknown-command >/dev/null 2>&1 || test $? -eq 2
./.fpc-build/boss4d doctor > .fpc-build/doctor.txt 2>&1 || true
grep -q git .fpc-build/doctor.txt
grep -q 'OK sha256:' .fpc-build/doctor.txt
(cd .fpc-build/package-smoke/project && /work/.fpc-build/boss4d sbom --format cyclonedx --lock-only --strict --validate --reproducible --vex /work/tests/fixtures/package-posix/vex.json --output sbom.cdx.json)
(cd .fpc-build/package-smoke/project && /work/.fpc-build/boss4d sbom --format spdx --lock-only --strict --validate --reproducible --output sbom.spdx.json)
(cd .fpc-build/package-smoke/project && /work/.fpc-build/boss4d publish --official --dry-run --allow-dirty --skip-tests --publisher smoke-publisher --repository github.com/example/demo --fingerprint aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa --sign test-key --artifact-url https://github.com/example/demo/releases/download/v1.0.0/demo-1.0.0.b4dpkg > official-publish.txt)
grep -q 'official dry-run approved' .fpc-build/package-smoke/project/official-publish.txt
test ! -e .fpc-build/package-smoke/project/dist/demo-1.0.0.b4dpkg
grep -q CycloneDX .fpc-build/package-smoke/project/sbom.cdx.json
grep -q CVE-2099-0001 .fpc-build/package-smoke/project/sbom.cdx.json
grep -q SPDX-2.3 .fpc-build/package-smoke/project/sbom.spdx.json
(cd .fpc-build/package-smoke/project && /work/.fpc-build/boss4d audit --offline > audit.txt)
grep -q 'audited packages' .fpc-build/package-smoke/project/audit.txt
(cd .fpc-build/package-smoke/project && /work/.fpc-build/boss4d doc --no-dependencies -o docs-api > doc.txt)
test -f .fpc-build/package-smoke/project/docs-api/index.html
test -f .fpc-build/package-smoke/project/docs-api/search-index.json
grep -q 'documented symbols' .fpc-build/package-smoke/project/doc.txt
(cd .fpc-build/package-smoke/project && /work/.fpc-build/boss4d publish --dry-run --allow-dirty --skip-tests --output publish.json)
grep -q '"artifact"' .fpc-build/package-smoke/project/publish.json
grep -q '"content"' .fpc-build/package-smoke/project/publish.json
rm -rf .fpc-build/tool-home
BOSS_HOME=/work/.fpc-build/tool-home ./.fpc-build/boss4d tool install -g /work/tests/fixtures/tool-posix --name hello
/work/.fpc-build/tool-home/bin/hello | grep -q 'Boss4D global tool'
BOSS_HOME=/work/.fpc-build/tool-home ./.fpc-build/boss4d tool list | grep -q hello
BOSS_HOME=/work/.fpc-build/tool-home ./.fpc-build/boss4d tool uninstall hello
test ! -f .fpc-build/tool-home/bin/hello
'@
$linuxScript = $linuxScript.Replace("`r`n", "`n")
docker run --rm -v "${root}:/work" -w /work $Image sh -lc $linuxScript
if ($LASTEXITCODE -ne 0) {
  throw "FPC Linux CI failed with exit code $LASTEXITCODE."
}
