-- Скрипт запуска тестирования совместимости автопилота
-- Запуск: lua test_runner.lua

print("Запуск тестирования совместимости автопилота для ETS 2")
print("======================================================")

-- Добавление пути к модулям
package.path = package.path .. ";./lua/?.lua"

-- Проверка наличия необходимых файлов
local required_files = {
    "manifest.sii",
    "def/autopilot/config.sii",
    "def/autopilot/settings.gui",
    "lua/autopilot_core.lua",
    "lua/logging.lua",
    "lua/navigation_parser.lua",
    "lua/vehicle_control.lua",
    "lua/test_compatibility.lua"
}

print("")
print("Проверка наличия необходимых файлов:")
print("------------------------------------")

local all_files_present = true
for _, file_path in ipairs(required_files) do
    local file = io.open(file_path, "r")
    if file then
        file:close()
        print("✓ " .. file_path)
    else
        print("✗ " .. file_path .. " - ОТСУТСТВУЕТ")
        all_files_present = false
    end
end

if not all_files_present then
    print("")
    print("ВНИМАНИЕ: Некоторые необходимые файлы отсутствуют!")
    print("Тестирование может быть неполным.")
    print("")
end

-- Загрузка и запуск тестов совместимости
print("")
print("Загрузка модуля тестирования совместимости...")

local success, test_module = pcall(require, "test_compatibility")

if not success then
    print("ОШИБКА: Не удалось загрузить модуль тестирования")
    print("Причина: " .. tostring(test_module))
    print("")
    print("Убедитесь, что файл lua/test_compatibility.lua существует")
    os.exit(1)
end

print("Модуль тестирования успешно загружен")
print("")

-- Настройка конфигурации тестирования
test_module.config = {
    test_modules = true,
    test_integration = true,
    test_performance = true,
    verbose_output = true,
    stop_on_error = false
}

-- Запуск тестов
print("Запуск всех тестов...")
print("")

local test_success = test_module.run_all_tests()

print("")
print("======================================================")

if test_success then
    print("✅ Тестирование завершено УСПЕШНО")
    print("   Автопилот совместим с ETS 2")
else
    print("⚠️  Тестирование завершено с ОШИБКАМИ")
    print("   Требуется доработка для полной совместимости")
end

print("")
print("Рекомендации по установке:")
print("1. Скопируйте папку autopilot_mod в mods/ вашей игры ETS 2")
print("2. Активируйте мод в меню модов игры")
print("3. В игре нажмите F5 для активации автопилота")
print("4. Нажмите F8 для открытия настроек автопилота")

print("")
print("Для получения дополнительной информации см. файлы:")
print("- README.md - общее описание мода")
print("- INSTALL_RU.md - инструкция по установке")
print("- logs/autopilot.log - логи работы (после запуска игры)")

os.exit(test_success and 0 or 1)