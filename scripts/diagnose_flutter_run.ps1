param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$OutputDir,
    [string]$LogFile,
    [switch]$SkipRun
)

$ErrorActionPreference = "Stop"

function New-PatternRule {
    param(
        [string]$Id,
        [string]$Title,
        [string]$Regex,
        [string]$LikelyCause,
        [string[]]$Fixes
    )

    return [PSCustomObject]@{
        Id = $Id
        Title = $Title
        Regex = $Regex
        LikelyCause = $LikelyCause
        Fixes = $Fixes
    }
}

function Get-Matches {
    param(
        [string[]]$Lines,
        [string]$Regex
    )

    return ($Lines | Select-String -Pattern $Regex -CaseSensitive:$false)
}

if (-not $OutputDir -or $OutputDir.Trim() -eq "") {
    $OutputDir = Join-Path $ProjectRoot "build\diagnostics"
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

if (-not $LogFile -or $LogFile.Trim() -eq "") {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $LogFile = Join-Path $OutputDir "flutter_run_$timestamp.log"
}

$SummaryFile = [System.IO.Path]::ChangeExtension($LogFile, ".summary.md")

if (-not $SkipRun) {
    $flutter = Get-Command flutter -ErrorAction SilentlyContinue
    if (-not $flutter) {
        throw "Flutter command not found in PATH."
    }

    Write-Host "[diagnose] Running: flutter run -v --no-resident"
    Push-Location $ProjectRoot
    try {
        & flutter run -v --no-resident *> $LogFile
        $FlutterExitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
}
else {
    if (-not (Test-Path $LogFile)) {
        throw "Log file not found: $LogFile"
    }
    $FlutterExitCode = 0
}

$lines = Get-Content -Path $LogFile -ErrorAction Stop

$rules = @(
    (New-PatternRule -Id "maven-central" -Title "Direct Maven Central Download" -Regex "repo\.maven\.apache\.org|Downloading https://repo\.maven\.apache\.org" -LikelyCause "Buildscript repositories are still using Maven Central directly." -Fixes @(
        "Use mirrored repositories in android/settings.gradle.kts pluginManagement.repositories.",
        "Add dependencyResolutionManagement with RepositoriesMode.PREFER_SETTINGS.",
        "Inject mirrors in gradle.beforeProject buildscript.repositories to cover plugin buildscript blocks."
    )),
    (New-PatternRule -Id "flutter-engine-repo" -Title "Missing Flutter Engine Maven" -Regex "Could not find io\.flutter:(flutter_embedding_debug|x86_64_debug)" -LikelyCause "Flutter engine repositories are missing in settings repositories." -Fixes @(
        "Add flutter SDK engine repo: \$flutterSdkPath/bin/cache/artifacts/engine.",
        "Add https://storage.googleapis.com/download.flutter.io in dependencyResolutionManagement.repositories."
    )),
    (New-PatternRule -Id "kotlin-230" -Title "Kotlin 2.3.0 Drift" -Regex "kotlin-gradle-plugin[/\\]2\.3\.0|kotlin-gradle-plugin-2\.3\.0" -LikelyCause "A plugin (often webview_flutter_android newer version) upgraded Kotlin plugin unexpectedly." -Fixes @(
        "Pin webview_flutter to 4.11.0 and webview_flutter_android to 4.10.11.",
        "Run flutter pub get and verify lockfile versions."
    )),
    (New-PatternRule -Id "desugaring" -Title "Core Library Desugaring Required" -Regex "requires core library desugaring to be enabled|coreLibraryDesugaringEnabled|checkDebugAarMetadata" -LikelyCause "flutter_local_notifications or related dependency requires core library desugaring in app module." -Fixes @(
        "Set isCoreLibraryDesugaringEnabled = true in android/app/build.gradle.kts compileOptions.",
        "Add coreLibraryDesugaring(\"com.android.tools:desugar_jdk_libs:2.1.5\") in dependencies."
    )),
    (New-PatternRule -Id "kotlin-cache" -Title "Kotlin Incremental Cache Noise" -Regex "Could not close incremental caches|different roots" -LikelyCause "Kotlin incremental cache issues across mixed roots (pub cache + project) may be transient." -Fixes @(
        "Check whether app actually reached runtime markers before acting.",
        "If build still fails: flutter clean, remove build folder, then rerun."
    )),
    (New-PatternRule -Id "assemble-failed" -Title "Gradle Assemble Failed" -Regex "Error: Gradle task assembleDebug failed|FAILURE: Build failed" -LikelyCause "Build failed; inspect the first upstream error before this marker." -Fixes @(
        "Scroll upward to first Execution failed for task / Could not find / requires ... line.",
        "Fix root cause, then rerun diagnosis."
    ))
)

$findings = @()
foreach ($rule in $rules) {
    $matches = Get-Matches -Lines $lines -Regex $rule.Regex
    if ($matches.Count -gt 0) {
        $samples = @($matches | Select-Object -First 5 | ForEach-Object { $_.Line.Trim() })
        $findings += [PSCustomObject]@{
            Rule = $rule
            Count = $matches.Count
            Samples = $samples
        }
    }
}

$priority = @("desugaring", "flutter-engine-repo", "kotlin-230", "maven-central", "kotlin-cache", "assemble-failed")
$primary = $null
foreach ($id in $priority) {
    $hit = $findings | Where-Object { $_.Rule.Id -eq $id } | Select-Object -First 1
    if ($hit) {
        $primary = $hit
        break
    }
}

$runMarkers = @(
    "Flutter run key commands.",
    "A Dart VM Service on"
)

$runtimeReached = $false
foreach ($marker in $runMarkers) {
    if (($lines | Select-String -Pattern [regex]::Escape($marker) -Quiet)) {
        $runtimeReached = $true
        break
    }
}

$summary = New-Object System.Collections.Generic.List[string]
$summary.Add("# Flutter Run Diagnostic Summary")
$summary.Add("")
$summary.Add("- ProjectRoot: $ProjectRoot")
$summary.Add("- LogFile: $LogFile")
$summary.Add("- FlutterExitCode: $FlutterExitCode")
$summary.Add("- RuntimeReached: $runtimeReached")
$summary.Add("")

if ($primary) {
    $summary.Add("## Primary Suspect")
    $summary.Add("")
    $summary.Add("- $($primary.Rule.Title)")
    $summary.Add("- LikelyCause: $($primary.Rule.LikelyCause)")
    $summary.Add("- MatchCount: $($primary.Count)")
    $summary.Add("")
    $summary.Add("### Suggested Fixes")
    foreach ($fix in $primary.Rule.Fixes) {
        $summary.Add("- $fix")
    }
    $summary.Add("")
}
else {
    $summary.Add("## Primary Suspect")
    $summary.Add("")
    $summary.Add("- No known keyword pattern matched. Inspect tail logs manually.")
    $summary.Add("")
}

$summary.Add("## Matched Patterns")
$summary.Add("")
if ($findings.Count -eq 0) {
    $summary.Add("- None")
}
else {
    foreach ($f in $findings) {
        $summary.Add("### $($f.Rule.Title) [$($f.Rule.Id)]")
        $summary.Add("- MatchCount: $($f.Count)")
        $summary.Add("- LikelyCause: $($f.Rule.LikelyCause)")
        $summary.Add("- Samples:")
        foreach ($sample in $f.Samples) {
            $summary.Add("  - $sample")
        }
        $summary.Add("")
    }
}

$summary.Add("## Final Notes")
$summary.Add("")
$summary.Add("- If RuntimeReached=true, startup has succeeded even if there are warnings.")
$summary.Add("- If FlutterExitCode is non-zero and RuntimeReached=false, fix primary suspect first and rerun.")

$summary | Set-Content -Path $SummaryFile -Encoding UTF8

Write-Host "[diagnose] Log saved: $LogFile"
Write-Host "[diagnose] Summary saved: $SummaryFile"
if ($primary) {
    Write-Host "[diagnose] Primary suspect: $($primary.Rule.Title)"
}

exit $FlutterExitCode
