$ErrorActionPreference = 'Stop'
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$ownersPath = Join-Path $workspace '.github\CODEOWNERS'
$templatePath = Join-Path $workspace `
  '.github\ISSUE_TEMPLATE\registry-package-submission.yml'
$workflowPath = Join-Path $workspace `
  '.github\workflows\registry-submission.yml'

foreach ($path in @($ownersPath, $templatePath, $workflowPath)) {
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

Write-Output 'Registry community governance contract: OK'

