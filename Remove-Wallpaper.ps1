<#
  Remove-Wallpaper.ps1
  Uninstall: removes the deployed image and, if the user's wallpaper still points at it,
  reverts the background to the Windows default image. Runs in USER context.
#>

$Version = '1'
$DestDir = Join-Path $env:LOCALAPPDATA 'CorporateWallpaper'
$DestImg = Join-Path $DestDir ("wallpaper-v{0}.jpg" -f $Version)

Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public class WallpaperNativeRemove {
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

$desktopKey = 'HKCU:\Control Panel\Desktop'
$current = (Get-ItemProperty -Path $desktopKey -Name WallPaper -ErrorAction SilentlyContinue).WallPaper

# Only revert if the user is still using our image
if ($current -eq $DestImg) {
    $default = Join-Path $env:windir 'Web\Wallpaper\Windows\img0.jpg'
    if (-not (Test-Path $default)) { $default = '' }
    Set-ItemProperty -Path $desktopKey -Name WallPaper -Value $default
    [void][WallpaperNativeRemove]::SystemParametersInfo(0x14, 0, $default, 3)
}

if (Test-Path $DestDir) { Remove-Item -Path $DestDir -Recurse -Force -ErrorAction SilentlyContinue }
exit 0
