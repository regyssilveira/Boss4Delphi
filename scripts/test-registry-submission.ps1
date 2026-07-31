$ErrorActionPreference = 'Stop'
$validator = Join-Path $PSScriptRoot 'validate-registry-submission.ps1'
$workflow = Join-Path (Split-Path $PSScriptRoot) `
  '.github\workflows\registry-submission.yml'
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
  $workflowContent = Get-Content -LiteralPath $workflow -Raw
  if ($workflowContent -notmatch '-Submitter "\$\{\{ github\.actor \}\}"') {
    throw 'Registry workflow must bind validation to github.actor.'
  }
  if ($workflowContent -notmatch 'test-new-registry-submission\.ps1') {
    throw 'Registry workflow must test the submission generator.'
  }
  $fingerprint = '1234567890ABCDEF1234567890ABCDEF12345678'
  $publisherEntry = '{"id":"demo","displayName":"Demo","githubOwners":["demo-owner"],"repositories":["github.com/demo/"],"allowedSigners":["' + $fingerprint + '"]}'
  $publishers = '{"schemaVersion":1,"publishers":[' + $publisherEntry + ']}'
  Write-Utf8 (Join-Path $base 'registry\publishers.json') $publishers
  Write-Utf8 (Join-Path $current 'registry\publishers.json') $publishers
  $index = '{"schemaVersion":2,"sparse":["packages/demo.json"],"packages":[]}'
  Write-Utf8 (Join-Path $base 'registry\index-v2.json') $index
  Write-Utf8 (Join-Path $current 'registry\index-v2.json') $index
  $v1 = '{"schemaVersion":2,"packages":[{"name":"Demo","publisher":"demo","repository":"github.com/demo/package","signerFingerprint":"' + $fingerprint + '","versions":[{"version":"1.0.0","artifact":"https://example.test/demo.b4dpkg","sha256":"' + ('a' * 64) + '","signature":"https://example.test/demo.asc","provenance":"https://example.test/demo.intoto.json"}]}]}'
  Write-Utf8 (Join-Path $base 'registry\packages\demo.json') $v1
  Write-Utf8 (Join-Path $current 'registry\packages\demo.json') $v1

  & $validator -Root $current -BaseRoot $base `
    -ChangedFiles 'registry/packages/demo.json' -Submitter 'demo-owner'

  Expect-Failure {
    & $validator -Root $current -BaseRoot $base `
      -ChangedFiles 'registry/packages/demo.json' -Submitter 'attacker'
  } 'not authorized'

  $legacyPublishers = $publishers.Replace(
    ',"githubOwners":["demo-owner"]', '')
  Write-Utf8 (Join-Path $base 'registry\publishers.json') $legacyPublishers
  & $validator -Root $current -BaseRoot $base `
    -ChangedFiles 'registry/publishers.json' -Submitter 'demo'
  Expect-Failure {
    & $validator -Root $current -BaseRoot $base `
      -ChangedFiles 'registry/publishers.json' -Submitter 'attacker'
  } 'not authorized'
  Write-Utf8 (Join-Path $base 'registry\publishers.json') $publishers

  $escalatedPublishers = $publishers.Replace(
    '"githubOwners":["demo-owner"]',
    '"githubOwners":["demo-owner","attacker"]')
  Write-Utf8 (Join-Path $current 'registry\publishers.json') $escalatedPublishers
  Expect-Failure {
    & $validator -Root $current -BaseRoot $base `
      -ChangedFiles @('registry/publishers.json', 'registry/packages/demo.json') `
      -Submitter 'attacker'
  } 'not authorized'
  Write-Utf8 (Join-Path $current 'registry\publishers.json') $publishers

  $newPublisher = '{"id":"new-publisher","displayName":"New Publisher","githubOwners":["new-owner"],"repositories":["github.com/new-owner/"],"allowedSigners":[]}'
  $withNewPublisher = '{"schemaVersion":1,"publishers":[' +
    $publisherEntry + ',' + $newPublisher + ']}'
  Write-Utf8 (Join-Path $current 'registry\publishers.json') $withNewPublisher
  & $validator -Root $current -BaseRoot $base `
    -ChangedFiles 'registry/publishers.json' -Submitter 'new-owner'
  Expect-Failure {
    & $validator -Root $current -BaseRoot $base `
      -ChangedFiles 'registry/publishers.json' -Submitter 'attacker'
  } 'not authorized'
  Write-Utf8 (Join-Path $current 'registry\publishers.json') $publishers

  Write-Utf8 (Join-Path $current 'registry\index-v2.json') `
    '{"schemaVersion":2,"sparse":[],"packages":[]}'
  Expect-Failure {
    & $validator -Root $current -BaseRoot $base `
      -ChangedFiles 'registry/index-v2.json' -Submitter 'demo-owner'
  } 'cannot remove sparse entry'
  Write-Utf8 (Join-Path $current 'registry\index-v2.json') $index

  $tampered = $v1.Replace(('a' * 64), ('b' * 64))
  Write-Utf8 (Join-Path $current 'registry\packages\demo.json') $tampered
  Expect-Failure {
    & $validator -Root $current -BaseRoot $base `
      -ChangedFiles 'registry/packages/demo.json' -Submitter 'demo-owner'
  } 'modifies immutable version'

  $outside = $v1.Replace('github.com/demo/package', 'github.com/other/package')
  Write-Utf8 (Join-Path $current 'registry\packages\demo.json') $outside
  Expect-Failure {
    & $validator -Root $current -BaseRoot $base `
      -ChangedFiles 'registry/packages/demo.json' -Submitter 'demo-owner'
  } 'outside the publisher scope'

  $unknownSigner = $v1.Replace($fingerprint, ('F' * 40))
  Write-Utf8 (Join-Path $current 'registry\packages\demo.json') $unknownSigner
  Expect-Failure {
    & $validator -Root $current -BaseRoot $base `
      -ChangedFiles 'registry/packages/demo.json' -Submitter 'demo-owner'
  } 'signer fingerprint is not authorized'

  $unsigned = $v1.Replace('"signature":"https://example.test/demo.asc",', '')
  Write-Utf8 (Join-Path $current 'registry\packages\demo.json') $unsigned
  Expect-Failure {
    & $validator -Root $current -BaseRoot $base `
      -ChangedFiles 'registry/packages/demo.json' -Submitter 'demo-owner'
  } 'requires signature and provenance'

  $gitRoot = Join-Path $temp 'git-base-ref'
  New-Item -ItemType Directory -Force $gitRoot | Out-Null
  Write-Utf8 (Join-Path $gitRoot 'registry\publishers.json') $publishers
  Write-Utf8 (Join-Path $gitRoot 'registry\index-v2.json') `
    '{"schemaVersion":2,"sparse":[],"packages":[]}'
  & git -C $gitRoot init --quiet
  & git -C $gitRoot config user.name 'Registry Test'
  & git -C $gitRoot config user.email 'registry-test@example.invalid'
  & git -C $gitRoot add registry
  & git -C $gitRoot commit --quiet -m 'base registry'
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to create BaseRef regression fixture.'
  }
  Write-Utf8 (Join-Path $gitRoot 'registry\index-v2.json') $index
  Write-Utf8 (Join-Path $gitRoot 'registry\packages\demo.json') $v1
  & $validator -Root $gitRoot -BaseRef HEAD `
    -ChangedFiles @('registry/index-v2.json', 'registry/packages/demo.json') `
    -Submitter 'demo-owner'

  Write-Output 'Registry submission validator tests: OK'
} finally {
  if (Test-Path -LiteralPath $temp) {
    Remove-Item -LiteralPath $temp -Recurse -Force
  }
}
