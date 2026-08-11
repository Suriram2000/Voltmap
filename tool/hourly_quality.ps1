$ErrorActionPreference = 'Stop'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'

$flutterCandidates = @(
  $env:VOLTMAP_FLUTTER,
  'C:\Users\ndyas\Documents\Codex\f\bin\flutter.bat',
  (Get-Command flutter.bat -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1)
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

$flutter = $flutterCandidates | Select-Object -First 1
if (-not $flutter) {
  throw 'Flutter was not found. Set VOLTMAP_FLUTTER to the Flutter executable path.'
}

$mobileDirectory = [System.IO.Path]::GetFullPath(
  (Join-Path $PSScriptRoot '..\mobile')
)
Set-Location -LiteralPath $mobileDirectory

function Invoke-FlutterStep {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  & $flutter @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Flutter step failed: $($Arguments -join ' ')"
  }
}

Invoke-FlutterStep @('pub', 'get', '--offline')
Invoke-FlutterStep @('analyze', '--no-pub')
Invoke-FlutterStep @('test', '--coverage', '--no-pub')
Invoke-FlutterStep @(
  'build',
  'web',
  '--release',
  '--base-href',
  '/',
  '--no-pub'
)

Write-Output 'VoltMapEV hourly quality suite passed.'
