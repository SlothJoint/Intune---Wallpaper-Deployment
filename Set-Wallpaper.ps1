<#
  Set-Wallpaper.ps1
  Copies wallpaper.jpg from the package to the user's profile and applies it as the desktop background.
  Runs in USER context (Intune install behaviour = User). No admin rights or reboot needed.

  To roll out a NEW image later: replace wallpaper.jpg in the package, increase $Version here and in
  Detect-Wallpaper.ps1 / Remove-Wallpaper.ps1, rebuild the .intunewin and upload it to the app.
#>

### Settings ###
$Version   = '1'
$SourceImg = Join-Path $PSScriptRoot 'wallpaper.jpg'
$DestDir   = Join-Path $env:LOCALAPPDATA 'CorporateWallpaper'
$DestImg   = Join-Path $DestDir ("wallpaper-v{0}.jpg" -f $Version)
$LogFile   = Join-Path $DestDir 'wallpaper.log'

# WallpaperStyle: 10 = Fill, 6 = Fit, 2 = Stretch, 0 = Center (TileWallpaper 0), 22 = Span
$WallpaperStyle = '10'
$TileWallpaper  = '0'

$ErrorActionPreference = 'Stop'

function Write-Log($msg) {
    try { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg" | Out-File -FilePath $LogFile -Append -Encoding utf8 } catch {}
}

Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public class WallpaperNative {
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

try {
    if (-not (Test-Path $DestDir)) { New-Item -Path $DestDir -ItemType Directory -Force | Out-Null }
    Write-Log "=== Set wallpaper v$Version for $env:USERNAME ==="

    if (-not (Test-Path $SourceImg)) { throw "wallpaper.jpg not found in package at $SourceImg" }

    # Remove older versions of the image
    Get-ChildItem -Path $DestDir -Filter 'wallpaper-v*.jpg' -File | Where-Object { $_.FullName -ne $DestImg } |
        Remove-Item -Force -ErrorAction SilentlyContinue

    Copy-Item -Path $SourceImg -Destination $DestImg -Force
    Write-Log "Copied image to $DestImg"

    # Persist for the user
    $desktopKey = 'HKCU:\Control Panel\Desktop'
    Set-ItemProperty -Path $desktopKey -Name WallPaper      -Value $DestImg
    Set-ItemProperty -Path $desktopKey -Name WallpaperStyle -Value $WallpaperStyle
    Set-ItemProperty -Path $desktopKey -Name TileWallpaper  -Value $TileWallpaper

    # Apply to the running session (SPI_SETDESKWALLPAPER = 0x14, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE = 3)
    [void][WallpaperNative]::SystemParametersInfo(0x14, 0, $DestImg, 3)
    Write-Log "Wallpaper applied"

    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}
