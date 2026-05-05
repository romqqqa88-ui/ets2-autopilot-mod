@echo off
REM Скрипт сборки Autopilot Mod для ETS 2
REM Создает архив .scs файл для установки

echo ========================================
echo    Autopilot Mod Builder v1.0
echo ========================================

set MOD_NAME=autopilot_mod
set VERSION=1.0.0
set OUTPUT_FILE=%MOD_NAME%_v%VERSION%.scs

echo.
echo Сборка мода: %MOD_NAME%
echo Версия: %VERSION%
echo.

REM Проверка наличия необходимых инструментов
where scs_archiver >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Ошибка: scs_archiver не найден!
    echo Установите SCS SDK Tools и добавьте в PATH
    pause
    exit /b 1
)

echo Шаг 1: Проверка структуры файлов...
if not exist manifest.sii (
    echo Ошибка: Файл manifest.sii не найден!
    pause
    exit /b 1
)

if not exist script\init.lua (
    echo Ошибка: Файл script\init.lua не найден!
    pause
    exit /b 1
)

echo Структура файлов проверена успешно.

echo.
echo Шаг 2: Создание временной директории...
set TEMP_DIR=%TEMP%\%MOD_NAME%_build
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"
mkdir "%TEMP_DIR%"

echo Копирование файлов...
xcopy /E /I /Y . "%TEMP_DIR%\" >nul

echo.
echo Шаг 3: Создание архива .scs...
scs_archiver --create "%OUTPUT_FILE%" --root "%TEMP_DIR%" --compress

if %ERRORLEVEL% neq 0 (
    echo Ошибка при создании архива!
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
echo Разместите файл в папке:
echo   Documents\Euro Truck Simulator 2\mod\
echo ========================================

echo.
echo Дополнительные команды:
echo   test.cmd     - запуск тестов
echo   clean.cmd    - очистка временных файлов
echo   docs.cmd     - генерация документации

pause