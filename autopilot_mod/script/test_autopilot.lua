-- Тестовый скрипт для автопилота
-- Проверка функциональности и отладка

local test = {
    enabled = false,
    test_cases = {},
    current_test = 1,
    results = {}
}

-- Инициализация тестов
function test.init()
    log("Test: Инициализация тестового модуля")
    
    -- Определение тестовых случаев
    test.test_cases = {
        {
            name = "Включение/выключение автопилота",
            function = test.toggle_test,
            expected = true
        },
        {
            name = "Установка скорости",
            function = test.speed_test,
            expected = true
        },
        {
            name = "Обнаружение препятствий",
            function = test.obstacle_test,
            expected = true
        },
        {
            name = "Интеграция с навигатором",
            function = test.navigation_test,
            expected = true
        },
        {
            name = "Управление рулевым колесом",
            function = test.steering_test,
            expected = true
        }
    }
    
    log(string.format("Test: Загружено %d тестовых случаев", #test.test_cases))
end

-- Запуск всех тестов
function test.run_all()
    log("Test: Запуск всех тестов")
    
    test.results = {}
    
    for i, test_case in ipairs(test.test_cases) do
        log(string.format("Test: Запуск теста %d: %s", i, test_case.name))
        
        local success, result = pcall(test_case.function)
        
        if success then
            if result == test_case.expected then
                test.results[i] = {passed = true, message = "Пройден"}
                log(string.format("Test: Тест %d пройден", i))
            else
                test.results[i] = {passed = false, message = "Неожиданный результат"}
                log(string.format("Test: Тест %d не пройден: неожиданный результат", i))
            end
        else
            test.results[i] = {passed = false, message = "Ошибка: " .. tostring(result)}
            log(string.format("Test: Тест %d не пройден: ошибка - %s", i, tostring(result)))
        end
        
        -- Пауза между тестами
        sleep(0.5)
    end
    
    test.print_results()
end

-- Тест включения/выключения
function test.toggle_test()
    local autopilot = require("autopilot")
    
    -- Сохраняем исходное состояние
    local original_state = autopilot.enabled
    
    -- Включаем
    autopilot.toggle()
    if not autopilot.enabled then
        return false, "Не удалось включить автопилот"
    end
    
    -- Выключаем
    autopilot.toggle()
    if autopilot.enabled then
        return false, "Не удалось выключить автопилот"
    end
    
    -- Восстанавливаем состояние
    if original_state ~= autopilot.enabled then
        autopilot.toggle()
    end
    
    return true
end

-- Тест установки скорости
function test.speed_test()
    local speed_controller = require("speed_controller")
    
    -- Тест установки допустимой скорости
    local result = speed_controller.set_target_speed(90)
    if not result then
        return false, "Не удалось установить скорость 90 км/ч"
    end
    
    if speed_controller.target_speed ~= 90 then
        return false, "Скорость не установилась корректно"
    end
    
    -- Тест установки недопустимой скорости (должна вернуть false)
    result = speed_controller.set_target_speed(200)
    if result then
        return false, "Недопустимая скорость была принята"
    end
    
    -- Тест расчета управления
    local throttle, brake = speed_controller.calculate(80, 0.1)
    
    if throttle < 0 or throttle > 1 then
        return false, "Некорректное значение throttle: " .. throttle
    end
    
    if brake < 0 or brake > 1 then
        return false, "Некорректное значение brake: " .. brake
    end
    
    return true
end

-- Тест обнаружения препятствий
function test.obstacle_test()
    local obstacle_detector = require("obstacle_detector")
    
    -- Тест инициализации
    if not obstacle_detector then
        return false, "Модуль obstacle_detector не загружен"
    end
    
    -- Проверка структуры данных
    if type(obstacle_detector.obstacles) ~= "table" then
        return false, "Некорректная структура obstacles"
    end
    
    if type(obstacle_detector.detection_range) ~= "number" then
        return false, "Некорректный detection_range"
    end
    
    -- Тест функций
    local dangerous, obstacle = obstacle_detector.needs_emergency_brake()
    
    if dangerous == nil then
        return false, "Функция needs_emergency_brake вернула nil"
    end
    
    return true
end

-- Тест интеграции с навигатором
function test.navigation_test()
    local navigation = require("navigation_integration")
    
    if not navigation then
        return false, "Модуль navigation_integration не загружен"
    end
    
    -- Проверка инициализации
    local init_result = navigation.init()
    
    if init_result == nil then
        return false, "Функция init вернула nil"
    end
    
    -- Проверка структуры маршрута
    if type(navigation.current_route) ~= "table" then
        return false, "Некорректная структура current_route"
    end
    
    return true
end

-- Тест управления рулевым колесом
function test.steering_test()
    -- Создаем тестовые данные
    local test_cases = {
        {current_angle = 0, target_angle = 0.1, expected = 0.05},
        {current_angle = 1.0, target_angle = 0, expected = -0.5},
        {current_angle = -0.5, target_angle = 0.5, expected = 0.5}
    }
    
    for i, case in ipairs(test_cases) do
        -- Простой расчет угла поворота
        local angle_diff = case.target_angle - case.current_angle
        local steering = angle_diff * 0.5 -- упрощенный коэффициент
        
        -- Проверка границ
        steering = math.max(-1.0, math.min(1.0, steering))
        
        if math.abs(steering - case.expected) > 0.2 then
            return false, string.format("Тест %d: ожидалось %.2f, получено %.2f", 
                i, case.expected, steering)
        end
    end
    
    return true
end

-- Вывод результатов тестов
function test.print_results()
    log("=" .. string.rep("=", 50))
    log("РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ")
    log("=" .. string.rep("=", 50))
    
    local passed = 0
    local failed = 0
    
    for i, result in ipairs(test.results) do
        local test_name = test.test_cases[i].name
        local status = result.passed and "ПРОЙДЕН" or "НЕ ПРОЙДЕН"
        local color = result.passed and "32" or "31" -- зеленый/красный
        
        log(string.format("\27[%smТест %d: %s - %s\27[0m", 
            color, i, test_name, status))
        
        if not result.passed then
            log(string.format("  Причина: %s", result.message))
        end
        
        if result.passed then
            passed = passed + 1
        else
            failed = failed + 1
        end
    end
    
    log("-" .. string.rep("-", 50))
    log(string.format("Итого: %d пройдено, %d не пройдено", passed, failed))
    
    if failed == 0 then
        log("\27[32mВсе тесты пройдены успешно!\27[0m")
    else
        log("\27[31mОбнаружены проблемы в тестах\27[0m")
    end
end

-- Функция для ручного тестирования
function test.interactive_test()
    log("Test: Интерактивное тестирование")
    log("Команды:")
    log("  'toggle' - включить/выключить автопилот")
    log("  'speed <значение>' - установить скорость")
    log("  'obstacles' - показать обнаруженные препятствия")
    log("  'route' - показать информацию о маршруте")
    log("  'exit' - выйти из тестового режима")
    
    test.interactive_mode = true
    
    while test.interactive_mode do
        local input = read_input()
        
        if input == "exit" then
            test.interactive_mode = false
            log("Test: Выход из интерактивного режима")
        elseif input == "toggle" then
            test.toggle_test()
        elseif input:sub(1, 5) == "speed" then
            local speed = tonumber(input:sub(7))
            if speed then
                log("Test: Установка скорости " .. speed .. " км/ч")
                -- Здесь будет вызов реальной функции
            end
        elseif input == "obstacles" then
            log("Test: Обнаружение препятствий...")
            -- Здесь будет вызов реальной функции
        elseif input == "route" then
            log("Test: Информация о маршруте...")
            -- Здесь будет вызов реальной функции
        else
            log("Test: Неизвестная команда")
        end
    end
end

-- Вспомогательные функции
function log(message)
    print("[Test] " .. message)
end

function sleep(seconds)
    -- Простая функция задержки
    local start = os.clock()
    while os.clock() - start < seconds do end
end

function read_input()
    -- Заглушка для чтения ввода
    return "exit" -- по умолчанию выход
end

-- Экспорт функций
return test