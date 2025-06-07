@echo off
chcp 65001 >nul
Setlocal Enabledelayedexpansion

:: Check admin privileges
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
    pushd "%CD%"
    CD /D "%~dp0"

:MAIN_MENU
echo ========================================
echo B站自动化IP优化工具
echo ========================================
echo.

:: Check required files
if not exist "bilibili-known-ips.txt" (
    echo [ERROR] Cannot find bilibili-known-ips.txt file!
    echo Please create this file in the same directory as the script.
    echo Each line should contain one IP address.
    echo.
    pause
    goto EXIT
)

if not exist "CloudflareST.exe" (
    echo [WARNING] Cannot find CloudflareST.exe file!
    echo Please put CloudflareST.exe in the same directory as the script.
    echo.
)

:: Show current IP list
echo Current IP list:
echo ----------------------------------------
type bilibili-known-ips.txt
echo ----------------------------------------

:: Count IPs
for /f %%a in ('type bilibili-known-ips.txt ^| find /c /v ""') do set /a ip_count=%%a
echo Total: %ip_count% IP addresses
echo.

echo Please select an option:
echo 1 - Auto test and apply best IP
echo 2 - Test only without applying
echo 3 - Manually specify IP to apply
echo 4 - View current hosts configuration
echo 5 - Restore hosts configuration
echo 6 - Exit program
echo.

CHOICE /C 123456 /M "Enter option number (1-6): "
IF ERRORLEVEL 6 GOTO EXIT
IF ERRORLEVEL 5 GOTO RESTORE_HOSTS
IF ERRORLEVEL 4 GOTO VIEW_HOSTS
IF ERRORLEVEL 3 GOTO MANUAL_IP
IF ERRORLEVEL 2 GOTO TEST_ONLY
IF ERRORLEVEL 1 GOTO AUTO_OPTIMIZE

:AUTO_OPTIMIZE
echo ========================================
echo Auto test and apply best IP
echo ========================================

if not exist "CloudflareST.exe" (
    echo [ERROR] CloudflareST.exe not found!
    pause
    goto MAIN_MENU
)

echo Running CloudflareSpeedTest...
echo This may take a few minutes, please wait...
echo.

:: Run speed test (latency only for faster results)
CloudflareST.exe -f bilibili-known-ips.txt -dd -o bilibili_speed_result.csv

:: Check results
if not exist "bilibili_speed_result.csv" (
    echo [ERROR] Speed test failed!
    pause
    goto MAIN_MENU
)

echo.
echo Speed test completed! Analyzing results...
echo ========================================

:: Show results
echo Speed test results:
type bilibili_speed_result.csv
echo ========================================

:: Extract best IP (second line, first field)
set /a line_count=0
for /f "tokens=1 delims=," %%a in (bilibili_speed_result.csv) do (
    set /a line_count+=1
    if !line_count! EQU 2 (
        set "best_ip=%%a"
        goto :found_best_ip
    )
)

:found_best_ip
if not defined best_ip (
    echo [ERROR] Cannot find best IP!
    pause
    goto MAIN_MENU
)

echo.
echo Best IP detected: %best_ip%
echo.
CHOICE /C YN /M "Apply this IP to hosts file? (Y/N): "
IF ERRORLEVEL 2 GOTO MAIN_MENU
IF ERRORLEVEL 1 GOTO APPLY_BEST_IP

:APPLY_BEST_IP
echo.
echo Applying best IP: %best_ip%
call :CLEAN_BILIBILI_HOSTS
call :ADD_IP_TO_HOSTS "%best_ip%"
call :FLUSH_DNS

echo.
echo ========================================
echo [SUCCESS] Applied best IP: %best_ip%
echo ========================================
echo.
echo You can now test if Bilibili video loading is faster
echo Press any key to return to main menu...
pause >nul
GOTO MAIN_MENU

:TEST_ONLY
echo ========================================
echo Test only mode
echo ========================================

if not exist "CloudflareST.exe" (
    echo [ERROR] CloudflareST.exe not found!
    pause
    goto MAIN_MENU
)

echo Running latency test...
CloudflareST.exe -f bilibili-known-ips.txt -dd -o bilibili_speed_result.csv

if exist "bilibili_speed_result.csv" (
    echo.
    echo Test results:
    echo ========================================
    type bilibili_speed_result.csv
    echo ========================================
)

echo.
echo Test completed! Press any key to return to main menu...
pause >nul
GOTO MAIN_MENU

:MANUAL_IP
echo ========================================
echo Manual IP specification mode
echo ========================================
echo.
echo Please enter the IP address to apply:
set /p manual_ip="IP address: "

:: Validate IP format
echo %manual_ip% | findstr "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo [ERROR] Invalid IP address format!
    pause
    goto MAIN_MENU
)

echo.
echo Will apply IP: %manual_ip%
CHOICE /C YN /M "Confirm applying this IP to hosts file? (Y/N): "
IF ERRORLEVEL 2 GOTO MAIN_MENU

call :CLEAN_BILIBILI_HOSTS
call :ADD_IP_TO_HOSTS "%manual_ip%"
call :FLUSH_DNS

echo.
echo ========================================
echo [SUCCESS] Applied IP: %manual_ip%
echo ========================================
echo.
echo Press any key to return to main menu...
pause >nul
GOTO MAIN_MENU

:VIEW_HOSTS
echo.
echo ========================================
echo Current Bilibili configuration in hosts
echo ========================================
echo.

set "found_config="
findstr /C:"live-push.bilivideo.com" C:\Windows\System32\drivers\etc\hosts >nul 2>&1
if not errorlevel 1 set "found_config=1"

findstr /C:"upos-sz-mirrorhw.bilivideo.com" C:\Windows\System32\drivers\etc\hosts >nul 2>&1
if not errorlevel 1 set "found_config=1"

findstr /C:"upos-sz-mirrorcos.bilivideo.com" C:\Windows\System32\drivers\etc\hosts >nul 2>&1
if not errorlevel 1 set "found_config=1"

findstr /C:"upos-sz-mirrorali.bilivideo.com" C:\Windows\System32\drivers\etc\hosts >nul 2>&1
if not errorlevel 1 set "found_config=1"

findstr /C:"upos-sz-mirroraliov.bilivideo.com" C:\Windows\System32\drivers\etc\hosts >nul 2>&1
if not errorlevel 1 set "found_config=1"

findstr /C:"upos-hz-mirrorakam.akamaized.net" C:\Windows\System32\drivers\etc\hosts >nul 2>&1
if not errorlevel 1 set "found_config=1"

if defined found_config (
    echo [Live streaming domains]:
    findstr /C:"live-push.bilivideo.com" C:\Windows\System32\drivers\etc\hosts 2>nul
    echo.
    echo [Video CDN domains]:
    findstr /C:"upos-sz-mirrorhw.bilivideo.com" C:\Windows\System32\drivers\etc\hosts 2>nul
    findstr /C:"upos-sz-mirrorcos.bilivideo.com" C:\Windows\System32\drivers\etc\hosts 2>nul
    findstr /C:"upos-sz-mirrorali.bilivideo.com" C:\Windows\System32\drivers\etc\hosts 2>nul
    findstr /C:"upos-sz-mirroraliov.bilivideo.com" C:\Windows\System32\drivers\etc\hosts 2>nul
    findstr /C:"upos-hz-mirrorakam.akamaized.net" C:\Windows\System32\drivers\etc\hosts 2>nul
) else (
    echo No Bilibili configuration found in hosts file
    echo Using default DNS resolution
)

echo.
echo Press any key to return to main menu...
pause >nul
GOTO MAIN_MENU

:RESTORE_HOSTS
echo ========================================
echo Restore hosts configuration
echo ========================================
echo.
echo This will remove all Bilibili-related configuration from hosts file
echo and restore default DNS resolution
echo.
CHOICE /C YN /M "Confirm restore operation? (Y/N): "
IF ERRORLEVEL 2 GOTO MAIN_MENU

call :CLEAN_BILIBILI_HOSTS
call :FLUSH_DNS

echo.
echo ========================================
echo [SUCCESS] Hosts configuration restored
echo ========================================
echo.
echo All Bilibili-related configuration has been removed
echo Now using default DNS resolution
echo.
echo Press any key to return to main menu...
pause >nul
GOTO MAIN_MENU

:: ======== Function definitions ========

:CLEAN_BILIBILI_HOSTS
echo Cleaning old Bilibili hosts configuration...
set "hostsFile=C:\Windows\System32\drivers\etc\hosts"
set "tempFile=C:\Windows\System32\drivers\etc\temp_bilibili_clean.txt"

type nul > "!tempFile!"

for /f "delims=" %%a in ("!hostsFile!") do (
    echo %%a|findstr /C:"live-push.bilivideo.com" >nul 2>&1
    if errorlevel 1 (
        echo %%a|findstr /C:"upos-sz-mirrorhw.bilivideo.com" >nul 2>&1
        if errorlevel 1 (
            echo %%a|findstr /C:"upos-sz-mirrorcos.bilivideo.com" >nul 2>&1
            if errorlevel 1 (
                echo %%a|findstr /C:"upos-sz-mirrorali.bilivideo.com" >nul 2>&1
                if errorlevel 1 (
                    echo %%a|findstr /C:"upos-sz-mirroraliov.bilivideo.com" >nul 2>&1
                    if errorlevel 1 (
                        echo %%a|findstr /C:"upos-hz-mirrorakam.akamaized.net" >nul 2>&1
                        if errorlevel 1 (
                            echo %%a>> "!tempFile!"
                        )
                    )
                )
            )
        )
    )
)

del /f "!hostsFile!" 2>nul
move /y "!tempFile!" "!hostsFile!" >nul
goto :eof

:ADD_IP_TO_HOSTS
set "target_ip=%~1"
echo Adding IP configuration: %target_ip%

echo %target_ip% live-push.bilivideo.com>>C:\Windows\System32\drivers\etc\hosts
echo %target_ip% upos-sz-mirrorhw.bilivideo.com>>C:\Windows\System32\drivers\etc\hosts
echo %target_ip% upos-sz-mirrorcos.bilivideo.com>>C:\Windows\System32\drivers\etc\hosts
echo %target_ip% upos-sz-mirrorali.bilivideo.com>>C:\Windows\System32\drivers\etc\hosts
echo %target_ip% upos-sz-mirroraliov.bilivideo.com>>C:\Windows\System32\drivers\etc\hosts
echo %target_ip% upos-hz-mirrorakam.akamaized.net>>C:\Windows\System32\drivers\etc\hosts

echo.
echo Added domain configurations:
echo [Live streaming] %target_ip% live-push.bilivideo.com
echo [Huawei Cloud CDN] %target_ip% upos-sz-mirrorhw.bilivideo.com
echo [Tencent Cloud CDN] %target_ip% upos-sz-mirrorcos.bilivideo.com
echo [Alibaba Cloud CDN] %target_ip% upos-sz-mirrorali.bilivideo.com
echo [Alibaba Cloud Overseas] %target_ip% upos-sz-mirroraliov.bilivideo.com
echo [Akamai CDN] %target_ip% upos-hz-mirrorakam.akamaized.net
goto :eof

:FLUSH_DNS
echo Flushing DNS cache...
ipconfig /flushdns >nul
echo DNS cache flushed
goto :eof

:EXIT
echo Thank you for using Bilibili Auto IP Optimizer!
echo.
endlocal
pause