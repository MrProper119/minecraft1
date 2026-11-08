@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

echo ======================================================
echo           Додавання нового моду в модпак
echo ======================================================
echo.
set /p MOD_INPUT="Введіть назву моду або посилання (Modrinth / CurseForge): "

if "%MOD_INPUT%"=="" (
    echo Порожнє введення. Скасовано.
    pause
    exit /b 0
)

echo.
echo [*] Пошук та додавання моду: %MOD_INPUT% ...

echo %MOD_INPUT% | findstr /i "curseforge.com" > nul
if %errorlevel% equ 0 (
    "%~dp0packwiz.exe" curseforge add "%MOD_INPUT%" -y
    goto finish
)

echo %MOD_INPUT% | findstr /i "modrinth.com" > nul
if %errorlevel% equ 0 (
    "%~dp0packwiz.exe" modrinth add "%MOD_INPUT%" -y
    goto finish
)

echo Спроба знайти на Modrinth...
"%~dp0packwiz.exe" modrinth add "%MOD_INPUT%" -y
if %errorlevel% equ 0 goto finish

echo Не знайдено на Modrinth. Спроба знайти на CurseForge...
"%~dp0packwiz.exe" curseforge add "%MOD_INPUT%" -y

:finish
echo.
echo [*] Оновлення індексу Packwiz...
"%~dp0packwiz.exe" refresh
echo.
echo ======================================================
echo  Мод додано! Щоб застосувати зміни у грі:
echo  1. Запустіть sync.bat для завантаження моду у ваш Minecraft.
echo  2. Запустіть push_changes.bat для відправки оновлення другу.
echo ======================================================
echo.
pause
