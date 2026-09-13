@echo off
setlocal EnableExtensions
title Warehouse Supabase Config
cd /d "%~dp0"
echo ==============================================
echo   Warehouse - Supabase Configuration
echo ==============================================
echo.
set /p "SUPA_URL=Paste Supabase Project URL: "
set /p "SUPA_KEY=Paste Supabase anon/public key: "
if "%SUPA_URL%"=="" goto :bad
if "%SUPA_KEY%"=="" goto :bad
set "CFG=public\supabase-config.js"
>"%CFG%" echo window.SUPABASE_CONFIG = {
>>"%CFG%" echo   url: '%SUPA_URL%',
>>"%CFG%" echo   anonKey: '%SUPA_KEY%'
>>"%CFG%" echo };
echo.
echo [OK] public\supabase-config.js has been configured.
echo You can now upload the PUBLIC folder to your free static host.
pause
exit /b 0
:bad
echo.
echo [ERROR] URL/key missing.
pause
exit /b 1
