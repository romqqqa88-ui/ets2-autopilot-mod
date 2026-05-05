-- Точка входа для мода автопилота в ETS 2
-- Этот файл загружается игрой при запуске мода

print("[Autopilot Mod] Инициализация мода автопилота для ETS 2")

-- Глобальные переменные для доступа из других скриптов
AUTOPILOT_MOD = {
    name = "Autopilot Mod",
    version = "1.0.0",
    author = "Mod Developer",
    enabled = false,
    initialized = false
}

-- Основная функция инициализации мода
local function initialize_autopilot()
    print("[Autopilot Mod] Загрузка модулей автопилота...")
    
    -- Добавление пути к модулям
    package.path = package.path .. ";./autopilot_mod/lua/?.lua"
    
    -- Попытка загрузить основной модуль
    local success, autopilot_core = pcall(require, "autopilot_core")
    
    if not success then
        print("[Autopilot Mod] ОШИБКА: Не удалось загрузить autopilot_core.lua")
        print("[Autopilot Mod] Причина: " .. tostring(autopilot_core))
        return false
    end
    
    -- Инициализация автопилота
    if autopilot_core.init then
        local init_success = autopilot_core.init()
        
        if init_success then
            print("[Autopilot Mod] Автопилот успешно инициализирован")
            AUTOPILOT_MOD.initialized = true
            AUTOPILOT_MOD.core = autopilot_core
            
            -- Регистрация обработчиков
            register_autopilot_handlers()
            
            return true
        else
            print("[Autopilot Mod] ОШИБКА: Инициализация автопилота не удалась")
            return false
        end
    else
        print("[Autopilot Mod] ОШИБКА: autopilot_core.init не найден")
        return false
    end
end

-- Регистрация обработчиков событий игры
local function register_autopilot_handlers()
    print("[Autopilot Mod] Регистрация обработчиков...")
    
    -- Обработчик обновления игры (вызывается каждый кадр)
    if onUpdate then
        local original_onUpdate = onUpdate
        
        function onUpdate(dt)
            -- Вызов оригинального обработчика
            if original_onUpdate then
                original_onUpdate(dt)
            end
            
            -- Обновление автопилота
            if AUTOPILOT_MOD.initialized and AUTOPILOT_MOD.core and AUTOPILOT_MOD.core.update then
                AUTOPILOT_MOD.core.update(dt)
            end
        end
        
        print("[Autopilot Mod] Обработчик onUpdate зарегистрирован")
    end
    
    -- Обработчик нажатия клавиш
    if onKey then
        local original_onKey = onKey
        
        function onKey(key, down, num1, num2)
            -- Вызов оригинального обработчика
            if original_onKey then
                original_onKey(key, down, num1, num2)
            end
            
            -- Обработка горячих клавиш автопилота
            if down then
                -- Проверка модификаторов клавиш
                -- В ETS 2 num1 может содержать информацию о модификаторах:
                -- 1 = Shift, 2 = Ctrl, 4 = Alt, 8 = Win (обычно)
                -- Используем несколько методов проверки для надежности
                local ctrl_pressed = false
                local shift_pressed = false
                local alt_pressed = false
                
                if num1 then
                    -- Метод 1: Битовая маска (стандартный для ETS 2)
                    ctrl_pressed = (num1 & 2) ~= 0
                    shift_pressed = (num1 & 1) ~= 0
                    alt_pressed = (num1 & 4) ~= 0
                    
                    -- Метод 2: Альтернативная проверка (для совместимости)
                    if not ctrl_pressed then
                        -- Некоторые моды могут использовать другую систему
                        ctrl_pressed = (num1 % 4 >= 2)
                    end
                end
                
                -- Основные горячие клавиши: CTRL + буква
                if ctrl_pressed then
                    -- CTRL + A (код 30) - включить/выключить автопилот
                    if key == 30 then
                        toggle_autopilot()
                        return true  -- Событие обработано
                    end
                    
                    -- CTRL + S (код 31) - открыть настройки
                    if key == 31 then
                        open_autopilot_settings()
                        return true  -- Событие обработано
                    end
                    
                    -- CTRL + D (код 32) - экстренная остановка
                    if key == 32 then
                        emergency_stop()
                        return true  -- Событие обработано
                    end
                end
                
                -- Альтернативные горячие клавиши (если CTRL не работает)
                -- NumPad 0 (код 82) - включить/выключить автопилот
                if key == 82 then  -- NumPad 0
                    toggle_autopilot()
                    return true
                end
                
                -- NumPad 1 (код 79) - открыть настройки
                if key == 79 then  -- NumPad 1
                    open_autopilot_settings()
                    return true
                end
                
                -- F10 (код 68) - экстренная остановка
                if key == 68 then  -- F10
                    emergency_stop()
                    return true
                end
            end
            
            return false
        end
        
        print("[Autopilot Mod] Обработчик onKey зарегистрирован")
        print("[Autopilot Mod] Основные горячие клавиши: CTRL+A, CTRL+S, CTRL+D")
        print("[Autopilot Mod] Альтернативные клавиши: NumPad 0, NumPad 1, F10")
    end
    
    -- Обработчик консольных команд
    registerConsoleCommand("autopilot_toggle", "Включить/выключить автопилот", function()
        toggle_autopilot()
    end)
    
    registerConsoleCommand("autopilot_status", "Показать статус автопилота", function()
        show_autopilot_status()
    end)
    
    print("[Autopilot Mod] Консольные команды зарегистрированы")
end

-- Включение/выключение автопилота
local function toggle_autopilot()
    if not AUTOPILOT_MOD.initialized or not AUTOPILOT_MOD.core then
        print("[Autopilot Mod] Автопилот не инициализирован")
        return
    end
    
    if AUTOPILOT_MOD.core.toggle then
        AUTOPILOT_MOD.core.toggle()
        AUTOPILOT_MOD.enabled = not AUTOPILOT_MOD.enabled
        
        local status = AUTOPILOT_MOD.enabled and "ВКЛЮЧЕН" or "ВЫКЛЮЧЕН"
        print("[Autopilot Mod] Автопилот " .. status)
        
        -- Показать уведомление в игре
        if game then
            game.showNotification("Автопилот " .. status)
        end
    else
        print("[Autopilot Mod] ОШИБКА: Функция toggle не найдена")
    end
end

-- Открытие настроек автопилота
local function open_autopilot_settings()
    print("[Autopilot Mod] Открытие настроек...")
    
    -- В реальной реализации здесь будет открытие GUI
    -- Пока просто выводим сообщение
    print("[Autopilot Mod] Настройки автопилота (реализация GUI в разработке)")
    
    if game then
        game.showNotification("Настройки автопилота открыты")
    end
end

-- Экстренная остановка автопилота
local function emergency_stop()
    print("[Autopilot Mod] Экстренная остановка автопилота!")
    
    -- Отключение автопилота
    AUTOPILOT_MOD.enabled = false
    
    -- Вызов функции экстренной остановки в основном модуле
    if AUTOPILOT_MOD.core and AUTOPILOT_MOD.core.emergency_stop then
        AUTOPILOT_MOD.core.emergency_stop()
    end
    
    -- Показать уведомление в игре
    if game then
        game.showNotification("ЭКСТРЕННАЯ ОСТАНОВКА! Автопилот отключен")
    end
    
    print("[Autopilot Mod] Автопилот отключен по экстренной остановке")
end

-- Показать статус автопилота
local function show_autopilot_status()
    if not AUTOPILOT_MOD.initialized then
        print("[Autopilot Mod] Статус: НЕ ИНИЦИАЛИЗИРОВАН")
        return
    end
    
    print("[Autopilot Mod] === Статус автопилота ===")
    print("Версия: " .. AUTOPILOT_MOD.version)
    print("Состояние: " .. (AUTOPILOT_MOD.enabled and "ВКЛЮЧЕН" or "ВЫКЛЮЧЕН"))
    print("Инициализирован: " .. (AUTOPILOT_MOD.initialized and "ДА" or "НЕТ"))
    
    if AUTOPILOT_MOD.core and AUTOPILOT_MOD.core.get_status then
        local status = AUTOPILOT_MOD.core.get_status()
        if status then
            print("Подсистемы: " .. tostring(status.subsystems or "N/A"))
            print("Производительность: " .. tostring(status.performance or "N/A"))
        end
    end
    
    print("================================")
end

-- Обработчик загрузки мода
local function onModLoaded()
    print("[Autopilot Mod] Мод загружен, начинаю инициализацию...")
    
    -- Небольшая задержка для полной загрузки игры
    local timer = 0
    local max_wait_time = 5.0  -- секунд
    local original_onUpdate = nil
    
    local function delayed_init(dt)
        timer = timer + dt
        
        if timer >= 2.0 then  -- Ждем 2 секунды перед инициализацией
            local success = initialize_autopilot()
            
            if success then
                print("[Autopilot Mod] Мод успешно инициализирован и готов к работе")
                print("[Autopilot Mod] Используйте CTRL+A для включения/выключения автопилота")
                print("[Autopilot Mod] Используйте CTRL+S для открытия настроек")
                print("[Autopilot Mod] Используйте CTRL+D для экстренной остановки")
                
                -- Удаляем временный обработчик инициализации
                -- Восстанавливаем оригинальный onUpdate
                if onUpdate and original_onUpdate then
                    onUpdate = original_onUpdate
                    print("[Autopilot Mod] Временный обработчик инициализации удален")
                end
            else
                print("[Autopilot Mod] ОШИБКА: Не удалось инициализировать мод")
            end
            
            return true  -- Завершить обработку
        end
        
        return false  -- Продолжить ожидание
    end
    
    -- Временный обработчик для отложенной инициализации
    if onUpdate then
        original_onUpdate = onUpdate
        
        function onUpdate(dt)
            if original_onUpdate then
                original_onUpdate(dt)
            end
            
            if not delayed_init(dt) then
                -- Продолжаем ждать
            end
        end
    end
end

-- Основная точка входа
print("[Autopilot Mod] Точка входа загружена")

-- Запуск инициализации при загрузке мода
onModLoaded()

-- Экспорт функций для использования из других модов
return {
    initialize = initialize_autopilot,
    toggle = toggle_autopilot,
    openSettings = open_autopilot_settings,
    getStatus = show_autopilot_status,
    MOD_INFO = AUTOPILOT_MOD
}