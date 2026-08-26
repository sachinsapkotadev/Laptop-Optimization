# ============================================================
#  virus-log.ps1 - Security & System Health Logger
#  Creates a timestamped log of virus status + system health.
#  Usage:  powershell -File virus-log.ps1 [-Scan]
#          (-Scan also runs a Defender Quick Scan first)
# ============================================================
param([switch]$Scan)

$ErrorActionPreference = 'SilentlyContinue'
$logDir = Join-Path $PSScriptRoot 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$stamp   = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$logFile = Join-Path $logDir "security-log_$stamp.log"

function Log { param([string]$Text = '') $Text | Tee-Object -FilePath $logFile -Append }

Log '================================================================'
Log ' SECURITY & SYSTEM HEALTH LOG'
Log (" Generated : " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Log (" Computer  : $env:COMPUTERNAME    User: $env:USERNAME")
Log '================================================================'

# ---------- optional quick scan ----------
if ($Scan) {
    Log ''
    Log '[SCAN] Running Windows Defender Quick Scan, please wait...'
    Start-MpScan -ScanType QuickScan
    Log ('[SCAN] Quick scan finished at ' + (Get-Date -Format 'HH:mm:ss'))
}

# ---------- 1. defender protection status ----------
Log ''
Log '--- 1. WINDOWS DEFENDER STATUS ---------------------------------'
$s = Get-MpComputerStatus
if ($s) {
    Log (" Antivirus enabled          : " + $(If ($s.AntivirusEnabled) {'YES'} Else {'NO !!'}))
    Log (" Real-time protection       : " + $(If ($s.RealTimeProtectionEnabled) {'ON'} Else {'OFF !!'}))
    Log (" Behavior monitoring        : " + $(If ($s.BehaviorMonitorEnabled) {'ON'} Else {'OFF !!'}))
    Log (" Signature version          : " + $s.AntivirusSignatureVersion)
    Log (" Signature updated          : " + $s.AntivirusSignatureLastUpdated)
    Log (" Last quick scan            : " + $s.QuickScanEndTime)
    Log (" Last full scan             : " + $s.FullScanEndTime)
} else {
    Log ' !! Could not read Defender status (run as Administrator?).'
}
$fw = Get-NetFirewallProfile
foreach ($p in $fw) { Log (" Firewall [" + $p.Name + "] : " + $(If ($p.Enabled) {'ON'} Else {'OFF !!'})) }

# ---------- 2. threat records ----------
Log ''
Log '--- 2. THREAT RECORDS (DEFENDER HISTORY) -----------------------'
$threats = Get-MpThreat
$dets    = Get-MpThreatDetection
if ($threats) {
    foreach ($t in $threats) {
        $sev = Switch ($t.SeverityID) { 5 {'SEVERE'} 4 {'HIGH'} default {"Level $($t.SeverityID)"} }
        $act = If ($t.IsActive) {'ACTIVE !!'} else {'inactive'}
        Log (" - " + $t.ThreatName.PadRight(40) + " [$sev] -> $act")
    }
} else {
    Log ' - No threat records found.'
}
Log (" Total detection events on record : " + (@($dets).Count))
if ($dets) {
    $latest = ($dets | Sort-Object InitialDetectionTime -Descending | Select-Object -First 1).InitialDetectionTime
    Log (" Most recent detection            : $latest")
}

# ---------- 3. verdict ----------
Log ''
Log '--- 3. VERDICT -------------------------------------------------'
$active = @($threats | Where-Object IsActive -eq $true)
if     ($active.Count -gt 0) { $verdict = "!! NOT SAFE - $($active.Count) ACTIVE THREAT(S): " + (($active | ForEach-Object ThreatName) -join ', '); $exit = 2 }
elseif ($null -eq $threats)  { $verdict = '100% SAFE - NO THREAT RECORDS, DEFENDER CLEAN';              $exit = 0 }
else                         { $verdict = '100% SAFE - ALL PAST THREATS REMOVED, NOTHING ACTIVE';      $exit = 0 }
Log (" >> $verdict")

# ---------- 4. disk health ----------
Log ''
Log '--- 4. DISK HEALTH ---------------------------------------------'
Get-PhysicalDisk | ForEach-Object {
    Log (" - " + $_.FriendlyName.PadRight(30) + "[" + $_.MediaType + "] -> " + $_.HealthStatus)
}
Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
    Log (" - Drive " + $_.DeviceID + " free " + ('{0:N1}' -f ($_.FreeSpace/1GB)) + " GB of " + ('{0:N0}' -f ($_.Size/1GB)) + " GB")
}

# ---------- 5. memory / cpu / uptime ----------
Log ''
Log '--- 5. SYSTEM LOAD ---------------------------------------------'
$os  = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor
$up  = (Get-Date) - $os.LastBootUpTime
$ramUsedGB = '{0:N1}' -f (($os.TotalVisibleMemorySize - $os.FreePhysicalMemory)/1MB)
$ramTotGB  = '{0:N1}' -f ($os.TotalVisibleMemorySize/1MB)
Log (" RAM in use : $ramUsedGB GB of $ramTotGB GB")
Log (" CPU load   : " + $(If ($cpu.LoadPercentage) {"$($cpu.LoadPercentage)%"} else {'n/a'}))
Log (" Uptime     : " + $up.Days + " days " + $up.Hours + " h " + $up.Minutes + " min")

# ---------- 6. crashes & errors ----------
Log ''
Log '--- 6. CRASHES / ERRORS (LAST 30 DAYS unless noted) ------------'
$since = (Get-Date).AddDays(-30)
$shuts = @(Get-WinEvent -FilterHashtable @{LogName='System'; Id=41; StartTime=$since} -MaxEvents 100)
Log (" Unexpected shutdowns (Event 41) : " + $shuts.Count)
$bsod = @(Get-WinEvent -FilterHashtable @{LogName='System'; Id=1001; ProviderName='Microsoft-Windows-WER-SystemErrorReporting'; StartTime=$since} -MaxEvents 50)
Log (" BSOD bugcheck events            : " + $bsod.Count)
if ($bsod.Count -gt 0) { Log (" Latest BSOD                     : " + $bsod[0].TimeCreated) }
$week = (Get-Date).AddDays(-7)
Log ' Top error sources (last 7 days):'
Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=$week} -MaxEvents 500 |
    Group-Object ProviderName | Sort-Object Count -Descending | Select-Object -First 5 |
    ForEach-Object { Log ("   " + $_.Count.ToString().PadLeft(4) + "x  " + $_.Name) }

# ---------- footer ----------
Log ''
Log '================================================================'
Log (" Log saved to : $logFile")
Log '================================================================'

exit $exit
