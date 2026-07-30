param(
  [string]$Boss4D = '.\dist\bin\boss4d.exe',
  [int]$Iterations = 5
)

$ErrorActionPreference = 'Stop'
if ($Iterations -lt 2) { throw 'Iterations must be at least 2.' }
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$exe = (Resolve-Path (Join-Path $root $Boss4D)).Path
$outputDir = Join-Path $root 'scratch\benchmark-pack'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$digests = [System.Collections.Generic.List[string]]::new()
$times = [System.Collections.Generic.List[double]]::new()
try {
  for ($i = 1; $i -le $Iterations; $i++) {
    $output = Join-Path $outputDir "run-$i.b4dpkg"
    $watch = [Diagnostics.Stopwatch]::StartNew()
    & $exe pack --output $output | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "pack failed at iteration $i" }
    $watch.Stop()
    $times.Add($watch.Elapsed.TotalMilliseconds)
    $digests.Add((Get-FileHash -Algorithm SHA256 -LiteralPath $output).Hash.ToLower())
  }
  if (($digests | Select-Object -Unique).Count -ne 1) {
    throw 'Determinism regression: pack digests differ.'
  }
  [ordered]@{
    schemaVersion = 1
    benchmark = 'boss4d-pack'
    iterations = $Iterations
    digest = $digests[0]
    minMs = ($times | Measure-Object -Minimum).Minimum
    averageMs = ($times | Measure-Object -Average).Average
    maxMs = ($times | Measure-Object -Maximum).Maximum
  } | ConvertTo-Json
}
finally {
  if (Test-Path -LiteralPath $outputDir) {
    Remove-Item -LiteralPath $outputDir -Recurse -Force
  }
}
