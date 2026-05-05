-- Упрощенная версия автопилота для быстрой проверки работы
-- Этот файл можно использовать как альтернативную точку входа

print("[Simple Autopilot] Упрощенный автопилот загружен")

-- Глобальные переменные
local autopilot_enabled = false
local autopilot_active = false
local last_toggle_time = 0
local toggle_cooldown = 1.0  -- секунды

-- Основная функция обновления
local function update_autopilot(dt)
    if not autopilot_enabled then
        return
    end
    
    -- Здесь будет логика автопилота
    -- Пока просто выводим сообщение каждые 5 секунд
    local current_time = os.clock()
    
    if current_time - last_toggle_time > 5.0 then
        print("[Simple Autopilot] Автопилот активен (заглушка)")
        last_toggle_time = current_time
    end
end

-- Включение/выключение автопилота
local function toggle_autopilot()
    local current_time = os.clock()
    
    if current_time - last_toggle_time < toggle_cooldown then
        return  -- Защита от слишком частых переключений
    end
    
    autopilot_enabled = not autopilot_enabled
    last_toggle_time = current_time
    
    local status = autopilot_enabled and "ВКЛЮЧЕН" or "ВЫКЛЮЧЕН"
    print("[Simple Autopilot] Автопилот " .. status)
    
    -- Попытка показать уведомление в игре
    if game and game.showNotification then
        game.showNotification("Автопилот " .. status)
    end
    
    return autopilot_enabled
end

-- Регистрация горячих клавиш
local function register_hotkeys()
    print("[Simple Autopilot] Регистрация горячих клавиш...")
    
    -- Обработчик нажатия клавиш (если доступен)
    if onKey then
        local original_onKey = onKey
        
        function onKey(key, down, num1, num2)
            -- Вызов оригинального обработчика
            if original_onKey then
                original_onKey(key, down, num1, num2)
            end
            
            -- Обработка горячих клавиш с CTRL
            -- num1 содержит модификаторы: 1=Shift, 2=Ctrl, 4=Alt
            local ctrl_pressed = (num1 and (num1 & 2) ~= 0) or false
            
            if down and ctrl_pressed then
                -- CTRL + A (код 30) - включить/выключить автопилот
                if key == 30 then
                    toggle_autopilot()
                    return true  -- Событие обработано
                end
                
                -- CTRL + S (код 31) - показать статус
                if key == 31 then
                    print("[Simple Autopilot] Статус: " .. (autopilot_enabled and "ВКЛЮЧЕН" or "ВЫКЛЮЧЕН"))
                    return true
                end
                
                -- CTRL + D (код 32) - экстренная остановка
                if key == 32 then
                    print("[Simple Autopilot] ЭКСТРЕННАЯ ОСТАНОВКА! Автопилот отключен")
                    autopilot_enabled = false
                    return true
                end
            end
            
            return false
        end
        
        print("[Simple Autopilot] Горячие клавиши зарегистрированы: CTRL+A - вкл/выкл, CTRL+S - статус, CTRL+D - экстренная остановка")
    else
        print("[Simple Autopilot] Предупреждение: onKey не доступен, горячие клавиши не работают")
    end
end

-- Регистрация консольных команд
local function register_console_commands()
    print("[Simple Autopilot] Регистрация консольных команд...")
    
    if registerConsoleCommand then
        -- Команда для включения/выключения автопилота
        registerConsoleCommand("autopilot", "Включить/выключить автопилот", function()
            toggle_autopilot()
        end)
        
        -- Команда для проверки статуса
        registerConsoleCommand("autopilot_status", "Показать статус автопилота", function()
            print("[Simple Autopilot] Статус: " .. (autopilot_enabled and "ВКЛЮЧЕН" or "ВЫКЛЮЧЕН"))
        end)
        
        print("[Simple Autopilot] Консольные команды зарегистрированы:")
        print("  autopilot - включить/выключить автопилот")
        print("  autopilot_status - показать статус")
    else
        print("[Simple Autopilot] Предупреждение: registerConsoleCommand не доступен")
    end
end

-- Интеграция с игровым циклом
local function integrate_with_game()
    print("[Simple Autopilot] Интеграция с игровым циклом...")
    
    -- Обработчик обновления игры
    if onUpdate then
        local original_onUpdate = onUpdate
        
        function onUpdate(dt)
            -- Вызов оригинального обработчика
            if original_onUpdate then
                original_onUpdate(dt)
            end
            
            -- Обновление автопилота
            update_autopilot(dt)
        end
        
        print("[Simple Autopilot] Интегрирован с onUpdate")
    else
        print("[Simple Autopilot] Предупреждение: onUpdate не доступен, автопилот не будет обновляться")
    end
    
    -- Обработчик загрузки уровня
    if onLevelLoaded then
        local original_onLevelLoaded = onLevelLoaded
        
        function onLevelLoaded()
            -- Вызов оригинального обработчика
            if original_onLevelLoaded then
                original_onLevelLoaded()
            end
            
            print("[Simple Autopilot] Уровень загружен, автопилот готов к работе")
        end
        
        print("[Simple Autopilot] Интегрирован с onLevelLoaded")
    end
end

-- Основная функция инициализации
local function initialize_simple_autopilot()
    print("[Simple Autopilot] Инициализация упрощенного автопилота...")
    
    -- Регистрация горячих клавиш
    register_hotkeys()
    
    -- Регистрация консольных команд
    register_console_commands()
    
    -- Интеграция с игровым циклом
    integrate_with_game()
    
    print("[Simple Autopilot] Инициализация завершена")
    print("[Simple Autopilot] Используйте CTRL+A для включения/выключения автопилота")
    print("[Simple Autopilot] Используйте CTRL+S для проверки статуса")
    print("[Simple Autopilot] Используйте CTRL+D для экстренной остановки")
    print("[Simple Autopilot] Или введите в консоли: autopilot")
    
    return true
end

-- Автоматическая инициализация при загрузке
local function auto_initialize()
    -- Небольшая задержка для полной загрузки игры
    local init_attempts = 0
    local max_attempts = 10
    
    local function try_initialize(dt)
        init_attempts = init_attempts + 1
        
        if init_attempts >= max_attempts then
            print("[Simple Autopilot] ОШИБКА: Не удалось инициализировать (превышено количество попыток)")
            return true
        end
        
        -- Проверка доступности необходимых функций
        if onUpdate or onKey then
            initialize_simple_autopilot()
            return true
        end
        
        -- Продолжить попытки
        if init_attempts == 1 then
            print("[Simple Autopilot] Ожидание инициализации игры...")
        end
        
        return false
    end
    
    -- Использование onUpdate для отложенной инициализации
    if onUpdate then
        local original_onUpdate = onUpdate
        
        function onUpdate(dt)
            if original_onUpdate then
                original_onUpdate(dt)
            end
            
            if not try_initialize(dt) then
                -- Продолжаем ждать
            end
        end
    else
        -- Немедленная попытка инициализации
        initialize_simple_autopilot()
    end
end

-- Запуск автоматической инициализации
auto_initialize()

-- Экспорт функций для тестирования
return {
    toggle = toggle_autopilot,
    isEnabled = function() return autopilot_enabled end,
    update = update_autopilot,
    initialize = initialize_simple_autopilot
}