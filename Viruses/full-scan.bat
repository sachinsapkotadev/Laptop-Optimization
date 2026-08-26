@echo off
title Windows Defender FULL Scan
REM ============================================================
REM  full-scan.bat - starts a Windows Defender Full Scan
REM  Takes 1-2 hours. Keep the laptop plugged in.
REM ============================================================
echo This will start a Windows Defender FULL SCAN.
echo It usually takes 1-2 hours. Keep the laptop plugged in.
echo You can keep working - the scan runs in the background.
echo.
choice /C YN /M "Start full scan now"
if errorlevel 2 goto :cancel

powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-MpScan -ScanType FullScan; if ($?) { Write-Host 'FULL SCAN STARTED/COMPLETED OK' } else { Write-Host 'Could not start scan' }"

echo.
echo Tip: check progress in Windows Security ^> Virus ^& threat protection.
goto :end

:cancel
echo Cancelled. Nothing was started.

:end
pause
