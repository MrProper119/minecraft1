@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

echo ======================================================
echo          Оновлення модпаку з GitHub
echo ======================================================
echo.

:: Знаходимо git
set "GIT_CMD=git"
where git >nul 2>nul
if %errorlevel% neq 0 (
    if exist "%LOCALAPPDATA%\GitHubDesktop\app-3.5.8\resources\app\git\cmd\git.exe" (
        set "GIT_CMD=%LOCALAPPDATA%\GitHubDesktop\app-3.5.8\resources\app\git\cmd\git.exe"
    ) else (
        for /d %%D in ("%LOCALAPPDATA%\GitHubDesktop\app-*") do (
            if exist "%%D\resources\app\git\cmd\git.exe" set "GIT_CMD=%%D\resources\app\git\cmd\git.exe"
        )
    )
)

echo [*] Отримання останніх змін із репозиторію GitHub...
"%GIT_CMD%" -C "%~dp0" pull origin main

echo.
echo [*] Запуск синхронізації клієнта...
call "%~dp0sync.bat"

