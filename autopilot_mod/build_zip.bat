@echo off
REM Скрипт сборки Autopilot Mod для ETS 2 в формате ZIP
REM Создает архив .zip файл для установки

echo ========================================
echo    Autopilot Mod ZIP Builder v1.0
echo ========================================

set MOD_NAME=autopilot_mod
set VERSION=1.0.0
set OUTPUT_FILE=%MOD_NAME%_v%VERSION%.zip

echo.
echo Сборка мода: %MOD_NAME%
echo Версия: %VERSION%
echo.

echo Шаг 1: Проверка структуры файлов...
if not exist manifest.sii (
    echo Ошибка: Файл manifest.sii не найден!
    pause
    exit /b 1
)

if not exist init.lua (
    echo Ошибка: Файл init.lua не найден!
    pause
    exit /b 1
)

echo Структура файлов проверена успешно.

echo.
echo Шаг 2: Создание временной директории...
set TEMP_DIR=%TEMP%\%MOD_NAME%_zip_build
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"
mkdir "%TEMP_DIR%"

echo Копирование файлов...
xcopy /E /I /Y . "%TEMP_DIR%\" >nul

echo.
echo Шаг 3: Создание ZIP архива...
cd /d "%TEMP_DIR%"
powershell -Command "Compress-Archive -Path '*' -DestinationPath '..\%OUTPUT_FILE%' -Force"
cd /d "%~dp0"

if not exist "%OUTPUT_FILE%" (
    echo Ошибка при создании ZIP архива!
    pause
    exit /b 1
)

echo.
echo Шаг 4: Очистка временных файлов...
rmdir /s /q "%TEMP_DIR%"

echo.
echo ========================================
echo Сборка завершена успешно!
echo Создан файл: %OUTPUT_FILE%
echo.
echo Размер файла: 
for %%F in ("%OUTPUT_FILE%") do echo   %%~zF байт
echo.
echo Инструкция по установке:
echo   1. Переименуйте файл в autopilot_mod.scs
echo   2. Поместите в папку:
echo      Documents\Euro Truck Simulator 2\mod\
echo   3. Запустите игру и активируйте мод в меню модов
echo.
echo Альтернативно, можно оставить как .zip и распаковать
echo в папку mods\autopilot_mod\ (для тестирования)
echo ========================================

echo.
pause