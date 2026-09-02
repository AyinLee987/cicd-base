<#
.SYNOPSIS
  Build and run the cicd-base Spring Boot app locally (no Docker required).

.DESCRIPTION
  pom.xml pins java.version=23, but the bundled lombok 1.18.36 does not
  support newer JDKs (24/25) and fails to compile on them. JDK 17 works
  reliably, so this script forces JDK 17 for both build and run, overriding
  java.version via -Djava.version=17.

.PARAMETER JdkHome
  Path to a JDK 17 install. Defaults to the common Adoptium install path;
  pass your own if JDK 17 lives elsewhere.

.PARAMETER SkipBuild
  Skip `mvnw clean package` and just run the jar already in target/.

.PARAMETER Port
  App listen port (passed as --port=<Port>, read by D13revisionApplication).
  Default is whatever application.properties sets (8080).

.EXAMPLE
  .\run.ps1
.EXAMPLE
  .\run.ps1 -SkipBuild -Port 3000
#>
param(
    [string]$JdkHome = "C:\Program Files\Eclipse Adoptium\jdk-17.0.20.8-hotspot",
    [switch]$SkipBuild,
    [int]$Port
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot

if (-not (Test-Path "$JdkHome\bin\java.exe")) {
    Write-Error "JDK 17 not found at '$JdkHome'. Install one, or pass -JdkHome <path>."
    exit 1
}

$env:JAVA_HOME = $JdkHome
$env:PATH = "$JdkHome\bin;$env:PATH"

Write-Host "Using JDK:" -ForegroundColor Cyan
& "$JdkHome\bin\java.exe" -version

Set-Location $ProjectRoot

if (-not $SkipBuild) {
    Write-Host "`nBuilding (mvnw clean package -DskipTests -Djava.version=17)..." -ForegroundColor Cyan
    # NOTE: PowerShell 5.1 mis-splits dotted -D args (e.g. -Djava.version=17)
    # when passed to an external .cmd, so use --% to stop PS from parsing them.
    # (Requires us to already be in $ProjectRoot, since --% blocks $-expansion.)
    & .\mvnw.cmd --% clean package -DskipTests -Djava.version=17
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed (exit $LASTEXITCODE)."
        exit $LASTEXITCODE
    }
}

$jar = Get-ChildItem -Path "$ProjectRoot\target" -Filter "*.jar" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notlike "*sources*" } |
    Select-Object -First 1

if (-not $jar) {
    Write-Error "No jar found in target/. Run without -SkipBuild first."
    exit 1
}

$runArgs = @("-jar", $jar.FullName)
if ($Port) {
    $runArgs += "--port=$Port"
}

Write-Host "`nStarting $($jar.Name) ..." -ForegroundColor Cyan
& "$JdkHome\bin\java.exe" @runArgs
