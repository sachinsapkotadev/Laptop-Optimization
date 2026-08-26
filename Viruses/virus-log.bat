@echo off
title Virus ^& System Health Logger
REM ============================================================
REM  virus-log.bat - double-click to generate a security log
REM  Optional: run "virus-log.bat scan" to also do a Quick Scan
REM  Logs are saved to:  Viruses\logs\
REM ============================================================
set ARGS=
if /I "%~1"=="scan" set ARGS=-Scan

echo Generating security + system health log, please wait...
if defined ARGS echo (Quick Scan requested - this adds about a minute)
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0virus-log.ps1" %ARGS%

echo.
echo Done. Log saved in the Viruses\logs folder.
pause
