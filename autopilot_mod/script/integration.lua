-- Финальная интеграция всех компонентов автопилота
-- Координирует работу всех систем и обеспечивает их взаимодействие

local integration = {
    -- Версия и информация
    version = "1.0.0",
    mod_name = "Autopilot Mod for ETS 2",
    
    -- Компоненты
    components = {
        autopilot = nil,
        speed_controller = nil,
        obstacle_detector = nil,
        navigation = nil,
        lane_keeping = nil,
        overtaking = nil,
        traffic_signs = nil,
        automatic_parking = nil,
        hud_indicator = nil,
        sound_notifications = nil
    },
    
    -- Состояние интеграции
    initialized = false,
    active = false,
    
    -- Конфигурация
    config = {},
    
    -- Статистика
    stats = {
        total_distance = 0,
        total_time = 0,
        fuel_saved = 0,
        violations_prevented = 0
    }
}

-- Инициализация интеграции
function integration.init()
    log("Integration: Инициализация интеграции всех компонентов")
    log("Integration: " .. integration.mod_name .. " v" .. integration.version)
    
    -- Загрузка конфигурации
    if not integration.load_config() then
        log("Integration: Ошибка загрузки конфигурации")
        return false
    end
    
    -- Загрузка компонентов
    if not integration.load_components() then
        log("Integration: Ошибка загрузки компонентов")
        return false
    end
    
    -- Инициализация компонентов
    if not integration.initialize_components() then
        log("Integration: Ошибка инициализации компонентов")
        return false
    end
    
    -- Настройка взаимодействия
    integration.setup_interactions()
    
    -- Регистрация обработчиков
    integration.register_handlers()
    
    integration.initialized = true
    integration.active = true
    
    log("Integration: Интеграция успешно инициализирована")
    integration.notify_system_ready()
    
    return true
end

-- Загрузка конфигурации
function integration.load_config()
    log("Integration: Загрузка конфигурации...")
    
    -- Загрузка из файла конфигурации
    local config_file = "def/autopilot_config.sui"
    
    -- Здесь будет код загрузки конфигурации
    -- Пока используем значения по умолчанию
    
    integration.config = {
        autopilot = {
            enabled = true,
            hotkey_toggle = "F5",
            hotkey_ui = "F6",
            activation_mode = "highway_only"
        },
        driving = {
            speed_percent = 100.0,
            follow_distance = 50.0,
            aggressiveness = 0.5,
            overtaking_enabled = true,
            automatic_parking = true
        },
        safety = {
            emergency_braking = true,
            obey_traffic_lights = true,
            obey_traffic_signs = true,
            weather_mode = "cautious",
            collision_sensitivity = 1.0
        },
        interface = {
            show_hud = true,
            show_notifications = true,
            enable_sounds = true,
            minimap_lane_highlight = true,
            ui_theme = "standard",
            ui_opacity = 90.0
        },
        advanced = {
            debug_mode = false,
            log_to_file = true,
            compatibility_mode = "auto"
        }
    }
    
    log("Integration: Конфигурация загружена")
    return true
end

-- Загрузка компонентов
function integration.load_components()
    log("Integration: Загрузка компонентов...")
    
    local components_loaded = 0
    local components_failed = 0
    
    -- Загрузка основных компонентов
    integration.components.autopilot = require("autopilot")
    if integration.components.autopilot then components_loaded = components_loaded + 1
    else components_failed = components_failed + 1 end
    
    integration.components.speed_controller = require("speed_controller")
    if integration.components.speed_controller then components_loaded = components_loaded + 1
    else components_failed = components_failed + 1 end
    
    integration.components.obstacle_detector = require("obstacle_detector")
    if integration.components.obstacle_detector then components_loaded = components_loaded + 1
    else components_failed = components_failed + 1 end
    
    integration.components.navigation = require("navigation_integration")
    if integration.components.navigation then components_loaded = components_loaded + 1
    else components_failed = components_failed + 1 end
    
    -- Загрузка дополнительных компонентов (если доступны)
    integration.components.lane_keeping = require("lane_keeping")
    if integration.components.lane_keeping then components_loaded = components_loaded + 1 end
    
    integration.components.overtaking = require("overtaking")
    if integration.components.overtaking then components_loaded = components_loaded + 1 end
    
    integration.components.traffic_signs = require("traffic_signs")
    if integration.components.traffic_signs then components_loaded = components_loaded + 1 end
    
    integration.components.automatic_parking = require("automatic_parking")
    if integration.components.automatic_parking then components_loaded = components_loaded + 1 end
    
    integration.components.hud_indicator = require("hud_indicator")
    if integration.components.hud_indicator then components_loaded = components_loaded + 1 end
    
    integration.components.sound_notifications = require("sound_notifications")
    if integration.components.sound_notifications then components_loaded = components_loaded + 1 end
    
    log("Integration: Загружено " .. components_loaded .. " компонентов, не загружено: " .. components_failed)
    
    return components_failed == 0
end

-- Инициализация компонентов
function integration.initialize_components()
    log("Integration: Инициализация компонентов...")
    
    -- Инициализация основных компонентов
    if integration.components.autopilot then
        integration.components.autopilot.init()
    end
    
    if integration.components.navigation then
        integration.components.navigation.init()
    end
    
    if integration.components.obstacle_detector then
        -- obstacle_detector не требует явной инициализации
    end
    
    if integration.components.speed_controller then
        -- speed_controller не требует явной инициализации
    end
    
    -- Инициализация дополнительных компонентов
    if integration.components.lane_keeping then
        integration.components.lane_keeping.init()
    end
    
    if integration.components.overtaking then
        integration.components.overtaking.init()
    end
    
    if integration.components.traffic_signs then
        integration.components.traffic_signs.init()
    end
    
    if integration.components.automatic_parking then
        integration.components.automatic_parking.init()
    end
    
    if integration.components.hud_indicator then
        integration.components.hud_indicator.init()
    end
    
    if integration.components.sound_notifications then
        integration.components.sound_notifications.init()
    end
    
    log("Integration: Компоненты инициализированы")
    return true
end

-- Настройка взаимодействия компонентов
function integration.setup_interactions()
    log("Integration: Настройка взаимодействия компонентов...")
    
    -- Настройка обмена данными между компонентами
    integration.setup_data_exchange()
    
    -- Настройка обработки событий
    integration.setup_event_handling()
    
    -- Настройка приоритетов
    integration.setup_priorities()
    
    log("Integration: Взаимодействие компонентов настроено")
end

-- Настройка обмена данными
function integration.setup_data_exchange()
    -- Здесь будет код настройки обмена данными между компонентами
    -- Например, как obstacle_detector передает данные speed_controller
    
    log("Integration: Настроен обмен данными между компонентами")
end

-- Настройка обработки событий
function integration.setup_event_handling()
    -- Регистрация обработчиков событий между компонентами
    
    -- Пример: при обнаружении препятствия уведомляем другие системы
    if integration.components.obstacle_detector then
        -- Здесь будет регистрация обработчиков
    end
    
    log("Integration: Настроена обработка событий")
end

-- Настройка приоритетов
function integration.setup_priorities()
    -- Определение приоритетов систем
    -- Безопасность > Навигация > Управление > Интерфейс
    
    integration.priorities = {
        safety = 100,      -- Системы безопасности (экстренное торможение)
        navigation = 80,   -- Навигация и маршрутизация
        control = 60,      -- Управление (руление, скорость)
        assistance = 40,   -- Вспомогательные системы (обгон, парковка)
        interface = 20     -- Интерфейс и уведомления
    }
    
    log("Integration: Настроены приоритеты систем")
end

-- Регистрация обработчиков
function integration.register_handlers()
    log("Integration: Регистрация обработчиков...")
    
    -- Регистрация горячих клавиш
    integration.register_hotkeys()
    
    -- Регистрация обработчиков событий игры
    integration.register_game_handlers()
    
    -- Регистрация обработчиков UI
    integration.register_ui_handlers()
    
    log("Integration: Обработчики зарегистрированы")
end

-- Регистрация горячих клавиш
function integration.register_hotkeys()
    local hotkey_toggle = integration.config.autopilot.hotkey_toggle or "F5"
    local hotkey_ui = integration.config.autopilot.hotkey_ui or "F6"
    
    -- Регистрация горячей клавиши включения/выключения автопилота
    register_key_handler(hotkey_toggle, function()
        integration.toggle_autopilot()
        return true
    end)
    
    -- Регистрация горячей клавиши показа/скрытия UI
    register_key_handler(hotkey_ui, function()
        integration.toggle_ui()
        return true
    end)
    
    -- Регистрация горячей клавиши экстренной остановки (F7)
    register_key_handler("F7", function()
        integration.emergency_stop()
        return true
    end)
    
    log("Integration: Горячие клавиши зарегистрированы: " .. hotkey_toggle .. ", " .. hotkey_ui .. ", F7")
end

-- Регистрация обработчиков событий игры
function integration.register_game_handlers()
    -- Обработчик загрузки игры
    register_event_handler("game_load", function()
        integration.on_game_load()
    end)
    
    -- Обработчик выхода из игры
    register_event_handler("game_exit", function()
        integration.on_game_exit()
    end)
    
    -- Обработчик изменения времени суток
    register_event_handler("time_changed", function(hour)
        integration.on_time_changed(hour)
    end)
    
    -- Обработчик изменения погоды
    register_event_handler("weather_changed", function(weather_type)
        integration.on_weather_changed(weather_type)
    end)
    
    log("Integration: Обработчики событий игры зарегистрированы")
end

-- Регистрация обработчиков UI
function integration.register_ui_handlers()
    -- Здесь будет регистрация обработчиков для элементов UI
    -- Например, кнопок в меню настроек
    
    log("Integration: Обработчики UI зарегистрированы")
end

-- Основной цикл обновления
function integration.update(dt)
    if not integration.active or not integration.initialized then
        return
    end
    
    -- Получение данных о транспортном средстве
    local vehicle_data = integration.get_vehicle_data()
    if not vehicle_data then
        return
    end
    
    -- Обновление навигации
    if integration.components.navigation then
        integration.components.navigation.update(dt)
    end
    
    -- Обновление обнаружения препятствий
    if integration.components.obstacle_detector then
        integration.components.obstacle_detector.update(dt, 
            vehicle_data.position, vehicle_data.direction, vehicle_data.speed)
    end
    
    -- Обновление дорожных знаков
    if integration.components.traffic_signs then
        integration.components.traffic_signs.update(dt, 
            vehicle_data.position, vehicle_data.speed)
    end
    
    -- Обновление удержания полосы
    if integration.components.lane_keeping then
        integration.components.lane_keeping.update_road_data(
            vehicle_data.position, vehicle_data.direction)
    end
    
    -- Обновление автопилота (если активен)
    if integration.components.autopilot and integration.components.autopilot.enabled then
        integration.update_autopilot(dt, vehicle_data)
    end
    
    -- Обновление HUD
    if integration.components.hud_indicator then
        local autopilot_data = integration.get_autopilot_data()
        local navigation_data = integration.get_navigation_data()
        
        integration.components.hud_indicator.update(dt, 
            autopilot_data, vehicle_data, navigation_data)
    end
    
    -- Обновление звуковых оповещений
    if integration.components.sound_notifications then
        integration.components.sound_notifications.update(dt)
    end
    
    -- Обновление статистики
    integration.update_stats(dt, vehicle_data)
end

-- Обновление автопилота
function integration.update_autopilot(dt, vehicle_data)
    -- Получение данных навигации
    local navigation_data = integration.get_navigation_data()
    
    -- Получение данных о препятствиях
    local obstacle_data = {}
    if integration.components.obstacle_detector then
        obstacle_data = integration.components.obstacle_detector.obstacles or {}
    end
    
    -- Получение ограничения скорости
    local speed_limit = nil
    if integration.components.traffic_signs then
        speed_limit = integration.components.traffic_signs.get_current_speed_limit()
    end
    
    -- Обновление автопилота
    integration.components.autopilot.update(dt, vehicle_data, 
        navigation_data, obstacle_data, speed_limit)
    
    -- Проверка возможности обгона
    if integration.components.overtaking and integration.components.overtaking.enabled then
        integration.check_overtaking(vehicle_data, obstacle_data)
    end
    
    -- Проверка автоматической парковки
    if integration.components.automatic_parking and integration.components.automatic_parking.enabled then
        integration.check_automatic_parking(vehicle_data, navigation_data)
    end
end

-- Проверка возможности обгона
function integration.check_overtaking(vehicle_data, obstacle_data)
    if integration.components.overtaking.is_overtaking then
        -- Обновление текущего маневра обгона
        integration.components.overtaking.update(0.1, vehicle_data, obstacle_data)
    else
        -- Проверка возможности начала обгона
        local possible, target = integration.components.overtaking.check_overtaking_possible(
            vehicle_data, obstacle_data)
        
        if possible then
            integration.components.overtaking.start_overtaking(vehicle_data, target)
            
            -- Уведомление
            if integration.components.sound_notifications then
                integration.components.sound_notifications.notify_maneuver("overtaking", "start")
            end
        end
    end
end

-- Проверка автоматической парковки
function integration.check_automatic_parking(vehicle_data, navigation_data)
    if integration.components.automatic_parking.is_parking then
        -- Обновление текущего процесса парковки
        integration.components.automatic_parking.update(0.1, vehicle_data)
    else
        -- Проверка возможности парковки
        local destination_info = {
            reached = navigation_data.destination_reached or false,
            position = navigation_data.destination or vehicle_data.position
        }
        
        local possible, parking_spot = integration.components.automatic_parking.check_parking_possible(
            destination_info, vehicle_data)
        
        if possible then
            integration.components.automatic_parking.start_parking(parking_spot, vehicle_data)
            
            -- Уведомление
            if integration.components.sound_notifications then
                integration.components.sound_notifications.notify_maneuver("parking", "start")
            end
        end
    end
end

-- Обновление статистики
function integration.update_stats(dt, vehicle_data)
    if integration.components.autopilot and integration.components.autopilot.enabled then
        integration.stats.total_time = integration.stats.total_time + dt
        integration.stats.total_distance = integration.stats.total_distance + vehicle_data.speed * dt
        
        -- Расчет экономии топлива (примерный)
        local fuel_saving_rate = 0.05 -- 5% экономии
        integration.stats.fuel_saved = integration.stats.fuel_saved + 
            vehicle_data.fuel_consumption * fuel_saving_rate * dt
    end
end

-- Получение данных о транспортном средстве
function integration.get_vehicle_data()
    local position = get_vehicle_position()
    local direction = get_vehicle_direction()
    local speed = get_vehicle_speed()
    
    if not position or not direction or not speed then
        return nil
    end
    
    return {
        position = position,
        direction = direction,
        speed = speed,
        fuel_consumption = get_vehicle_fuel_consumption() or 0
    }
end

-- Получение данных автопилота
function integration.get_autopilot_data()
    if not integration.components.autopilot then
        return {}
    end
    
    return {
        enabled = integration.components.autopilot.enabled,
        target_speed = integration.components.autopilot.target_speed,
        follow_distance = integration.components.autopilot.follow_distance
    }
end

-- Получение данных навигации
function integration.get_navigation_data()
    if not integration.components.navigation then
        return {}
    end
    
    return {
        speed_limit = integration.components.navigation.current_speed_limit,
        destination_reached = integration.components.navigation.destination_reached,
        destination = integration.components.navigation.destination
    }
end

-- Включение/выключение автопилота
function integration.toggle_autopilot()
    if not integration.components.autopilot then
        return
    end
    
    integration.components.autopilot.toggle()
    
    -- Уведомление
    if integration.components.sound_notifications then
        if integration.components.autopilot.enabled then
            integration.components.sound_notifications.notify_autopilot_event("autopilot_on")
        else
            integration.components.sound_notifications.notify_autopilot_event("autopilot_off")
        end
    end
    
    -- Обновление HUD
    if integration.components.hud_indicator then
        integration.components.hud_indicator.add_notification(
            integration.components.autopilot.enabled and "Автопилот включен" or "Автопилот выключен",
            integration.components.autopilot.enabled and "success" or "info",
            3.0)
    end
end

-- Показать/скрыть UI
function integration.toggle_ui()
    -- Здесь будет код показа/скрытия UI
    -- Временная заглушка
    
    if integration.components.sound_notifications then
        integration.components.sound_notifications.play_ui_sound("click")
    end
    
    log("Integration: UI переключен")
end

-- Экстренная остановка
function integration.emergency_stop()
    log("Integration: Экстренная остановка!")
    
    -- Отключение автопилота
    if integration.components.autopilot then
        integration.components.autopilot.enabled = false
    end
    
    -- Прерывание обгона
    if integration.components.overtaking then
        integration.components.overtaking.abort_overtaking("Экстренная остановка")
    end
    
    -- Прерывание парковки
    if integration.components.automatic_parking then
        integration.components.automatic_parking.abort_parking("Экстренная остановка")
    end
    
    -- Применение торможения
    set_brake(1.0)
    set_throttle(0)
    
    -- Уведомление
    if integration.components.sound_notifications then
        integration.components.sound_notifications.notify_warning("collision", "high")
    end
    
    if integration.components.hud_indicator then
        integration.components.hud_indicator.add_warning("ЭКСТРЕННАЯ ОСТАНОВКА!", "emergency", 5.0)
    end
end

-- Уведомление о готовности системы
function integration.notify_system_ready()
    if integration.components.sound_notifications then
        integration.components.sound_notifications.notify_system_event("system_ready")
    end
    
    if integration.components.hud_indicator then
        integration.components.hud_indicator.add_notification(
            "Автопилот готов к работе. " .. integration.config.autopilot.hotkey_toggle .. " - включить/выключить",
            "info", 5.0)
    end
end

-- Обработчики событий игры
function integration.on_game_load()
    log("Integration: Игра загружена")
    
    if integration.components.sound_notifications then
        integration.components.sound_notifications.notify_system_event("system_start")
    end
end

function integration.on_game_exit()
    log("Integration: Выход из игры")
    
    -- Сохранение статистики и конфигурации
    integration.save_state()
end

function integration.on_time_changed(hour)
    -- Корректировка поведения в ночное время
    if hour >= 22 or hour <= 6 then
        -- Ночное время - более осторожное вождение
        if integration.components.autopilot then
            integration.components.autopilot.aggressiveness = 
                integration.components.autopilot.aggressiveness * 0.7
        end
    end
end

function integration.on_weather_changed(weather_type)
    -- Корректировка поведения при плохой погоде
    local bad_weather = {"rain", "storm", "snow", "fog"}
    
    for _, bad in ipairs(bad_weather) do
        if weather_type == bad then
            -- Уменьшение скорости и увеличение дистанции
            if integration.components.autopilot then
                integration.components.autopilot.target_speed = 
                    integration.components.autopilot.target_speed * 0.8
                integration.components.autopilot.follow_distance = 
                    integration.components.autopilot.follow_distance * 1.5
            end
            
            -- Уведомление
            if integration.components.hud_indicator then
                integration.components.hud_indicator.add_notification(
                    "Плохая погода: осторожный режим", "warning", 5.0)
            end
            
            break
        end
    end
end

-- Сохранение состояния
function integration.save_state()
    log("Integration: Сохранение состояния...")
    
    -- Здесь будет код сохранения статистики и настроек
    
    log("Integration: Состояние сохранено")
end

-- Получение информации о системе
function integration.get_system_info()
    local info = {
        version = integration.version,
        mod_name = integration.mod_name,
        initialized = integration.initialized,
        active = integration.active,
        components = {}
    }
    
    -- Информация о компонентах
    for name, component in pairs(integration.components) do
        info.components[name] = (component ~= nil)
    end
    
    -- Статистика
    info.stats = integration.stats
    
    return info
end

-- Вспомогательные функции
function log(message)
    print("[Integration] " .. message)
end

return integration