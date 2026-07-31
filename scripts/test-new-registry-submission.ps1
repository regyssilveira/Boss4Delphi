$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$generator = Join-Path $PSScriptRoot 'new-registry-submission.ps1'
$validator = Join-Path $PSScriptRoot 'validate-registry-submission.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) `
  ('boss4d-registry-generator-' + [Guid]::NewGuid().ToString('N'))
$base = Join-Path $temp 'base'
$current = Join-Path $temp 'current'

function Write-Utf8([string]$Path, [string]$Content) {
  New-Item -ItemType Directory -Force (Split-Path $Path) | Out-Null
  [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

function Expect-Failure([scriptblock]$Action, [string]$Pattern) {
  try {
    & $Action
    throw "Expected failure: $Pattern"
  } catch {
    if ($_.Exception.Message -notmatch $Pattern) { throw }
  }
}

try {
  $fingerprint = '1234567890ABCDEF1234567890ABCDEF12345678'
  $publishers = '{"schemaVersion":1,"publishers":[{"id":"demo","displayName":"Demo","githubOwners":["demo-owner"],"repositories":["github.com/demo/"],"allowedSigners":["' + $fingerprint + '"]}]}'
  $index = '{"schemaVersion":2,"includes":[],"sparse":[],"packages":[]}'
  foreach ($root in @($base, $current)) {
    Write-Utf8 (Join-Path $root 'registry\publishers.json') $publishers
    Write-Utf8 (Join-Path $root 'registry\index-v2.json') $index
  }

  & $generator -Root $current -PackageName 'Demo Package' -Publisher demo `
    -Repository 'github.com/demo/package' -SignerFingerprint $fingerprint `
    -Version '1.0.0' -Artifact 'https://example.test/demo.b4dpkg' `
    -Sha256 ('A' * 64) -Signature 'https://example.test/demo.b4dpkg.asc' `
    -Provenance 'https://example.test/demo.b4dpkg.intoto.json' `
    -Description 'Demo package' -License MIT

  $packagePath = Join-Path $current 'registry\packages\demo-package.json'
  if (-not (Test-Path -LiteralPath $packagePath)) {
    throw 'Generator did not create normalized package metadata.'
  }
  $package = Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json
  $generatedIndex = Get-Content -LiteralPath `
    (Join-Path $current 'registry\index-v2.json') -Raw | ConvertFrom-Json
  if ($package.packages[0].versions[0].sha256 -cne ('a' * 64) -or
      @($generatedIndex.sparse) -notcontains 'packages/demo-package.json') {
    throw 'Generator did not normalize evidence or update sparse metadata.'
  }
  & $validator -Root $current -BaseRoot $base `
    -ChangedFiles @('registry/packages/demo-package.json',
      'registry/index-v2.json') -Submitter demo-owner

  Expect-Failure {
    & $generator -Root $current -PackageName 'Demo Package' -Publisher demo `
      -Repository 'github.com/demo/package' -SignerFingerprint $fingerprint `
      -Version '1.0.1' -Artifact 'https://example.test/demo.b4dpkg' `
      -Sha256 ('b' * 64) -Signature 'https://example.test/demo.asc' `
      -Provenance 'https://example.test/demo.intoto.json'
  } 'already exists'

  Expect-Failure {
    & $generator -Root $base -PackageName Demo -Publisher unknown `
      -Repository 'github.com/demo/package' -SignerFingerprint $fingerprint `
      -Version '1.0.0' -Artifact 'https://example.test/demo.b4dpkg' `
      -Sha256 ('b' * 64) -Signature 'https://example.test/demo.asc' `
      -Provenance 'https://example.test/demo.intoto.json'
  } 'not registered'

  Expect-Failure {
    & $generator -Root $base -PackageName Demo -Publisher demo `
      -Repository 'github.com/demo/package' -SignerFingerprint $fingerprint `
      -Version '1.0.0' -Artifact 'http://example.test/demo.b4dpkg' `
      -Sha256 ('b' * 64) -Signature 'https://example.test/demo.asc' `
      -Provenance 'https://example.test/demo.intoto.json'
  } 'absolute HTTPS'

  Write-Output 'Registry submission generator tests: OK'
} finally {
  if (Test-Path -LiteralPath $temp) {
    Remove-Item -LiteralPath $temp -Recurse -Force
  }
}
