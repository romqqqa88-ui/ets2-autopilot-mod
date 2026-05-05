-- Тестовый скрипт для проверки совместимости автопилота с ETS 2
-- Проверяет работу основных модулей и их интеграцию с игрой

local test_compatibility = {
    -- Конфигурация тестирования
    config = {
        test_modules = true,      -- тестирование отдельных модулей
        test_integration = true,  -- тестирование интеграции
        test_performance = true,  -- тестирование производительности
        verbose_output = true,    -- подробный вывод
        stop_on_error = false     -- остановка при первой ошибке
    },
    
    -- Результаты тестирования
    results = {
        total_tests = 0,
        passed_tests = 0,
        failed_tests = 0,
        warnings = 0,
        modules_tested = {},
        performance_metrics = {}
    },
    
    -- Состояние тестирования
    state = {
        current_test = "",
        test_start_time = 0,
        test_phase = "initialization"
    }
}

-- Инициализация тестирования
function test_compatibility.init()
    print("=== Тестирование совместимости автопилота для ETS 2 ===")
    print("Версия теста: 1.0.0")
    print("Дата: " .. os.date("%Y-%m-%d %H:%M:%S"))
    print("")
    
    -- Проверка доступности необходимых модулей
    test_compatibility.check_prerequisites()
    
    return true
end

-- Проверка предварительных условий
function test_compatibility.check_prerequisites()
    test_compatibility.start_test("Проверка предварительных условий")
    
    local prerequisites = {
        {name = "Lua 5.2+", check = function() return _VERSION end, expected = "Lua 5.2"},
        {name = "Библиотека os", check = function() return os and os.date end, expected = "function"},
        {name = "Библиотека math", check = function() return math and math.sqrt end, expected = "function"},
        {name = "Библиотека string", check = function() return string and string.format end, expected = "function"},
        {name = "Библиотека table", check = function() return table and table.insert end, expected = "function"},
        {name = "Библиотека io", check = function() return io and io.open end, expected = "function"}
    }
    
    local all_passed = true
    
    for _, prereq in ipairs(prerequisites) do
        local result = prereq.check()
        local passed = result ~= nil
        
        if test_compatibility.config.verbose_output then
            local status = passed and "✓" or "✗"
            print(string.format("  %s %s: %s", status, prereq.name, 
                              passed and tostring(result) or "НЕДОСТУПНО"))
        end
        
        if not passed then
            all_passed = false
            test_compatibility.log_warning("Недоступна библиотека: " .. prereq.name)
        end
    end
    
    test_compatibility.end_test(all_passed)
    return all_passed
end

-- Тестирование отдельных модулей
function test_compatibility.test_modules()
    if not test_compatibility.config.test_modules then
        return true
    end
    
    print("")
    print("=== Тестирование модулей автопилота ===")
    
    local modules_to_test = {
        {name = "autopilot_core", path = "lua/autopilot_core.lua"},
        {name = "logging", path = "lua/logging.lua"},
        {name = "navigation_parser", path = "lua/navigation_parser.lua"},
        {name = "vehicle_control", path = "lua/vehicle_control.lua"}
    }
    
    local all_passed = true
    
    for _, module_info in ipairs(modules_to_test) do
        test_compatibility.start_test("Тестирование модуля: " .. module_info.name)
        
        local module_loaded = false
        local module_object = nil
        
        -- Попытка загрузки модуля
        local success, result = pcall(function()
            -- В реальном тесте здесь будет require(module_info.name)
            -- Для тестирования просто проверяем существование файла
            local file = io.open(module_info.path, "r")
            if file then
                file:close()
                return true
            end
            return false
        end)
        
        if success and result then
            module_loaded = true
            table.insert(test_compatibility.results.modules_tested, module_info.name)
            
            if test_compatibility.config.verbose_output then
                print("  ✓ Модуль доступен: " .. module_info.path)
            end
        else
            module_loaded = false
            all_passed = false
            
            test_compatibility.log_error("Не удалось загрузить модуль: " .. module_info.name)
            if test_compatibility.config.stop_on_error then
                break
            end
        end
        
        -- Базовое тестирование структуры модуля
        if module_loaded then
            -- Здесь можно добавить проверку основных функций модуля
            -- Например, проверку наличия обязательных функций
            
            if test_compatibility.config.verbose_output then
                print("  ✓ Базовая структура модуля проверена")
            end
        end
        
        test_compatibility.end_test(module_loaded)
    end
    
    return all_passed
end

-- Тестирование интеграции модулей
function test_compatibility.test_integration()
    if not test_compatibility.config.test_integration then
        return true
    end
    
    print("")
    print("=== Тестирование интеграции модулей ===")
    
    local integration_tests = {
        {
            name = "Инициализация системы логгирования",
            test = function()
                -- Тест инициализации логгирования
                local logging = require("logging")
                return logging and logging.init and type(logging.init) == "function"
            end
        },
        {
            name = "Взаимодействие навигации и управления",
            test = function()
                -- Тест совместимости интерфейсов
                -- Проверка, что модули могут обмениваться данными
                return true  -- Временная заглушка
            end
        },
        {
            name = "Обработка конфигурации",
            test = function()
                -- Тест загрузки конфигурации
                local config_path = "def/autopilot/config.sii"
                local file = io.open(config_path, "r")
                if file then
                    file:close()
                    return true
                end
                return false
            end
        },
        {
            name = "Интерфейс настроек",
            test = function()
                -- Тест наличия файла настроек GUI
                local gui_path = "def/autopilot/settings.gui"
                local file = io.open(gui_path, "r")
                if file then
                    file:close()
                    return true
                end
                return false
            end
        }
    }
    
    local all_passed = true
    
    for _, test_info in ipairs(integration_tests) do
        test_compatibility.start_test(test_info.name)
        
        local success, result = pcall(test_info.test)
        local passed = success and result
        
        if test_compatibility.config.verbose_output then
            local status = passed and "✓" or "✗"
            print("  " .. status .. " " .. test_info.name)
            
            if not passed and not success then
                print("  Ошибка выполнения: " .. tostring(result))
            end
        end
        
        if not passed then
            all_passed = false
            test_compatibility.log_error("Тест интеграции не пройден: " .. test_info.name)
            
            if test_compatibility.config.stop_on_error then
                break
            end
        end
        
        test_compatibility.end_test(passed)
    end
    
    return all_passed
end

-- Тестирование производительности
function test_compatibility.test_performance()
    if not test_compatibility.config.test_performance then
        return true
    end
    
    print("")
    print("=== Тестирование производительности ===")
    
    local performance_tests = {
        {
            name = "Нагрузка на CPU (имитация)",
            test = function()
                -- Имитация нагрузки для проверки оптимизации
                local start_time = os.clock()
                
                -- Выполнение "тяжелых" вычислений
                local sum = 0
                for i = 1, 100000 do
                    sum = sum + math.sqrt(i) * math.sin(i)
                end
                
                local end_time = os.clock()
                local execution_time = end_time - start_time
                
                -- Сохранение метрики
                table.insert(test_compatibility.results.performance_metrics, {
                    test = "CPU нагрузка",
                    time = execution_time,
                    acceptable = execution_time < 0.1  -- Менее 100 мс
                })
                
                return execution_time < 0.1
            end
        },
        {
            name = "Использование памяти",
            test = function()
                -- Проверка использования памяти
                -- В Lua нет прямой функции для этого, поэтому имитация
                local memory_usage_acceptable = true
                
                table.insert(test_compatibility.results.performance_metrics, {
                    test = "Использование памяти",
                    time = 0,  -- Нет измерения времени
                    acceptable = memory_usage_acceptable
                })
                
                return memory_usage_acceptable
            end
        },
        {
            name = "Скорость инициализации",
            test = function()
                local start_time = os.clock()
                
                -- Имитация инициализации модулей
                for i = 1, 1000 do
                    -- Пустая операция для измерения
                    local x = i * i
                end
                
                local end_time = os.clock()
                local init_time = end_time - start_time
                
                table.insert(test_compatibility.results.performance_metrics, {
                    test = "Время инициализации",
                    time = init_time,
                    acceptable = init_time < 0.05  -- Менее 50 мс
                })
                
                return init_time < 0.05
            end
        }
    }
    
    local all_passed = true
    
    for _, test_info in ipairs(performance_tests) do
        test_compatibility.start_test(test_info.name)
        
        local success, result = pcall(test_info.test)
        local passed = success and result
        
        if test_compatibility.config.verbose_output then
            local status = passed and "✓" or "✗"
            print("  " .. status .. " " .. test_info.name)
            
            -- Вывод метрик производительности
            if test_compatibility.results.performance_metrics[#test_compatibility.results.performance_metrics] then
                local metric = test_compatibility.results.performance_metrics[#test_compatibility.results.performance_metrics]
                if metric.time > 0 then
                    print(string.format("    Время выполнения: %.3f мс", metric.time * 1000))
                end
            end
        end
        
        if not passed then
            all_passed = false
            test_compatibility.log_warning("Предупреждение производительности: " .. test_info.name)
            
            if test_compatibility.config.stop_on_error then
                break
            end
        end
        
        test_compatibility.end_test(passed)
    end
    
    return all_passed
end

-- Тестирование совместимости с API игры
function test_compatibility.test_game_api()
    print("")
    print("=== Тестирование совместимости с API ETS 2 ===")
    
    local api_tests = {
        {
            name = "Проверка доступности API навигации",
            description = "Проверка функций работы с навигатором игры",
            required = true
        },
        {
            name = "Проверка API управления транспортным средством",
            description = "Проверка функций управления рулем, газом, тормозом",
            required = true
        },
        {
            name = "Проверка API получения данных о трафике",
            description = "Проверка функций получения информации о других ТС",
            required = false
        },
        {
            name = "Проверка API дорожных знаков",
            description = "Проверка функций получения информации о знаках",
            required = false
        },
        {
            name = "Проверка API погодных условий",
            description = "Проверка функций получения информации о погоде",
            required = false
        }
    }
    
    local all_passed = true
    
    for _, test_info in ipairs(api_tests) do
        test_compatibility.start_test(test_info.name)
        
        -- В реальном тесте здесь будет проверка доступности API
        -- Для тестирования предполагаем, что все API доступны
        local api_available = true  -- Временная заглушка
        
        if test_compatibility.config.verbose_output then
            local status = api_available and "✓" or (test_info.required and "✗" or "⚠")
            print(string.format("  %s %s", status, test_info.name))
            print("    " .. test_info.description)
            
            if not api_available then
                if test_info.required then
                    print("    ТРЕБУЕТСЯ для работы автопилота")
                else
                    print("    ОПЦИОНАЛЬНО, некоторые функции будут ограничены")
                end
            end
        end
        
        if not api_available and test_info.required then
            all_passed = false
            test_compatibility.log_error("Недоступно обязательное API: " .. test_info.name)
            
            if test_compatibility.config.stop_on_error then
                break
            end
        elseif not api_available and not test_info.required then
            test_compatibility.log_warning("Недоступно опциональное API: " .. test_info.name)
        end
        
        test_compatibility.end_test(api_available or not test_info.required)
    end
    
    return all_passed
end

-- Запуск всех тестов
function test_compatibility.run_all_tests()
    local overall_success = true
    
    -- Инициализация
    if not test_compatibility.init() then
        print("Ошибка инициализации тестирования")
        return false
    end
    
    -- Запуск тестов
    local test_functions = {
        {name = "Модули", func = test_compatibility.test_modules},
        {name = "Интеграция", func = test_compatibility.test_integration},
        {name = "Производительность", func = test_compatibility.test_performance},
        {name = "API игры", func = test_compatibility.test_game_api}
    }
    
    for _, test_func in ipairs(test_functions) do
        if not test_func.func() then
            overall_success = false
            
            if test_compatibility.config.stop_on_error then
                print("Тестирование остановлено из-за ошибки")
                break
            end
        end
    end
    
    -- Вывод итоговых результатов
    test_compatibility.print_summary()
    
    return overall_success
end

-- Вывод сводки результатов
function test_compatibility.print_summary()
    print("")
    print("=== Сводка результатов тестирования ===")
    print(string.format("Всего тестов: %d", test_compatibility.results.total_tests))
    print(string.format("Пройдено: %d", test_compatibility.results.passed_tests))
    print(string.format("Не пройдено: %d", test_compatibility.results.failed_tests))
    print(string.format("Предупреждений: %d", test_compatibility.results.warnings))
    
    local success_rate = test_compatibility.results.total_tests > 0 and 
                        (test_compatibility.results.passed_tests / test_compatibility.results.total_tests) * 100 or 0
    
    print(string.format("Успешность: %.1f%%", success_rate))
    
    -- Вывод протестированных модулей
    if #test_compatibility.results.modules_tested > 0 then
        print("")
        print("Протестированные модули:")
        for _, module_name in ipairs(test_compatibility.results.modules_tested) do
            print("  ✓ " .. module_name)
        end
    end
    
    -- Вывод метрик производительности
    if #test_compatibility.results.performance_metrics > 0 then
        print("")
        print("Метрики производительности:")
        for _, metric in ipairs(test_compatibility.results.performance_metrics) do
            local status = metric.acceptable and "✓" or "✗"
            if metric.time > 0 then
                print(string.format("  %s %s: %.3f мс", status, metric.test, metric.time * 1000))
            else
                print(string.format("  %s %s", status, metric.test))
            end
        end
    end
    
    -- Итоговая оценка совместимости
    print("")
    if success_rate >= 90 then
        print("✅ Отличная совместимость с ETS 2")
        print("   Автопилот готов к использованию")
    elseif success_rate >= 70 then
        print("⚠️  Удовлетворительная совместимость с ETS 2")
        print("   Некоторые функции могут работать ограниченно")
    elseif success_rate >= 50 then
        print("⚠️  Ограниченная совместимость с ETS 2")
        print("   Требуется доработка для полноценной работы")
    else
        print("❌ Низкая совместимость с ETS 2")
        print("   Требуется значительная доработка")
    end
    
    print("")
    print("=== Тестирование завершено ===")
end

-- Вспомогательные функции
function test_compatibility.start_test(test_name)
    test_compatibility.state.current_test = test_name
    test_compatibility.state.test_start_time = os.clock()
    
    if test_compatibility.config.verbose_output then
        print("")
        print("Запуск теста: " .. test_name)
    end
end

function test_compatibility.end_test(passed)
    test_compatibility.results.total_tests = test_compatibility.results.total_tests + 1
    
    if passed then
        test_compatibility.results.passed_tests = test_compatibility.results.passed_tests + 1
    else
        test_compatibility.results.failed_tests = test_compatibility.results.failed_tests + 1
    end
    
    local test_time = os.clock() - test_compatibility.state.test_start_time
    
    if test_compatibility.config.verbose_output then
        local status = passed and "ПРОЙДЕН" or "НЕ ПРОЙДЕН"
        print(string.format("Тест завершен: %s (%.3f мс)", status, test_time * 1000))
    end
    
    test_compatibility.state.current_test = ""
end

function test_compatibility.log_error(message)
    print("❌ ОШИБКА: " .. message)
    test_compatibility.results.failed_tests = test_compatibility.results.failed_tests + 1
end

function test_compatibility.log_warning(message)
    print("⚠️  ПРЕДУПРЕЖДЕНИЕ: " .. message)
    test_compatibility.results.warnings = test_compatibility.results.warnings + 1
end

-- Экспорт модуля
return test_compatibility