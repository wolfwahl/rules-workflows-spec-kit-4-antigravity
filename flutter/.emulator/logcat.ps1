param (
    [Parameter(Mandatory)]
    [string]$DEVICE,

    [Parameter(Mandatory)]
    [string]$AVD
)

Write-Host "=== Logcat Controller for $DEVICE ==="

# ---------- Helpers ----------

function Wait-For-Boot {
    Write-Host "Waiting for device..."
    adb -s $DEVICE wait-for-device

    Write-Host "Waiting for boot completion..."
    do {
        Start-Sleep -Seconds 1
        $booted = adb -s $DEVICE shell getprop sys.boot_completed 2>$null
    } while ($booted -ne "1")

    Write-Host "Device booted."
}

function Wait-For-Adb-Stable {
    param ($DEVICE)

    Write-Host "Waiting for stable ADB on $DEVICE..."

    while ($true) {
        $state = adb devices | Select-String $DEVICE
        if ($state -and $state.ToString().EndsWith("device")) {
            try {
                adb -s $DEVICE shell echo ok > $null 2>&1
                break
            } catch {}
        }
        Start-Sleep -Seconds 2
    }

    Write-Host "$DEVICE ADB is stable."
}

function Get-User-Packages {
    adb -s $DEVICE shell pm list packages -3 |
        ForEach-Object { $_ -replace "package:" }
}

function Detect-Flutter-Package {
    Write-Host "Detecting Flutter package..."

    $before = Get-User-Packages

    while ($true) {
        Start-Sleep -Seconds 1
        $after = Get-User-Packages

        $diff = Compare-Object $before $after |
                Where-Object { $_.SideIndicator -eq "=>" } |
                Select-Object -ExpandProperty InputObject

        if ($diff.Count -gt 0) {
            $pkg = $diff[0]
            Write-Host "Detected package: $pkg"
            return $pkg
        }
    }
}

function Start-Logcat-For-PID {
    param ($PID)

    Write-Host "Binding logcat to PID $PID"
    Wait-For-Adb-Stable $DEVICE
    Start-Process adb `
        -ArgumentList "-s $DEVICE logcat --pid=$PID" `
        -NoNewWindow `
        -PassThru
}

function Cold-Boot {
    Write-Host "Cold booting emulator..."
    Wait-For-Adb-Stable $DEVICE
    adb -s $DEVICE emu kill | Out-Null

    Start-Process emulator `
        -ArgumentList "-avd $AVD -port $($DEVICE.Split('-')[1]) -wipe-data" `
        -WindowStyle Minimized

    Wait-For-Boot
}

# ---------- Startup ----------

Wait-For-Boot

$PACKAGE = Detect-Flutter-Package

$logcatProcess = $null
$currentPID = $null

Write-Host ""
Write-Host "Hotkeys:"
Write-Host "  c = clear logcat"
Write-Host "  w = cold boot (wipe)"
Write-Host "  q = quit"
Write-Host ""

# ---------- Main Loop ----------

while ($true) {

    # PID monitoring
    Wait-For-Adb-Stable $DEVICE
    $newPID = adb -s $DEVICE shell pidof $PACKAGE 2>$null

    if ($newPID -and $newPID -ne $currentPID) {
        Write-Host "PID change detected: $currentPID → $newPID"

        if ($logcatProcess) {
            $logcatProcess | Stop-Process -Force
        }

        adb -s $DEVICE logcat -c
        $logcatProcess = Start-Logcat-For-PID $newPID
        $currentPID = $newPID
    }

    # Non-blocking key read
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true).KeyChar

        switch ($key) {
            'c' {
                Write-Host "Manual logcat clear"
                Wait-For-Adb-Stable $DEVICE
                adb -s $DEVICE logcat -c
            }
            'w' {
                if ($logcatProcess) {
                    $logcatProcess | Stop-Process -Force
                }
                Cold-Boot
                $PACKAGE = Detect-Flutter-Package
                $currentPID = $null
            }
            'q' {
                Write-Host "Exiting..."
                if ($logcatProcess) {
                    $logcatProcess | Stop-Process -Force
                }
                break
            }
        }
    }

    Start-Sleep -Milliseconds 300
}