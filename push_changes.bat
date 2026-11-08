@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

echo ======================================================
echo       Відправка оновлень модпаку на GitHub
echo ======================================================
echo.

set "GAME_DIR=%APPDATA%\.minecraft\versions\2"
if exist "%GAME_DIR%\config" (
    echo [*] Копіювання свіжих конфігів з гри (%GAME_DIR%\config)...
    xcopy "%GAME_DIR%\config\*" "%~dp0config\" /s /e /y /q > nul
)
if exist "%GAME_DIR%\defaultconfigs" (
    xcopy "%GAME_DIR%\defaultconfigs\*" "%~dp0defaultconfigs\" /s /e /y /q > nul
)

echo [*] Оновлення індексів Packwiz...
"%~dp0packwiz.exe" refresh

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

echo.
echo [*] Перевірка змін у репозиторії:
"%GIT_CMD%" -C "%~dp0" status --short
echo.

set /p COMMIT_MSG="Введіть опис змін (Enter для 'Оновлення модпаку'): "
if "%COMMIT_MSG%"=="" set "COMMIT_MSG=Оновлення модпаку"

echo.
echo [*] Збереження та відправка на GitHub...
"%GIT_CMD%" -C "%~dp0" add .
"%GIT_CMD%" -C "%~dp0" commit -m "%COMMIT_MSG%"
"%GIT_CMD%" -C "%~dp0" push origin main

if %errorlevel% equ 0 (
    echo.
    echo ======================================================
    echo  Успішно відправлено на GitHub!
    echo  Тепер ваш друг може запустити sync.bat у себе!
    echo ======================================================
) else (
    echo.
    echo [!] Виникла помилка під час push. Перевірте підключення до інтернету або авторизацію.
)

echo.
pause
