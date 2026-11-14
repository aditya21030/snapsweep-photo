param(
    [string]$InterstitialAdUnitId = 'ca-app-pub-8510502760785545/8753913671',
    [string]$NativeAdUnitId = '',
    [switch]$AppBundle
)
$ErrorActionPreference = 'Stop'
foreach ($unit in @($InterstitialAdUnitId, $NativeAdUnitId)) {
    if ($unit -and $unit -notmatch '^ca-app-pub-\d{16}/\d{10}$') { throw 'Invalid AdMob unit ID format.' }
}
if ($InterstitialAdUnitId -and $NativeAdUnitId -and $InterstitialAdUnitId -eq $NativeAdUnitId) {
    throw 'Native and interstitial placements need separate unit IDs.'
}
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildTemp = Join-Path $projectRoot 'build\runtime-tmp'
New-Item -ItemType Directory -Path $buildTemp -Force | Out-Null
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
$previousJavaOptions = $env:JAVA_TOOL_OPTIONS
$previousGradleOptions = $env:GRADLE_OPTS
$previousGradleUserHome = $env:GRADLE_USER_HOME
Push-Location -LiteralPath $projectRoot
try {
    $env:TEMP = $buildTemp
    $env:TMP = $buildTemp
    $env:GRADLE_USER_HOME = 'D:\.gradle'
    $env:JAVA_TOOL_OPTIONS = ($previousJavaOptions + ' -Djava.io.tmpdir="' + $buildTemp + '"').Trim()
    $env:GRADLE_OPTS = ($previousGradleOptions + ' -Dorg.gradle.daemon=false').Trim()
    $artifactType = if ($AppBundle) { 'appbundle' } else { 'apk' }
    $buildArguments = @('build', $artifactType, '--release', '--no-pub')
    if ($InterstitialAdUnitId) { $buildArguments += "--dart-define=ADMOB_INTERSTITIAL_AD_UNIT_ID=$InterstitialAdUnitId" }
    if ($NativeAdUnitId) { $buildArguments += "--dart-define=ADMOB_NATIVE_AD_UNIT_ID=$NativeAdUnitId" }
    if (!$InterstitialAdUnitId -or !$NativeAdUnitId) { Write-Output 'Unconfigured production placements will stay disabled.' }
    & flutter @buildArguments
    if ($LASTEXITCODE -ne 0) { throw "Release build failed with exit code $LASTEXITCODE" }
} finally {
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
    $env:JAVA_TOOL_OPTIONS = $previousJavaOptions
    $env:GRADLE_OPTS = $previousGradleOptions
    $env:GRADLE_USER_HOME = $previousGradleUserHome
    Pop-Location
}
