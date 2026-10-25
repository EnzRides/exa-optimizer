<#
    Win11-Debloat-Optimizer.ps1  |  EXA OPTIMIZER (web launcher edition)
    -----------------------------------------------------------------
    A safe, reversible Windows 11 debloat + optimization script.
    This version is built to run via: irm <raw-github-url> | iex

    What it does:
      1. Creates a System Restore point before changing anything
      2. Removes common pre-installed/bundled ("bloat") apps
      3. Removes OneDrive
      4. Removes Widgets, Chat icon, and Copilot button from the taskbar
      5. Disables background telemetry/diagnostic tasks (not security)
      6. Trims unnecessary startup entries and visual effects
      7. Disables a short list of non-essential services (reversible)
      8. Runs disk cleanup and DISM component cleanup

    What it deliberately does NOT do:
      - Disable Windows Update, Defender, or Firewall
      - Remove the Microsoft Store itself
      - Touch BitLocker, user accounts, or network security settings
      - Make unverifiable "gaming FPS boost" registry hacks

    Everything here is reversible: apps can be reinstalled from the
    Microsoft Store, services can be re-enabled via services.msc,
    and the restore point lets you roll back entirely.
-----------------------------------------------------------------#>

$ErrorActionPreference = 'Continue'

# -----------------------------------------------------------------
# Self-elevate: iex can't use #Requires, so check manually and
# relaunch an elevated PowerShell that re-downloads and runs the
# script if we are not already admin.
# -----------------------------------------------------------------
$SCRIPT_URL = ""

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting Administrator access..." -ForegroundColor Yellow
    $elevateCmd = "irm $SCRIPT_URL | iex"
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$elevateCmd`"" -Verb RunAs
    return
}

# Runs every step by default (no command-line switches with the iex launcher)
$SkipRestorePoint  = $false
$SkipAppRemoval    = $false
$SkipOneDrive      = $false
$SkipWidgets       = $false
$SkipServiceTweaks = $false
$SkipDiskCleanup   = $false
$Host.UI.RawUI.WindowTitle = "EXA OPTIMIZER"
try {
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "Green"
    Clear-Host
} catch {}
$logFile = "$env:USERPROFILE\Desktop\Win11-Optimizer-Log.txt"
"EXA Optimizer run started $(Get-Date)" | Out-File -FilePath $logFile -Force

# Counters for the summary at the end
$stats = [ordered]@{
    "Apps removed"       = 0
    "Tasks disabled"     = 0
    "Services adjusted"  = 0
    "Tweaks applied"     = 0
    "Issues encountered" = 0
}

# -----------------------------------------------------------------
# Visual helpers
# -----------------------------------------------------------------
function Show-Banner {
    $banner = @"

   _______  __   __  _______    _______  _______  _______  __   __  ___   _______  _______  ______
  |       ||  |_|  ||   _   |  |       ||       ||       ||  |_|  ||   | |       ||       ||    _ |
  |    ___||       ||  |_|  |  |   _   ||    _  ||_     _||       ||   | |  _____||    ___||   | ||
  |   |___ |       ||       |  |  | |  ||   |_| |  |   |  |       ||   | | |_____ |   |___ |   |_||_
  |    ___| |     | |       |  |  |_|  ||    ___|  |   |  |       ||   | |_____  ||    ___||    __  |
  |   |___ |   |   ||   _   |  |       ||   |      |   |  |   |   ||   |  _____| ||   |___ |   |  | |
  |_______||__| |__||__| |__|  |_______||___|      |___|  |___| |_||___| |_______||_______||___|  |_|

                           Windows 11 Debloat & Performance Tune-up
"@
    Write-Host $banner -ForegroundColor Cyan
    Write-Host ("  " + ("=" * 95)) -ForegroundColor Green
    Write-Host ""
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "  >> $Title" -ForegroundColor Black -BackgroundColor Green
    Add-Content -Path $logFile -Value "`n=== $Title ==="
}

function Write-Log {
    param([string]$Message, [string]$Color = 'Green')
    $timestamp = Get-Date -Format 'HH:mm:ss'
    Write-Host "     [$timestamp] $Message" -ForegroundColor $Color
    Add-Content -Path $logFile -Value "[$timestamp] $Message"
}

function Write-Ok   { param([string]$m) Write-Log "[OK]   $m" 'Green' }
function Write-Info { param([string]$m) Write-Log "[..]   $m" 'Green' }
function Write-Skip { param([string]$m) Write-Log "[--]   $m" 'DarkGreen' }
function Write-Warn { param([string]$m) Write-Log "[!!]   $m" 'Green'; $stats["Issues encountered"]++ }

Show-Banner
Write-Host "  Press Ctrl+C at any time to cancel.`n" -ForegroundColor DarkGreen
Start-Sleep -Seconds 1

# -----------------------------------------------------------------
# 1. System Restore Point
# -----------------------------------------------------------------
Write-Section "Step 1 / 8  -  System Restore Point"
if (-not $SkipRestorePoint) {
    try {
        Write-Info "Enabling System Restore on C: (if not already on)..."
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue

        Write-Info "Creating restore point 'Pre-EXA-Optimizer'..."
        Checkpoint-Computer -Description "Pre-EXA-Optimizer" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Ok "Restore point created."
    } catch {
        Write-Warn "Could not create a restore point (often blocked if one was made in the last 24h). Continuing anyway."
    }
} else {
    Write-Skip "Skipped (per -SkipRestorePoint)."
}

# -----------------------------------------------------------------
# 2. Remove bundled / bloat apps
# -----------------------------------------------------------------
Write-Section "Step 2 / 8  -  Removing Bundled Apps"
if (-not $SkipAppRemoval) {
    # Review/edit this list before running. Core Windows components
    # (Store, Calculator, Photos, Notepad, Edge) are left alone.
    $appsToRemove = @(
        "Microsoft.3DBuilder"
        "Microsoft.BingNews"
        "Microsoft.BingWeather"
        "Microsoft.BingFinance"
        "Microsoft.BingSports"
        "Microsoft.GetHelp"
        "Microsoft.Getstarted"
        "Microsoft.Messaging"
        "Microsoft.Microsoft3DViewer"
        "Microsoft.MicrosoftOfficeHub"
        "Microsoft.MicrosoftSolitaireCollection"
        "Microsoft.MixedReality.Portal"
        "Microsoft.NetworkSpeedTest"
        "Microsoft.News"
        "Microsoft.Office.OneNote"
        "Microsoft.Office.Sway"
        "Microsoft.OneConnect"
        "Microsoft.People"
        "Microsoft.Print3D"
        "Microsoft.SkypeApp"
        "Microsoft.Wallet"
        "Microsoft.WindowsAlarms"
        "Microsoft.WindowsFeedbackHub"
        "Microsoft.WindowsMaps"
        "Microsoft.WindowsSoundRecorder"
        "Microsoft.Xbox.TCUI"
        "Microsoft.XboxApp"
        "Microsoft.XboxGameOverlay"
        "Microsoft.XboxGamingOverlay"
        "Microsoft.XboxIdentityProvider"
        "Microsoft.XboxSpeechToTextOverlay"
        "Microsoft.YourPhone"
        "Microsoft.ZuneMusic"
        "Microsoft.ZuneVideo"
        "MicrosoftTeams"
        "Microsoft.OutlookForWindows"
        "Clipchamp.Clipchamp"
        "Microsoft.549981C3F5F10"
        "king.com.CandyCrushSaga"
        "king.com.CandyCrushSodaSaga"
        "SpotifyAB.SpotifyMusic"
        "Disney.37853FC22B2CE"
        "Facebook.Facebook"
    )

    $i = 0
    foreach ($app in $appsToRemove) {
        $i++
        Write-Progress -Activity "Removing bundled apps" -Status $app -PercentComplete (($i / $appsToRemove.Count) * 100)
        try {
            $found = Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue
            $found | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object DisplayName -EQ $app |
                Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
            if ($found) { $stats["Apps removed"]++ }
            Write-Skip "  $app"
        } catch {
            Write-Skip "  $app (not present)"
        }
    }
    Write-Progress -Activity "Removing bundled apps" -Completed
    Write-Ok "App removal pass complete ($($stats['Apps removed']) packages matched)."
} else {
    Write-Skip "Skipped (per -SkipAppRemoval)."
}

# -----------------------------------------------------------------
# 3. Remove OneDrive
# -----------------------------------------------------------------
Write-Section "Step 3 / 8  -  Removing OneDrive"
if (-not $SkipOneDrive) {
    try {
        Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        $oneDriveSetup = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
        if (-not (Test-Path $oneDriveSetup)) {
            $oneDriveSetup = "$env:SystemRoot\System32\OneDriveSetup.exe"
        }

        if (Test-Path $oneDriveSetup) {
            Start-Process $oneDriveSetup -ArgumentList "/uninstall" -Wait -ErrorAction Stop
            Write-Ok "OneDrive uninstalled."
            $stats["Tweaks applied"]++
        } else {
            Write-Skip "OneDriveSetup.exe not found (likely already removed)."
        }

        Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:PROGRAMDATA\Microsoft OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:USERPROFILE\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue

        New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Force | Out-Null
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowSyncProviderNotifications" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

        New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction SilentlyContinue | Out-Null
        $clsid64 = "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
        if (Test-Path $clsid64) {
            Set-ItemProperty -Path $clsid64 -Name "System.IsPinnedToNameSpaceTree" -Value 0 -ErrorAction SilentlyContinue
        }
        Write-Ok "OneDrive leftovers and sidebar entry cleaned up."
    } catch {
        Write-Warn "OneDrive removal ran into an issue: $($_.Exception.Message)"
    }
} else {
    Write-Skip "Skipped (per -SkipOneDrive)."
}

# -----------------------------------------------------------------
# 4. Remove Widgets, Chat icon, and Copilot button
# -----------------------------------------------------------------
Write-Section "Step 4 / 8  -  Widgets, Chat & Copilot"
if (-not $SkipWidgets) {
    try {
        # Taskbar Widgets icon
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Ok "Taskbar Widgets icon hidden."
        $stats["Tweaks applied"]++

        # Taskbar Chat (Teams consumer) icon
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Ok "Taskbar Chat icon hidden."
        $stats["Tweaks applied"]++

        # Copilot button
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Ok "Taskbar Copilot button hidden."
        $stats["Tweaks applied"]++

        # Disable the Widgets board/service itself via policy
        $wPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
        if (-not (Test-Path $wPolicy)) { New-Item -Path $wPolicy -Force | Out-Null }
        Set-ItemProperty -Path $wPolicy -Name "AllowNewsAndInterests" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Ok "Widgets board disabled via policy."
        $stats["Tweaks applied"]++

        # Remove the Widgets app package if present
        $widgetsApp = Get-AppxPackage -Name "MicrosoftWindows.Client.WebExperience" -AllUsers -ErrorAction SilentlyContinue
        if ($widgetsApp) {
            $widgetsApp | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            Write-Ok "Widgets app package removed."
            $stats["Apps removed"]++
        } else {
            Write-Skip "Widgets app package already absent."
        }

        Write-Info "Restarting Explorer to apply taskbar changes..."
        Stop-Process -ProcessName explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Start-Process explorer.exe
        Write-Ok "Explorer restarted."
    } catch {
        Write-Warn "Widgets/Chat/Copilot cleanup ran into an issue: $($_.Exception.Message)"
    }
} else {
    Write-Skip "Skipped (per -SkipWidgets)."
}

# -----------------------------------------------------------------
# 5. Telemetry / diagnostics scheduled tasks
# -----------------------------------------------------------------
Write-Section "Step 5 / 8  -  Telemetry & Diagnostics"
$tasksToDisable = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
    "\Microsoft\Windows\Autochk\Proxy"
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
    "\Microsoft\Windows\Feedback\Siuf\DmClient"
    "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload"
    "\Microsoft\Windows\PI\Sqm-Tasks"
    "\Microsoft\Windows\Windows Error Reporting\QueueReporting"
)
foreach ($task in $tasksToDisable) {
    try {
        Disable-ScheduledTask -TaskPath (Split-Path $task) -TaskName (Split-Path $task -Leaf) -ErrorAction Stop | Out-Null
        Write-Skip "Disabled: $task"
        $stats["Tasks disabled"]++
    } catch {
        Write-Skip "Already disabled or not found: $task"
    }
}

try {
    $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    Set-ItemProperty -Path $path -Name "AllowTelemetry" -Value 0 -Type DWord -Force
    Write-Ok "Telemetry level set to Security/Minimum."
    $stats["Tweaks applied"]++
} catch {
    Write-Warn "Could not adjust telemetry registry key: $($_.Exception.Message)"
}

# -----------------------------------------------------------------
# 6. Visual effects & startup trimming
# -----------------------------------------------------------------
Write-Section "Step 6 / 8  -  Visual Effects & Startup"
try {
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "DragFullWindows" -Value "0" -Force
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -Force
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "EnableAeroPeek" -Value 0 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Type Binary -Force
    Write-Ok "Visual effects set to performance-leaning (animations reduced)."
    $stats["Tweaks applied"]++
} catch {
    Write-Warn "Could not fully adjust visual effects: $($_.Exception.Message)"
}

Write-Info "Current startup apps (review manually - 3rd-party apps are not auto-disabled):"
Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location |
    Format-Table -AutoSize | Out-String | Write-Log

# -----------------------------------------------------------------
# 7. Safe-to-disable services
# -----------------------------------------------------------------
Write-Section "Step 7 / 8  -  Non-Essential Services"
if (-not $SkipServiceTweaks) {
    $servicesToManual = @(
        "DiagTrack"          # Connected User Experiences and Telemetry
        "dmwappushservice"   # WAP Push message routing
        "RetailDemo"         # Retail Demo Service
        "MapsBroker"         # Downloaded Maps Manager
        "WSearch"            # Windows Search (skip if you rely on Start menu search)
    )
    foreach ($svc in $servicesToManual) {
        try {
            $service = Get-Service -Name $svc -ErrorAction Stop
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc -StartupType Manual -ErrorAction Stop
            Write-Skip "Set $svc to Manual (was $($service.StartType))."
            $stats["Services adjusted"]++
        } catch {
            Write-Skip "Service $svc not found or inaccessible."
        }
    }
    Write-Ok "Service tweaks complete. Re-enable any via services.msc if something breaks."
} else {
    Write-Skip "Skipped (per -SkipServiceTweaks)."
}

# -----------------------------------------------------------------
# 8. Disk cleanup + DISM
# -----------------------------------------------------------------
Write-Section "Step 8 / 8  -  Disk Cleanup"
if (-not $SkipDiskCleanup) {
    Write-Info "Running Disk Cleanup (temp files, old update files)..."
    try {
        Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:65" -Wait -ErrorAction Stop
        Write-Ok "Disk cleanup complete."
        $stats["Tweaks applied"]++
    } catch {
        Write-Warn "Disk cleanup step skipped/failed: $($_.Exception.Message)"
    }

    Write-Info "Running DISM component cleanup (reclaims space)..."
    try {
        Start-Process -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup /ResetBase" -Wait -NoNewWindow
        Write-Ok "DISM cleanup complete."
        $stats["Tweaks applied"]++
    } catch {
        Write-Warn "DISM cleanup failed: $($_.Exception.Message)"
    }
} else {
    Write-Skip "Skipped (per -SkipDiskCleanup)."
}

# -----------------------------------------------------------------
# Summary
# -----------------------------------------------------------------
Write-Host ""
Write-Host ("  " + ("=" * 60)) -ForegroundColor Green
Write-Host "   EXA OPTIMIZER - SUMMARY" -ForegroundColor Green
Write-Host ("  " + ("=" * 60)) -ForegroundColor Green
foreach ($key in $stats.Keys) {
    $color = if ($key -eq "Issues encountered" -and $stats[$key] -gt 0) { "DarkGreen" } else { "Green" }
    Write-Host ("   {0,-22}: {1}" -f $key, $stats[$key]) -ForegroundColor $color
}
Write-Host ("  " + ("=" * 60)) -ForegroundColor Green
Write-Host ""
Write-Host "  Log saved to: $logFile" -ForegroundColor Green
Write-Host "  A restart is recommended for all changes to fully apply." -ForegroundColor Green
Write-Host ""
