# ============================================================================
# build.ps1 – iOS cross-compilation helper for Windows
# Requires: zig 0.14+ (bundles iOS SDK headers)
# ============================================================================

param(
    [switch]$Clean,
    [switch]$SyntaxOnly
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$zigExe = "zig.exe"

# Locate zig
if (!(Get-Command $zigExe -ErrorAction SilentlyContinue)) {
    # Check common install paths
    $paths = @(
        "$env:USERPROFILE\scoop\shims\zig.exe",
        "$env:USERPROFILE\.zig\zig.exe",
        "C:\zig\zig.exe"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { $zigExe = $p; break }
    }
    if (!(Test-Path $zigExe)) {
        Write-Error "zig not found. Install: scoop install zig or https://ziglang.org/download/"
        exit 1
    }
}

Write-Host "zig found at: $zigExe"

$srcFiles = @(
    "TweakEntry.mm",
    "Hooks.mm",
    "FloatingOverlay.mm"
)

$outDir = "$scriptDir\build"
if ($Clean -and (Test-Path $outDir)) { Remove-Item -Recurse -Force $outDir }
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

# ── Build flags ─────────────────────────────────────────────────────────────
$target = "aarch64-ios-none"
$mode = "ReleaseSmall"

$cflags = @(
    "-target", $target
    "-O$mode"
    "-I$scriptDir"
    "-fobjc-arc"
    "-fobjc-runtime=ios"
    "-fmodules"
    "-lc"
    "-lobjc"
)

$ldflags = @(
    "-framework", "UIKit",
    "-framework", "Foundation",
    "-framework", "CoreGraphics",
    "-framework", "QuartzCore"
)

$srcPaths = $srcFiles | ForEach-Object { "$scriptDir\$_" }

if ($SyntaxOnly) {
    # Just check C++ sources (skip .mm ObjC which needs SDK)
    $cppFiles = @("Hooks.mm")
    $cppPaths = $cppFiles | ForEach-Object { "$scriptDir\$_" }
    & $zigExe build-exe -target $target -fno-emit-bin $cppPaths --library c
    if ($LASTEXITCODE -eq 0) {
        Write-Host "C++ syntax OK" -ForegroundColor Green
    } else {
        Write-Host "C++ syntax ERRORS" -ForegroundColor Red
    }
    exit
}

# ── Compile ─────────────────────────────────────────────────────────────────
Write-Host "Compiling for $target ..."
& $zigExe build-lib `
    --name MalumMenu `
    $srcPaths `
    --cache-dir "$outDir\.zig-cache" `
    --output-dir $outDir `
    $cflags `
    $ldflags

if ($LASTEXITCODE -eq 0) {
    Write-Host "SUCCESS: $outDir\MalumMenu.dylib" -ForegroundColor Green
    Get-Item "$outDir\MalumMenu.dylib" | Select-Object Length, FullName
} else {
    Write-Host "FAILED (exit code: $LASTEXITCODE)" -ForegroundColor Red
}
