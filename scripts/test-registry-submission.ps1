$ErrorActionPreference = 'Stop'
$validator = Join-Path $PSScriptRoot 'validate-registry-submission.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('boss4d-registry-test-' + [guid]::NewGuid())
$base = Join-Path $temp 'base'
$current = Join-Path $temp 'current'

function Write-Utf8([string]$Path, [string]$Content) {
  New-Item -ItemType Directory -Force (Split-Path $Path) | Out-Null
  [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

function Expect-Failure([scriptblock]$Action, [string]$Pattern) {
  try {
    & $Action
    throw "Expected validation failure: $Pattern"
  } catch {
    if ($_.Exception.Message -notmatch $Pattern) { throw }
  }
}

try {
  $fingerprint = '1234567890ABCDEF1234567890ABCDEF12345678'
  $publishers = '{"schemaVersion":1,"publishers":[{"id":"demo","displayName":"Demo","repositories":["github.com/demo/"],"allowedSigners":["' + $fingerprint + '"]}]}'
  Write-Utf8 (Join-Path $base 'registry\publishers.json') $publishers
  Write-Utf8 (Join-Path $current 'registry\publishers.json') $publishers
  $index = '{"schemaVersion":2,"sparse":["packages/demo.json"],"packages":[]}'
  Write-Utf8 (Join-Path $base 'registry\index-v2.json') $index
  Write-Utf8 (Join-Path $current 'registry\index-v2.json') $index
  $v1 = '{"schemaVersion":2,"packages":[{"name":"Demo","publisher":"demo","repository":"github.com/demo/package","signerFingerprint":"' + $fingerprint + '","versions":[{"version":"1.0.0","artifact":"https://example.test/demo.b4dpkg","sha256":"' + ('a' * 64) + '","signature":"https://example.test/demo.asc","provenance":"https://example.test/demo.intoto.json"}]}]}'
  Write-Utf8 (Join-Path $base 'registry\packages\demo.json') $v1
  Write-Utf8 (Join-Path $current 'registry\packages\demo.json') $v1

  & $validator -Root $current -BaseRoot $base -ChangedFiles 'registry/packages/demo.json'

  $tampered = $v1.Replace(('a' * 64), ('b' * 64))
  Write-Utf8 (Join-Path $current 'registry\packages\demo.json') $tampered
  Expect-Failure {
    & $validator -Root $current -BaseRoot $base -ChangedFiles 'registry/packages/demo.json'
  } 'modifies immutable version'

  $outside = $v1.Replace('github.com/demo/package', 'github.com/other/package')
  Write-Utf8 (Join-Path $current 'registry\packages\demo.json') $outside
  Expect-Failure {
    & $validator -Root $current -BaseRoot $base -ChangedFiles 'registry/packages/demo.json'
  } 'outside the publisher scope'

  $unknownSigner = $v1.Replace($fingerprint, ('F' * 40))
  Write-Utf8 (Join-Path $current 'registry\packages\demo.json') $unknownSigner
  Expect-Failure {
    & $validator -Root $current -BaseRoot $base -ChangedFiles 'registry/packages/demo.json'
  } 'signer fingerprint is not authorized'

  $unsigned = $v1.Replace('"signature":"https://example.test/demo.asc",', '')
  Write-Utf8 (Join-Path $current 'registry\packages\demo.json') $unsigned
  Expect-Failure {
    & $validator -Root $current -BaseRoot $base -ChangedFiles 'registry/packages/demo.json'
  } 'requires signature and provenance'

  Write-Output 'Registry submission validator tests: OK'
} finally {
  if (Test-Path -LiteralPath $temp) {
    Remove-Item -LiteralPath $temp -Recurse -Force
  }
}
