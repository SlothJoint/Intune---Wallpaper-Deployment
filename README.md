# Intune Win32 App: Deploy a Desktop Wallpaper

A per-user Win32 app for Microsoft Intune that deploys a desktop wallpaper from an image bundled in the package. The image is copied to the user's profile and applied immediately, with no admin rights and no reboot.

> Review the scripts and test in a lab or pilot group before deploying to production.

---

## Features

- Image is bundled in the package, so there is no download at apply time and no dependency on network access
- Applies instantly to the signed-in user (no sign-out or restart needed)
- Configurable scaling style (Fill, Fit, Stretch, Center, Span)
- Versioned image file, so rolling out a new wallpaper is a version bump and re-upload
- Clean uninstall that reverts the user to the default Windows wallpaper
- Optional enforcement: either leave users free to change the wallpaper later, or re-apply it automatically

---

## Repository contents

| File | Purpose |
|---|---|
| `Set-Wallpaper.ps1` | Install script: copies the image and applies it |
| `Remove-Wallpaper.ps1` | Uninstall script: removes the image and reverts the background |
| `Detect-Wallpaper.ps1` | Custom detection script, uploaded separately in Intune |
| `README.md` | This document |

You supply your own image as `wallpaper.jpg`. No image is included.

---

## Requirements

- Microsoft Intune with Windows devices enrolled
- Windows 10 1607 or later (64-bit)
- Microsoft Win32 Content Prep Tool (`IntuneWinAppUtil.exe`): https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool
- A JPG image at or above your screens' resolution (for example 1920x1080 or 3840x2160)

---

## How it works

- The app is installed with **install behaviour set to User**, so the scripts run as the signed-in user. This allows them to write the user's own registry hive (`HKCU`) and refresh the desktop immediately, which is not possible from the SYSTEM account.
- The image is copied to `%LOCALAPPDATA%\CorporateWallpaper\wallpaper-v<version>.jpg`.
- The script sets `WallPaper`, `WallpaperStyle` and `TileWallpaper` under `HKCU\Control Panel\Desktop`, then calls the Windows `SystemParametersInfo` API to apply it to the running session.
- Activity is logged to `%LOCALAPPDATA%\CorporateWallpaper\wallpaper.log`.

### Scaling styles

Set `$WallpaperStyle` in `Set-Wallpaper.ps1`:

| Value | Style | `TileWallpaper` |
|---|---|---|
| `10` | Fill (default) | `0` |
| `6` | Fit | `0` |
| `2` | Stretch | `0` |
| `0` | Center | `0` |
| `22` | Span | `0` |

### Detection behaviour

`Detect-Wallpaper.ps1` has a switch named `$EnforceWallpaper`:

- `$false` (default): detected while the image file exists. Users can choose a different wallpaper afterwards and it is left alone.
- `$true`: detected only while the user's wallpaper still points at the deployed image. If the user changes it, Intune re-applies it at a later check-in.

---

## Customise before you build

| What | Where |
|---|---|
| Image | Save your image as `wallpaper.jpg` in the package folder |
| Scaling style | `$WallpaperStyle` in `Set-Wallpaper.ps1` |
| Version number | `$Version` in all three scripts (keep them identical) |
| Folder name under `%LOCALAPPDATA%` | `CorporateWallpaper` in all three scripts (keep them identical) |
| Enforcement | `$EnforceWallpaper` in `Detect-Wallpaper.ps1` |

---

## Build the package

1. Create a package folder, referred to below as `<PackageFolder>`, containing:
   ```
   Set-Wallpaper.ps1
   Remove-Wallpaper.ps1
   wallpaper.jpg
   ```
   `Detect-Wallpaper.ps1` stays **outside** this folder, because it is uploaded separately in Intune.
2. Confirm the three files are present directly in the folder (not in a subfolder).
3. Build the `.intunewin` file:
   ```
   IntuneWinAppUtil.exe -c "<PackageFolder>" -s Set-Wallpaper.ps1 -o "<OutputFolder>"
   ```
   - `-c` is the folder to package
   - `-s` is the setup file, which must be directly inside that folder
   - `-o` is where the output is written
4. The result is `<OutputFolder>\Set-Wallpaper.intunewin`.

---

## Test locally first

Sign in as a standard user and run, from the package folder:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Set-Wallpaper.ps1
echo %ERRORLEVEL%
```

The desktop should change immediately and the exit code should be `0`. Then check detection:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Detect-Wallpaper.ps1
echo %ERRORLEVEL%
```

It should print `Wallpaper v1 deployed` and return `0`. Run `Remove-Wallpaper.ps1` and confirm detection then fails (exit code `1`).

---

## Deploy with Intune

1. Open the Intune admin centre and go to **Apps → Windows → Create → Windows app (Win32)**.
2. **App information:** upload `Set-Wallpaper.intunewin` and enter a name, description and publisher.
3. **Program:**

   | Setting | Value |
   |---|---|
   | Install command | `powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File .\Set-Wallpaper.ps1` |
   | Uninstall command | `powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File .\Remove-Wallpaper.ps1` |
   | Install behaviour | **User** |
   | Device restart behaviour | No specific action |

4. **Requirements:** 64-bit architecture, Windows 10 1607 or later.
5. **Detection rules:** choose **Use a custom detection script**, upload `Detect-Wallpaper.ps1`, and set:
   - Run script as 32-bit process on 64-bit clients: **No**
   - Enforce script signature check and run script silently: **No**
6. **Assignments:** assign **Required** to a **user group**, starting with a pilot group.
7. **Review + create.**

### Monitoring

In Intune, open the app and check **Device install status** and **User install status**. On the device, read `%LOCALAPPDATA%\CorporateWallpaper\wallpaper.log`.

---

## Updating the wallpaper later

1. Replace `wallpaper.jpg` in the package folder.
2. Increase `$Version` (for example from `'1'` to `'2'`) in `Set-Wallpaper.ps1`, `Remove-Wallpaper.ps1` and `Detect-Wallpaper.ps1`.
3. Rebuild the `.intunewin`.
4. In Intune, open the app and go to **Properties → App package file → Edit**, then upload the new package. Update the detection script as well.
5. Detection now looks for the new versioned file, so every targeted user receives the new image.

---

## Notes

- **Other wallpaper settings override this app.** A Group Policy, Intune policy (including the Personalization CSP) or script that forces a wallpaper takes priority. Remove or unassign conflicting settings first.
- **Assign to users, not devices.** Apps installed in user context are most reliable when targeted at user groups. Assigning a user-context app to a device group can result in a "Not applicable" status.
- **A user must be signed in** for the install to run. If nobody is signed in, it installs at the next sign-in.
- **The image is stored per user**, so on shared devices each targeted user receives their own copy.
- **Wallpaper only.** This package does not change the lock screen.

---

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Install fails and the log says `wallpaper.jpg not found in package` | The image is missing from the package folder or misnamed. It must be called `wallpaper.jpg`. |
| `IntuneWinAppUtil` says the setup file cannot be accessed | `Set-Wallpaper.ps1` is not directly inside the folder passed to `-c`, or the filename differs. Check with `dir`. |
| App shows as installed but the wallpaper is unchanged | A policy is overriding it, or the user changed it afterwards. Check `HKCU\Control Panel\Desktop` (`WallPaper`) and any wallpaper policies. |
| Intune keeps reinstalling the app | `$EnforceWallpaper` is `$true` and the user changed the wallpaper. |
| Desktop is black | The image file is missing or the path is wrong. Check the folder under `%LOCALAPPDATA%\CorporateWallpaper`. |
| Detection never succeeds | Install behaviour must be **User**. A System install runs detection as SYSTEM and cannot see the user's files. |
| Status is "Not applicable" | The app is assigned to a device group. Assign it to a user group. |

---

## Log file

`%LOCALAPPDATA%\CorporateWallpaper\wallpaper.log`

Each line holds a timestamp and a message.
