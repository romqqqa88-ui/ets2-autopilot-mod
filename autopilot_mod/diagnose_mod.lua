-- Диагностический скрипт для проверки работы мода автопилота
-- Запуск: lua diagnose_mod.lua

print("=== Диагностика мода автопилота для ETS 2 ===")
print("Версия диагностики: 1.0.0")
print("")

-- 1. Проверка структуры файлов
print("1. Проверка структуры файлов:")
print("--------------------------------")

local essential_files = {
    {path = "manifest.sii", description = "Манифест мода"},
    {path = "def/autopilot/config.sii", description = "Конфигурация"},
    {path = "lua/autopilot_core.lua", description = "Основной модуль"},
    {path = "lua/logging.lua", description = "Модуль логгирования"},
    {path = "lua/navigation_parser.lua", description = "Парсер навигации"},
    {path = "lua/vehicle_control.lua", description = "Управление ТС"}
}

local missing_files = {}
for _, file_info in ipairs(essential_files) do
    local file = io.open(file_info.path, "r")
    if file then
        file:close()
        print("✓ " .. file_info.path .. " - " .. file_info.description)
    else
        print("✗ " .. file_info.path .. " - ОТСУТСТВУЕТ (" .. file_info.description .. ")")
        table.insert(missing_files, file_info.path)
    end
end

if #missing_files > 0 then
    print("")
    print("ОШИБКА: Отсутствуют важные файлы!")
    print("Мод не будет работать без этих файлов.")
end

-- 2. Проверка синтаксиса Lua файлов
print("")
print("2. Проверка синтаксиса Lua файлов:")
print("-----------------------------------")

local lua_files = {
    "lua/autopilot_core.lua",
    "lua/logging.lua", 
    "lua/navigation_parser.lua",
    "lua/vehicle_control.lua"
}

local syntax_errors = {}
for _, lua_file in ipairs(lua_files) do
    local file = io.open(lua_file, "r")
    if file then
        local content = file:read("*a")
        file:close()
        
        -- Простая проверка на наличие очевидных синтаксических ошибок
        local has_function_keyword = content:find("function%s+")
        local has_end_keyword = content:find("end")
        local has_return_statement = content:find("return%s+")
        
        if has_function_keyword and has_end_keyword then
            print("✓ " .. lua_file .. " - базовый синтаксис OK")
        else
            print("⚠ " .. lua_file .. " - возможные синтаксические проблемы")
            table.insert(syntax_errors, lua_file)
        end
    else
        print("✗ " .. lua_file .. " - файл не найден")
        table.insert(syntax_errors, lua_file)
    end
end

-- 3. Проверка манифеста
print("")
print("3. Проверка манифеста (manifest.sii):")
print("--------------------------------------")

local manifest_file = io.open("manifest.sii", "r")
if manifest_file then
    local manifest_content = manifest_file:read("*a")
    manifest_file:close()
    
    -- Проверка ключевых полей
    local checks = {
        {pattern = "mod_package", name = "Определение пакета мода"},
        {pattern = "package_name", name = "Название пакета"},
        {pattern = "package_version", name = "Версия пакета"},
        {pattern = "compatible_versions", name = "Совместимые версии"},
        {pattern = "mod_data", name = "Данные мода"}
    }
    
    for _, check in ipairs(checks) do
        if manifest_content:find(check.pattern) then
            print("✓ " .. check.name)
        else
            print("✗ " .. check.name .. " - не найдено")
        end
    end
    
    -- Проверка версии 1.58
    if manifest_content:find('"1%.58"') then
        print("✓ Поддержка версии 1.58")
    else
        print("✗ Поддержка версии 1.58 - не найдена")
    end
else
    print("✗ Файл manifest.sii не найден")
end

-- 4. Проверка структуры для ETS 2
print("")
print("4. Проверка структуры для ETS 2:")
print("---------------------------------")

local ets2_structure = {
    {path = "def/", is_dir = true, description = "Директория определений"},
    {path = "lua/", is_dir = true, description = "Директория скриптов"},
    {path = "material/", is_dir = true, description = "Директория материалов"},
    {path = "ui/", is_dir = true, description = "Директория интерфейса"},
    {path = "def/autopilot/", is_dir = true, description = "Конфигурация автопилота"}
}

for _, item in ipairs(ets2_structure) do
    if item.is_dir then
        -- Проверка существования директории
        local test_file = item.path .. "/.test"
        local file = io.open(test_file, "w")
        if file then
            file:close()
            os.remove(test_file)
            print("✓ " .. item.path .. " - " .. item.description)
        else
            -- Попытка создать директорию
            os.execute("mkdir \"" .. item.path .. "\" 2>nul")
            print("⚠ " .. item.path .. " - создана (" .. item.description .. ")")
        end
    end
end

-- 5. Проверка точки входа
print("")
print("5. Проверка точки входа:")
print("-------------------------")

-- В ETS 2 моды обычно загружаются через manifest.sii
-- Lua скрипты должны быть указаны в mod_data[]

local entry_points = {
    {type = "Lua модуль", file = "lua/autopilot_core.lua", check = "return statement"},
    {type = "Конфигурация", file = "def/autopilot/config.sii", check = "SiiNunit format"},
    {type = "Интерфейс", file = "def/autopilot/settings.gui", check = "gui definition"}
}

for _, entry in ipairs(entry_points) do
    local file = io.open(entry.file, "r")
    if file then
        local content = file:read("*a")
        file:close()
        
        if #content > 100 then  -- Минимальный размер файла
            print("✓ " .. entry.type .. " - " .. entry.file .. " (" .. entry.check .. ")")
        else
            print("⚠ " .. entry.type .. " - " .. entry.file .. " (маленький файл)")
        end
    else
        print("✗ " .. entry.type .. " - " .. entry.file .. " (не найден)")
    end
end

-- 6. Рекомендации по устранению неполадок
print("")
print("6. Рекомендации по устранению неполадок:")
print("------------------------------------------")

if #missing_files == 0 and #syntax_errors == 0 then
    print("✓ Базовая структура мода в порядке")
    print("")
    print("Возможные причины, почему мод не работает:")
    print("1. Мод не активирован в меню модов игры")
    print("2. Конфликт с другими модами")
    print("3. Неправильная установка (не в папку mods/)")
    print("4. Требуется перезапуск игры после активации мода")
    print("5. Отсутствуют зависимости (DLC)")
else
    print("⚠ Обнаружены проблемы со структурой мода:")
    
    if #missing_files > 0 then
        print("   - Отсутствуют файлы: " .. table.concat(missing_files, ", "))
        print("     Решение: Восстановите недостающие файлы")
    end
    
    if #syntax_errors > 0 then
        print("   - Проблемы с синтаксисом в: " .. table.concat(syntax_errors, ", "))
        print("     Решение: Проверьте правильность Lua кода")
    end
end

print("")
print("7. Шаги по диагностике в игре:")
print("-------------------------------")
print("1. Убедитесь, что мод активирован в 'Меню модов'")
print("2. Проверьте консоль игры (обычно ~) на наличие ошибок")
print("3. Ищите файл logs/autopilot.log после запуска игры")
print("4. Попробуйте отключить другие моды для проверки конфликтов")
print("5. Убедитесь, что версия игры 1.58 (напишите 'g_version' в консоли)")

print("")
print("=== Диагностика завершена ===")
print("")
print("Для получения дополнительной помощи:")
print("- Проверьте файл INSTALL_RU.md для инструкций по установке")
print("- Запустите test_runner.lua для расширенного тестирования")
print("- Проверьте папку logs/ после запуска игры с модом")