# Re-export the Web (HTML5) build into build\web for the LOCAL mobile test loop (no itch upload).
# After a code change: run this, then just REFRESH the phone browser (serve_web.ps1 keeps serving).
#   PS> .\tools\export_web.ps1
$ErrorActionPreference = "Stop"
$proj  = Split-Path $PSScriptRoot -Parent
$godot = "C:\Users\Troy Pepito\OneDrive\Desktop\Godot_v4.6.3_console.exe"
if (-not (Test-Path $godot)) {
    Write-Host "Godot not found at:`n  $godot`nEdit the `$godot path at the top of this script." -ForegroundColor Red
    exit 1
}
Write-Host "Exporting Web -> build\web ..." -ForegroundColor Cyan
& $godot --headless --path $proj --export-release "Web"
if ($LASTEXITCODE -eq 0) {
    Write-Host "`nDone. Refresh the phone browser to see the change." -ForegroundColor Green
} else {
    Write-Host "`nExport FAILED (exit $LASTEXITCODE)." -ForegroundColor Red
}
