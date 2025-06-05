@echo off
chcp 65001 >nul
Setlocal Enabledelayedexpansion

:: 检查是否获得管理员权限
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    goto UACPrompt
) else ( goto gotAdmin )

:: 写入vbs脚本，以管理员身份重新运行此脚本
:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B

:: 删除临时vbs脚本
:gotAdmin
    if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
    pushd "%CD%"
    CD /D "%~dp0"

:MENU
echo ========================================
echo B站直播推流优化工具
echo ========================================
echo.
echo 请选择要执行的操作:
echo 1 - 测速并设置最优推流服务器
echo 2 - 清除hosts文件中的B站推流设置
echo 3 - 查看当前hosts中的B站配置
echo 4 - 退出程序
echo.

CHOICE /C 1234 /M "请输入选项数字 (1-4):"
IF ERRORLEVEL 4 GOTO STOP
IF ERRORLEVEL 3 GOTO VIEW_SETTING
IF ERRORLEVEL 2 GOTO REMOVE_SETTING
IF ERRORLEVEL 1 GOTO ADD_SETTING

:ADD_SETTING
echo.
echo ========================================
echo 正在获取B站推流服务器IP列表...
echo ========================================

:: 解析live-push.bilivideo.com域名获取IP列表
for /f "tokens=2" %%a in ('nslookup live-push.bilivideo.com ^| find "Address"') do (
    set ip=%%a
    echo %%a>>temp.txt
)

:: 将nslookup结果保存到临时文件
nslookup live-push.bilivideo.com>temp.txt

:: 初始化变量
set "start=no"
set "ip=ip.txt"

:: 创建新的结果文件
type nul > !ip!

:: 解析nslookup结果
for /f "tokens=1,2" %%a in (temp.txt) do (
    :: 检查是否到达"Addresses:"行
    if /i "%%a"=="Addresses:" (
        type nul > !ip!
        set "start=yes"
    ) else (
        :: 如果在"Addresses:"行之后，保存IP到结果文件
        if "!start!" equ "yes" (
            echo %%a %%b>> !ip!
        )
    )
)
del temp.txt

echo 已获取到IP列表，开始进行网络测速...
echo.
echo ========================================
echo 正在使用CloudflareSpeedTest进行测速...
echo 这可能需要几分钟时间，请耐心等待...
echo ========================================

:: 执行CloudflareSpeedTest，自动回车结束程序
echo.|CloudflareST.exe -t 100 -f "ip.txt" -o "speed_test.txt"
del ip.txt

:: 检查测速结果文件是否存在
if not exist speed_test.txt (
    echo.
    echo [错误] CloudflareSpeedTest测速结果为空，可能的原因：
    echo 1. CloudflareST.exe文件不存在
    echo 2. 网络连接问题
    echo 3. 所有IP都无法连接
    echo.
    echo 请检查网络连接后重试...
    goto :STOP
)

echo.
echo ========================================
echo 测速完成，正在选择最优IP...
echo ========================================

:: 获取最快的2-3个IP
for /f "tokens=1 delims=," %%i in (speed_test.txt) do (
    SET /a n+=1
    IF !n! GEQ 2 (
        IF !n! LEQ 4 (
            echo 选择优质IP: %%i
            echo %%i>> best_ips.txt
        )
    )
)

:: 检查是否成功获取到优质IP
if not exist best_ips.txt (
    echo [错误] 未能获取到可用的优质IP
    goto :STOP
)

echo.
echo ========================================
echo 正在更新hosts文件...
echo ========================================

:: 设置hosts文件路径
set "hostsFile=C:\Windows\System32\drivers\etc\hosts"
set "tempFile=C:\Windows\System32\drivers\etc\temp_bilibili.txt"

:: 创建新的临时文件
type nul > !tempFile!

:: 遍历原hosts文件，移除旧的bilibili配置
for /f "delims=" %%a in (!hostsFile!) do (
    :: 检查当前行是否包含"live-push.bilivideo.com"
    echo %%a|findstr /C:"live-push.bilivideo.com" >nul 2>&1
    if errorlevel 1 (
        :: 不包含则写入新文件
        echo %%a>> !tempFile!
    )
)

:: 删除原hosts文件并重命名临时文件
del /f !hostsFile!
move /y !tempFile! !hostsFile!

:: 添加新的最优IP到hosts文件
echo.
echo 正在添加以下配置到hosts文件:
for /f "tokens=*" %%i in (best_ips.txt) do (
    echo %%i live-push.bilivideo.com
    echo %%i live-push.bilivideo.com>>C:\Windows\System32\drivers\etc\hosts
)

del best_ips.txt
del speed_test.txt

echo.
echo ========================================
echo 正在刷新DNS缓存...
echo ========================================
ipconfig /flushdns

echo.
echo [成功] B站直播推流优化已完成！
echo 现在您的推流应该会连接到更稳定快速的服务器
echo.
echo 按任意键返回主菜单...
pause >nul
GOTO MENU

:REMOVE_SETTING
echo.
echo ========================================
echo 正在清除B站推流hosts配置...
echo ========================================

:: 设置hosts文件路径
set "hostsFile=C:\Windows\System32\drivers\etc\hosts"
set "tempFile=C:\Windows\System32\drivers\etc\temp_bilibili.txt"

:: 创建新的临时文件
type nul > !tempFile!

:: 遍历原hosts文件，移除bilibili相关配置
for /f "delims=" %%a in (!hostsFile!) do (
    :: 检查当前行是否包含"live-push.bilivideo.com"
    echo %%a|findstr /C:"live-push.bilivideo.com" >nul 2>&1
    if errorlevel 1 (
        :: 不包含则写入新文件
        echo %%a>> !tempFile!
    )
)

:: 删除原hosts文件并重命名临时文件
del /f !hostsFile!
move /y !tempFile! !hostsFile!

echo.
echo 正在刷新DNS缓存...
ipconfig /flushdns

echo.
echo [成功] 已清除所有B站推流相关的hosts配置
echo 推流将恢复使用默认的DNS解析
echo.
echo 按任意键返回主菜单...
pause >nul
GOTO MENU

:VIEW_SETTING
echo.
echo ========================================
echo 当前hosts文件中的B站推流配置:
echo ========================================
echo.

:: 在hosts文件中查找bilibili相关配置
findstr /C:"live-push.bilivideo.com" C:\Windows\System32\drivers\etc\hosts
if errorlevel 1 (
    echo [信息] 当前hosts文件中没有B站推流相关配置
    echo 正在使用默认DNS解析
) else (
    echo.
    echo 以上为当前生效的B站推流服务器配置
)
echo.
echo 按任意键返回主菜单...
pause >nul
GOTO MENU

:STOP
echo ========================================
echo 操作完成，感谢使用B站直播推流优化工具！
echo ========================================
endlocal
pause