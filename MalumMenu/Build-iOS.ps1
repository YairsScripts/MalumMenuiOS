param(
    [string]$ZigPath = "C:\Users\Yairsabn\AppData\Local\zig\zig-x86_64-windows-0.16.0\zig.exe",
    [string]$ProjectDir = $PSScriptRoot
)

Remove-Item "$ProjectDir\*.o", "$ProjectDir\*.dylib", "$ProjectDir\*.a" -Force -ErrorAction SilentlyContinue
$freshCache = Join-Path $env:TEMP "zgc-$(Get-Random)"
$env:ZIG_GLOBAL_CACHE_DIR = $freshCache

Write-Output "Compiling..."
& $ZigPath build-lib -dynamic --name MalumMenu -target aarch64-macos-none `
    -I"$ProjectDir" -I"$ProjectDir\include" -I"$ProjectDir\sdks\iOS.sdk\usr\include" `
    -lc "$ProjectDir\frameworks\libExtra.tbd" `
    "$ProjectDir\TweakEntry.mm" "$ProjectDir\Hooks.mm" "$ProjectDir\FloatingOverlay.mm" 2>&1

if ($LASTEXITCODE -ne 0) { Write-Error "Build failed"; exit 1 }
$dylib = "$ProjectDir\libMalumMenu.dylib"
Write-Output "OK: $((Get-Item $dylib).Length) bytes"

python "$ProjectDir\patch_macho.py" $dylib 2>&1
if ($LASTEXITCODE -ne 0) { Write-Error "Patch failed"; exit 1 }

Remove-Item $freshCache -Recurse -Force -ErrorAction SilentlyContinue
exit 0