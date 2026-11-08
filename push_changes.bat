@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

echo ======================================================
echo       Відправка оновлень модпаку на GitHub
echo ======================================================
echo.

if exist "%~dp0packwiz.exe" (
    echo [*] Оновлення індексів Packwiz...
    "%~dp0packwiz.exe" refresh
)

:: Знаходимо git
set "GIT_CMD=git"
where git >nul 2>nul
if %errorlevel% neq 0 (
    for /d %%D in ("%LOCALAPPDATA%\GitHubDesktop\app-*") do (
        if exist "%%D\resources\app\git\cmd\git.exe" set "GIT_CMD=%%D\resources\app\git\cmd\git.exe"
    )
)

echo.
echo [*] Поточна гілка та зміни у репозиторії:
for /f "delims=" %%B in ('"%GIT_CMD%" -C "%~dp0" rev-parse --abbrev-ref HEAD') do set "CUR_BRANCH=%%B"
echo Гілка: !CUR_BRANCH!
"%GIT_CMD%" -C "%~dp0" status --short
echo.

set /p TARGET_BRANCH="Введіть назву гілки для пушу (Enter для '!CUR_BRANCH!'): "
if "!TARGET_BRANCH!"=="" set "TARGET_BRANCH=!CUR_BRANCH!"

set /p COMMIT_MSG="Введіть опис змін (Enter для 'Оновлення модпаку'): "
if "!COMMIT_MSG!"=="" set "COMMIT_MSG=Оновлення модпаку"

echo.
echo [*] Збереження та відправка на GitHub у гілку !TARGET_BRANCH!...
if /i not "!TARGET_BRANCH!"=="!CUR_BRANCH!" (
    "%GIT_CMD%" -C "%~dp0" checkout -B "!TARGET_BRANCH!"
)
"%GIT_CMD%" -C "%~dp0" add .
"%GIT_CMD%" -C "%~dp0" commit -m "!COMMIT_MSG!"
"%GIT_CMD%" -C "%~dp0" push -u origin "!TARGET_BRANCH!"

if %errorlevel% equ 0 (
    echo.
    echo ======================================================
    echo  Успішно відправлено на GitHub ^(гілка: !TARGET_BRANCH!^)!
    echo ======================================================
) else (
    echo.
    echo [!] Виникла помилка під час push. Перевірте підключення або авторизацію.
)

echo.
pause
