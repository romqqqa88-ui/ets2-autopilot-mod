-- Инициализационный скрипт для Autopilot Mod
-- Загружает все компоненты и настраивает интеграцию с игрой

local autopilot_mod = {
    version = "1.0.0",
    components = {},
    initialized = false,
    debug_mode = false
}

-- Загрузка компонентов
function autopilot_mod.load_components()
    log("Autopilot Mod v" .. autopilot_mod.version .. ": Загрузка компонентов...")
    
    -- Загрузка основных модулей
    autopilot_mod.components.autopilot = require("autopilot")
    autopilot_mod.components.speed_controller = require("speed_controller")
    autopilot_mod.components.obstacle_detector = require("obstacle_detector")
    autopilot_mod.components.navigation = require("navigation_integration")
    
    -- Проверка успешной загрузки
    for name, component in pairs(autopilot_mod.components) do
        if component then
            log("  ✓ " .. name .. " загружен")
        else
            log("  ✗ " .. name .. " не загружен")
            return false
        end
    end
    
    return true
end

-- Инициализация компонентов
function autopilot_mod.initialize_components()
    log("Autopilot Mod: Инициализация компонентов...")
    
    -- Инициализация навигации
    if not autopilot_mod.components.navigation.init() then
        log("Предупреждение: Навигация не инициализирована, некоторые функции могут быть ограничены")
    end
    
    -- Инициализация основного модуля автопилота
    autopilot_mod.components.autopilot.init()
    
    -- Настройка горячих клавиш
    autopilot_mod.setup_hotkeys()
    
    -- Загрузка конфигурации
    autopilot_mod.load_configuration()
    
    log("Autopilot Mod: Инициализация завершена")
    return true
end

-- Настройка горячих клавиш
function autopilot_mod.setup_hotkeys()
    log("Autopilot Mod: Настройка горячих клавиш...")
    
    -- Регистрация обработчиков клавиш
    register_key_handler("F5", function()
        autopilot_mod.components.autopilot.toggle()
        return true -- обработано, не передавать дальше
    end)
    
    register_key_handler("F6", function()
        autopilot_mod.toggle_ui()
        return true
    end)
    
    register_key_handler("F7", function()
        autopilot_mod.emergency_stop()
        return true
    end)
    
    register_key_handler("NUMPAD_PLUS", function()
        autopilot_mod.increase_speed()
        return true
    end)
    
    register_key_handler("NUMPAD_MINUS", function()
        autopilot_mod.decrease_speed()
        return true
    end)
    
    log("Autopilot Mod: Горячие клавиши настроены")
end

-- Загрузка конфигурации
function autopilot_mod.load_configuration()
    log("Autopilot Mod: Загрузка конфигурации...")
    
    -- Здесь будет код загрузки конфигурации из файла
    -- Пока используем значения по умолчанию
    
    autopilot_mod.config = {
        speed_limit = 90.0,
        follow_distance = 50.0,
        aggressiveness = 0.5,
        enable_lane_change = true,
        stop_at_lights = true
    }
    
    log("Autopilot Mod: Конфигурация загружена")
end

-- Переключение UI
function autopilot_mod.toggle_ui()
    autopilot_mod.ui_visible = not autopilot_mod.ui_visible
    
    if autopilot_mod.ui_visible then
        log("Autopilot Mod: UI показан")
        -- Здесь будет код показа UI
    else
        log("Autopilot Mod: UI скрыт")
        -- Здесь будет код скрытия UI
    end
end

-- Экстренная остановка
function autopilot_mod.emergency_stop()
    log("Autopilot Mod: Экстренная остановка!")
    
    -- Отключение автопилота
    if autopilot_mod.components.autopilot.enabled then
        autopilot_mod.components.autopilot.toggle()
    end
    
    -- Применение полного торможения
    set_brake(1.0)
    set_throttle(0)
    
    -- Визуальное и звуковое уведомление
    show_message("АВТОПИЛОТ: ЭКСТРЕННАЯ ОСТАНОВКА!")
    play_sound("emergency_stop")
end

-- Увеличение скорости
function autopilot_mod.increase_speed()
    local current_speed = autopilot_mod.config.speed_limit
    local new_speed = math.min(current_speed + 5.0, 130.0)
    
    autopilot_mod.config.speed_limit = new_speed
    autopilot_mod.components.speed_controller.set_target_speed(new_speed)
    
    log("Autopilot Mod: Скорость увеличена до " .. new_speed .. " км/ч")
    show_message("Ограничение скорости: " .. new_speed .. " км/ч")
end

-- Уменьшение скорости
function autopilot_mod.decrease_speed()
    local current_speed = autopilot_mod.config.speed_limit
    local new_speed = math.max(current_speed - 5.0, 30.0)
    
    autopilot_mod.config.speed_limit = new_speed
    autopilot_mod.components.speed_controller.set_target_speed(new_speed)
    
    log("Autopilot Mod: Скорость уменьшена до " .. new_speed .. " км/ч")
    show_message("Ограничение скорости: " .. new_speed .. " км/ч")
end

-- Основной цикл обновления
function autopilot_mod.update(dt)
    if not autopilot_mod.initialized then
        return
    end
    
    -- Обновление навигации
    autopilot_mod.components.navigation.update(dt)
    
    -- Если автопилот включен
    if autopilot_mod.components.autopilot.enabled then
        -- Обновление обнаружения препятствий
        local player_pos = get_player_position()
        local player_dir = get_player_direction()
        local player_speed = get_player_speed()
        
        autopilot_mod.components.obstacle_detector.update(dt, player_pos, player_dir, player_speed)
        
        -- Проверка необходимости экстренного торможения
        local emergency, obstacle = autopilot_mod.components.obstacle_detector.needs_emergency_brake()
        if emergency then
            log("Autopilot Mod: Обнаружено препятствие, экстренное торможение")
            autopilot_mod.emergency_stop()
            return
        end
        
        -- Обновление автопилота
        autopilot_mod.components.autopilot.update(dt)
    end
    
    -- Отладочная информация (если включено)
    if autopilot_mod.debug_mode then
        autopilot_mod.draw_debug_info()
    end
end

-- Отрисовка отладочной информации
function autopilot_mod.draw_debug_info()
    -- Информация о состоянии
    local y_offset = 50
    
    draw_text(10, y_offset, "Autopilot Mod v" .. autopilot_mod.version, 0xFFFFFF)
    y_offset = y_offset + 20
    
    draw_text(10, y_offset, "Состояние: " .. (autopilot_mod.components.autopilot.enabled and "ВКЛ" or "ВЫКЛ"), 
              autopilot_mod.components.autopilot.enabled and 0x00FF00 or 0xFF0000)
    y_offset = y_offset + 20
    
    draw_text(10, y_offset, "Скорость: " .. string.format("%.1f", autopilot_mod.config.speed_limit) .. " км/ч", 0xFFFFFF)
    y_offset = y_offset + 20
    
    draw_text(10, y_offset, "Дистанция: " .. string.format("%.1f", autopilot_mod.config.follow_distance) .. " м", 0xFFFFFF)
    y_offset = y_offset + 20
    
    -- Информация о препятствиях
    local obstacle_count = #autopilot_mod.components.obstacle_detector.obstacles
    draw_text(10, y_offset, "Препятствия: " .. obstacle_count, 
              obstacle_count > 0 and 0xFFFF00 or 0xFFFFFF)
    y_offset = y_offset + 20
    
    -- Информация о маршруте
    if #autopilot_mod.components.navigation.current_route > 0 then
        draw_text(10, y_offset, "Маршрут: " .. autopilot_mod.components.navigation.current_node_index .. "/" .. 
                  #autopilot_mod.components.navigation.current_route .. " точек", 0xFFFFFF)
        y_offset = y_offset + 20
        
        local distance = autopilot_mod.components.navigation.distance_remaining or 0
        draw_text(10, y_offset, "Осталось: " .. string.format("%.1f", distance / 1000) .. " км", 0xFFFFFF)
    end
end

-- Обработчик события загрузки игры
function on_game_load()
    log("Autopilot Mod: Игра загружена, инициализация...")
    
    -- Загрузка компонентов
    if not autopilot_mod.load_components() then
        log("Autopilot Mod: Ошибка загрузки компонентов")
        return
    end
    
    -- Инициализация
    if not autopilot_mod.initialize_components() then
        log("Autopilot Mod: Ошибка инициализации")
        return
    end
    
    -- Регистрация цикла обновления
    register_update("autopilot_mod_update", function(dt)
        autopilot_mod.update(dt)
    end)
    
    autopilot_mod.initialized = true
    log("Autopilot Mod: Успешно инициализирован и готов к работе")
    
    -- Приветственное сообщение
    show_message("Autopilot Mod v" .. autopilot_mod.version .. " загружен. F5 - включить/выключить")
end

-- Обработчик события выхода из игры
function on_game_exit()
    log("Autopilot Mod: Выход из игры, очистка...")
    
    -- Отключение автопилота
    if autopilot_mod.components.autopilot.enabled then
        autopilot_mod.components.autopilot.toggle()
    end
    
    -- Отмена регистрации обновлений
    unregister_update("autopilot_mod_update")
    
    log("Autopilot Mod: Завершение работы")
end

-- Вспомогательные функции
function log(message)
    print("[Autopilot Mod] " .. message)
    
    -- Запись в файл логов (если включено)
    if autopilot_mod.config and autopilot_mod.config.log_to_file then
        -- Здесь будет код записи в файл
    end
end

function show_message(text)
    -- Показать сообщение на экране
    print("[Autopilot] " .. text)
    -- Здесь будет вызов API игры для показа сообщения
end

function play_sound(sound_name)
    -- Воспроизвести звук
    -- Здесь будет вызов API игры для воспроизведения звука
end

-- Экспорт модуля
return autopilot_mod