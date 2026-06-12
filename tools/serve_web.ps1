# Serve the exported Web build to your PHONE over local Wi-Fi - NO itch upload needed.
#   1) run this once and leave it running:   PS> .\tools\serve_web.ps1
#   2) on the phone (same Wi-Fi) open the http://... URL it prints
#   3) after a code change run .\tools\export_web.ps1, then just refresh the phone
# First run, Windows may ask to allow Python through the firewall - click Allow (Private networks).
$proj = Split-Path $PSScriptRoot -Parent
$web  = Join-Path $proj "build\web"
if (-not (Test-Path (Join-Path $web "index.html"))) {
    Write-Host "No build\web\index.html yet - run .\tools\export_web.ps1 first." -ForegroundColor Yellow
    exit 1
}
$ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
       Where-Object { $_.IPAddress -like "192.168.*" -or $_.IPAddress -like "10.*" -or $_.IPAddress -like "172.*" } |
       Select-Object -First 1).IPAddress
if (-not $ip) { $ip = "<your-PC-LAN-IP, run ipconfig>" }
Write-Host "Serving: $web" -ForegroundColor Cyan
Write-Host "On your phone (same Wi-Fi) open:" -ForegroundColor Green
Write-Host "    http://${ip}:8000" -ForegroundColor Green
Write-Host "Ctrl+C to stop.`n" -ForegroundColor DarkGray
python -m http.server 8000 --bind 0.0.0.0 --directory $web
