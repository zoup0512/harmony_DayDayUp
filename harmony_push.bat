@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion
REM HarmonyOS Project One-Click Push To GitHub
REM 鸿蒙项目一键上传GitHub脚本（可重复执行）

REM ====================== 必填配置项 ======================
set GITHUB_USERNAME=zoup0512
REM 新建仓库时的可见性：私有true / 公开false
set PRIVATE_REPO=true
REM =========================================================

REM 从环境变量读取 GitHub Token；只在单次请求中使用，绝不写入 .git/config
if "%GITHUB_TOKEN%"=="" (
    echo [x] 未检测到环境变量 GITHUB_TOKEN，请先设置！
    echo     设置方法：set GITHUB_TOKEN=ghp_你的token
    pause
    exit /b 1
)

for %%F in ("%CD%") do set REPO_NAME=%%~nxF
set REMOTE_URL=https://github.com/%GITHUB_USERNAME%/%REPO_NAME%.git

echo =============================================
echo   HarmonyOS 鸿蒙项目一键上传GitHub工具
echo   项目名称: %REPO_NAME%
echo =============================================

REM 1. 初始化本地Git仓库
if not exist .git (
    echo [1/5] 初始化本地Git仓库...
    git init -b main || goto :fail
) else (
    echo [1/5] 本地Git仓库已存在，跳过初始化
)

REM 2. 检查提交身份（不自动改写 git config）
git config user.name >nul 2>&1 && git config user.email >nul 2>&1
if errorlevel 1 (
    echo [x] 未配置 git user.name / user.email，请先自行配置后再运行。
    goto :fail
)

REM 3. 提交变更（.gitignore 由仓库维护，不在此覆盖）
echo [2/5] 暂存并提交变更...
git add -A
git diff --cached --quiet
if errorlevel 1 (
    git commit -m "Update HarmonyOS project" || goto :fail
) else (
    echo [i] 无新变更，跳过提交
)

REM 4. 远程仓库不存在时才创建
echo [3/5] 检查GitHub远程仓库...
curl -s -o nul -w "%%{http_code}" -H "Authorization: token %GITHUB_TOKEN%" https://api.github.com/repos/%GITHUB_USERNAME%/%REPO_NAME% > "%TEMP%\gh_repo_status.txt"
set /p REPO_STATUS=<"%TEMP%\gh_repo_status.txt"
if "!REPO_STATUS!"=="200" (
    echo [i] 远程仓库已存在
) else (
    echo [i] 远程仓库不存在，正在创建（private=%PRIVATE_REPO%）...
    curl -s -X POST -H "Authorization: token %GITHUB_TOKEN%" -H "Accept: application/vnd.github.v3+json" https://api.github.com/user/repos -d "{\"name\":\"%REPO_NAME%\",\"private\":%PRIVATE_REPO%,\"description\":\"HarmonyOS APP Project\",\"auto_init\":false}" > "%TEMP%\gh_create_result.json"
    findstr /C:"\"full_name\"" "%TEMP%\gh_create_result.json" >nul 2>&1
    if errorlevel 1 (
        echo [x] 远程仓库创建失败！
        type "%TEMP%\gh_create_result.json"
        goto :fail
    )
)

REM 5. 远程地址不含凭据；Token 仅通过一次性请求头传给本次 push
echo [4/5] 关联远程仓库...
git remote get-url origin >nul 2>&1
if errorlevel 1 (
    git remote add origin %REMOTE_URL%
) else (
    git remote set-url origin %REMOTE_URL%
)

echo [5/5] 推送代码...
for /f "delims=" %%A in ('powershell -NoProfile -Command "[Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('x-access-token:' + $env:GITHUB_TOKEN))"') set GH_BASIC=%%A
git -c http.https://github.com/.extraheader="AUTHORIZATION: basic !GH_BASIC!" push -u origin HEAD:main
set PUSH_RC=%ERRORLEVEL%
set GH_BASIC=
if not "%PUSH_RC%"=="0" goto :fail

echo.
echo [v] 全部完成：https://github.com/%GITHUB_USERNAME%/%REPO_NAME%
pause
exit /b 0

:fail
echo [x] 执行失败！
pause
exit /b 1
