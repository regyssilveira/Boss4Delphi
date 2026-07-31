$ErrorActionPreference = 'Stop'
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$ownersPath = Join-Path $workspace '.github\CODEOWNERS'
$templatePath = Join-Path $workspace `
  '.github\ISSUE_TEMPLATE\registry-package-submission.yml'
$workflowPath = Join-Path $workspace `
  '.github\workflows\registry-submission.yml'
$publishersPath = Join-Path $workspace 'registry\publishers.json'

foreach ($path in @($ownersPath, $templatePath, $workflowPath,
    $publishersPath)) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Registry community governance file is missing: $path"
  }
}

$owners = Get-Content -LiteralPath $ownersPath -Raw
foreach ($rule in @(
    '/registry/ @regyssilveira',
    '/scripts/*registry* @regyssilveira',
    '/.github/workflows/registry-*.yml @regyssilveira',
    '/.github/ISSUE_TEMPLATE/registry-package-submission.yml @regyssilveira')) {
  if (-not $owners.Contains($rule)) {
    throw "CODEOWNERS does not protect Registry surface: $rule"
  }
}

$template = Get-Content -LiteralPath $templatePath -Raw
foreach ($required in @(
    'id: package',
    'id: repository',
    'id: publisher',
    'id: version',
    'id: license',
    'id: compatibility',
    'id: evidence',
    'explicit maintainer approval',
    'private keys',
    'required: true')) {
  if (-not $template.Contains($required)) {
    throw "Registry submission template is missing: $required"
  }
}

$workflow = Get-Content -LiteralPath $workflowPath -Raw
foreach ($required in @(
    'contents: read',
    './scripts/validate-registry-submission.ps1',
    './scripts/test-registry-community-governance.ps1')) {
  if (-not $workflow.Contains($required)) {
    throw "Registry workflow is missing governance control: $required"
  }
}
foreach ($forbidden in @('pull_request_target:', 'contents: write')) {
  if ($workflow.Contains($forbidden)) {
    throw "Registry workflow uses unsafe permission or trigger: $forbidden"
  }
}

$publishers = Get-Content -LiteralPath $publishersPath -Raw |
  ConvertFrom-Json
$boss4dPublisher = @($publishers.publishers |
  Where-Object { $_.id -eq 'boss4d' })
if ($boss4dPublisher.Count -ne 1) {
  throw 'Boss4D publisher identity is missing or duplicated.'
}
$publisherDirectory = Split-Path -Parent $publishersPath
$publicKeyReference = [string]$boss4dPublisher[0].publicKey
$publicKeyPath = [IO.Path]::GetFullPath(
  (Join-Path $publisherDirectory $publicKeyReference))
$registryRoot = [IO.Path]::GetFullPath((Join-Path $workspace 'registry'))
if (-not $publicKeyPath.StartsWith(
    $registryRoot + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase) -or
    -not (Test-Path -LiteralPath $publicKeyPath -PathType Leaf)) {
  throw 'Boss4D publisher public key must remain inside the Registry.'
}
$gpg = Get-Command gpg -ErrorAction SilentlyContinue
$gpgPath = if ($null -ne $gpg) { $gpg.Source } else { '' }
if ($null -eq $gpg) {
  $bundledGpg = Join-Path $env:ProgramFiles 'Git\usr\bin\gpg.exe'
  if (Test-Path -LiteralPath $bundledGpg -PathType Leaf) {
    $gpgPath = $bundledGpg
  }
}
if ([string]::IsNullOrWhiteSpace($gpgPath)) {
  throw 'GnuPG is required to validate the Registry public key.'
}
$gpgArguments = @(
  '--batch',
  '--with-colons',
  '--show-keys',
  '--with-fingerprint',
  $publicKeyPath
)
$gpgOutput = & $gpgPath @gpgArguments 2>$null
$keyFingerprints = @($gpgOutput |
  Where-Object { $_ -like 'fpr:*' } |
  ForEach-Object { ($_ -split ':')[9] })
if ($LASTEXITCODE -ne 0 -or $keyFingerprints.Count -eq 0) {
  throw 'Boss4D Registry public key cannot be parsed by GnuPG.'
}
$primaryFingerprint = $keyFingerprints[0]
if (@($boss4dPublisher[0].allowedSigners) -notcontains
    $primaryFingerprint) {
  throw 'Boss4D public key fingerprint is not an allowed signer.'
}

Write-Output 'Registry community governance contract: OK'
