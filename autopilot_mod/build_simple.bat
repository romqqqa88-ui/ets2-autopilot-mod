@echo off
REM Простой скрипт сборки Autopilot Mod для ETS 2
REM Создает архив .zip файл с помощью tar

echo ========================================
echo    Autopilot Mod Builder (Simple)
echo ========================================

set MOD_NAME=autopilot_mod
set VERSION=1.0.0
set OUTPUT_FILE=%MOD_NAME%_v%VERSION%.zip

echo.
echo Сборка мода: %MOD_NAME%
echo Версия: %VERSION%
echo.

echo Шаг 1: Проверка основных файлов...
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

echo Основные файлы проверены успешно.

echo.
echo Шаг 2: Создание ZIP архива с помощью tar...
tar -a -cf "%OUTPUT_FILE%" * --exclude="*.bat" --exclude="*.zip" --exclude="*.scs" --exclude="logs\*" 2>nul

if not exist "%OUTPUT_FILE%" (
    echo Ошибка: Не удалось создать архив!
    echo Убедитесь, что tar доступен (Windows 10+)
    echo.
    echo Альтернатива: создайте архив вручную:
    echo   1. Выделите все файлы в папке autopilot_mod
    echo   2. Щелкните правой кнопкой -> Отправить -> Сжатая ZIP-папка
    echo   3. Переименуйте в autopilot_mod_v1.0.0.zip
    pause
    exit /b 1
)

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
echo ИЛИ оставьте как .zip и распакуйте в:
echo   Documents\Euro Truck Simulator 2\mod\autopilot_mod\
echo ========================================

echo.
dir "%OUTPUT_FILE%"
echo.
pause