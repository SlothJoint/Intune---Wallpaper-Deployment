<#
  Detect-Wallpaper.ps1
  Intune custom detection script (runs in the same context as the install = USER).
  Installed = exit 0 AND text written to STDOUT.

  $EnforceWallpaper = $false : detected as long as the image is deployed (user may later pick their own wallpaper)
  $EnforceWallpaper = $true  : detected only while the user's wallpaper still points at the image;
                               Intune will re-apply it at later check-ins if the user changes it.
#>

$Version          = '1'
$EnforceWallpaper = $false

$DestImg = Join-Path $env:LOCALAPPDATA ("CorporateWallpaper\wallpaper-v{0}.jpg" -f $Version)

if (-not (Test-Path $DestImg)) { exit 1 }

if ($EnforceWallpaper) {
    $current = (Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallPaper -ErrorAction SilentlyContinue).WallPaper
    if ($current -ne $DestImg) { exit 1 }
}

Write-Output "Wallpaper v$Version deployed"
exit 0
