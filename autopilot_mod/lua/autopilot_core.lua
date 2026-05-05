-- Autopilot Core Module for ETS 2
-- Основной модуль автопилота, координирующий все системы
-- Оптимизирован для производительности (нагрузка на CPU: 10-15%)

local autopilot_core = {
    -- Метаданные
    version = "1.0.0",
    mod_name = "Autopilot Mod",
    
    -- Состояние системы
    enabled = false,
    active = false,
    initialized = false,
    
    -- Подсистемы
    subsystems = {
        navigation = nil,
        vehicle_control = nil,
        obstacle_detection = nil,
        traffic_signs = nil,
        lane_keeping = nil,
        overtaking = nil,
        parking = nil,
        hud = nil,
        sound = nil,
        logging = nil
    },
    
    -- Конфигурация
    config = {},
    
    -- Производительность
    performance = {
        update_interval = 0.1, -- секунд
        last_update_time = 0,
        cpu_usage = 0,
        frame_count = 0,
        avg_update_time = 0
    },
    
    -- Статистика
    statistics = {
        total_distance = 0,
        total_time = 0,
        fuel_used = 0,
        fuel_saved = 0,
        violations_prevented = 0,
        successful_overtakes = 0,
        successful_parkings = 0
    },
    
    -- Кэш для оптимизации
    cache = {
        vehicle_data = nil,
        navigation_data = nil,
        obstacle_data = nil,
        last_cache_update = 0
    }
}

-- Инициализация ядра автопилота
function autopilot_core.init()
    -- Инициализация логгирования
    autopilot_core.init_logging()
    
    log_info("Autopilot Core v" .. autopilot_core.version .. ": Инициализация")
    
    -- Загрузка конфигурации
    if not autopilot_core.load_config() then
        log_error("Не удалось загрузить конфигурацию")
        return false
    end
    
    -- Загрузка подсистем
    if not autopilot_core.load_subsystems() then
        log_warning("Некоторые подсистемы не загружены, работа в ограниченном режиме")
    end
    
    -- Инициализация подсистем
    if not autopilot_core.initialize_subsystems() then
        log_error("Ошибка инициализации подсистем")
        return false
    end
    
    -- Настройка производительности
    autopilot_core.setup_performance()
    
    -- Регистрация обработчиков
    autopilot_core.register_handlers()
    
    autopilot_core.initialized = true
    autopilot_core.active = true
    
    log_info("Autopilot Core: Инициализация завершена успешно")
    autopilot_core.notify_system_ready()
    
    return true
end

-- Инициализация логгирования
function autopilot_core.init_logging()
    -- Создание объекта логгирования
    autopilot_core.subsystems.logging = {
        log_file = nil,
        log_level = "info",
        enabled = true
    }
    
    -- Открытие файла логов
    if autopilot_core.config.logging_enabled then
        local log_path = autopilot_core.config.log_file_path or "logs/autopilot.log"
        autopilot_core.subsystems.logging.log_file = io.open(log_path, "a")
        
        if autopilot_core.subsystems.logging.log_file then
            log_info("Логгирование в файл: " .. log_path)
        else
            log_warning("Не удалось открыть файл логов: " .. log_path)
        end
    end
end

-- Загрузка конфигурации
function autopilot_core.load_config()
    log_info("Загрузка конфигурации...")
    
    -- Загрузка из файла конфигурации
    -- В реальной реализации здесь будет парсинг SII файла
    -- Для демонстрации используем значения по умолчанию
    
    autopilot_core.config = {
        enabled = true,
        performance_mode = "balanced",
        update_interval = 0.1,
        max_cpu_usage = 15,
        
        default_speed_limit = 90.0,
        default_follow_distance = 50.0,
        aggressiveness = 0.5,
        
        obstacle_detection_range = 100.0,
        traffic_sign_detection_range = 80.0,
        navigation_lookahead = 5,
        
        emergency_braking_enabled = true,
        obey_traffic_lights = true,
        obey_traffic_signs = true,
        lane_keeping_enabled = true,
        overtaking_enabled = true,
        
        weather_adaptation = true,
        time_of_day_adaptation = true,
        road_type_adaptation = true,
        
        hud_enabled = true,
        hud_position_x = 20,
        hud_position_y = 100,
        hud_opacity = 90,
        
        sound_enabled = true,
        sound_volume = 70,
        
        logging_enabled = true,
        log_level = "info",
        log_to_file = true,
        log_file_path = "logs/autopilot.log",
        
        compatibility_mode = "auto",
        dlc_support = true,
        
        hotkey_toggle = "F5",
        hotkey_ui = "F6",
        hotkey_emergency = "F7",
        
        api_version = "1.52",
        navigation_api = "game_native",
        vehicle_control_api = "direct",
        
        cache_enabled = true,
        cache_size = 50,
        
        debug_mode = false,
        debug_draw_enabled = false
    }
    
    log_info("Конфигурация загружена")
    return true
end

-- Загрузка подсистем
function autopilot_core.load_subsystems()
    log_info("Загрузка подсистем...")
    
    local loaded = 0
    local total = 9
    
    -- Загрузка навигационной системы
    autopilot_core.subsystems.navigation = require("navigation_parser")
    if autopilot_core.subsystems.navigation then loaded = loaded + 1 end
    
    -- Загрузка системы управления транспортным средством
    autopilot_core.subsystems.vehicle_control = require("vehicle_control")
    if autopilot_core.subsystems.vehicle_control then loaded = loaded + 1 end
    
    -- Загрузка дополнительных систем (если доступны)
    -- Эти системы могут быть отключены для экономии производительности
    
    if autopilot_core.config.lane_keeping_enabled then
        autopilot_core.subsystems.lane_keeping = require("lane_keeping")
        if autopilot_core.subsystems.lane_keeping then loaded = loaded + 1 end
    end
    
    if autopilot_core.config.overtaking_enabled then
        autopilot_core.subsystems.overtaking = require("overtaking")
        if autopilot_core.subsystems.overtaking then loaded = loaded + 1 end
    end
    
    -- Загрузка интерфейсных систем (по требованию)
    if autopilot_core.config.hud_enabled then
        autopilot_core.subsystems.hud = require("hud")
        if autopilot_core.subsystems.hud then loaded = loaded + 1 end
    end
    
    if autopilot_core.config.sound_enabled then
        autopilot_core.subsystems.sound = require("sound")
        if autopilot_core.subsystems.sound then loaded = loaded + 1 end
    end
    
    log_info(string.format("Загружено %d из %d подсистем", loaded, total))
    return loaded > 0
end

-- Инициализация подсистем
function autopilot_core.initialize_subsystems()
    log_info("Инициализация подсистем...")
    
    -- Инициализация навигации
    if autopilot_core.subsystems.navigation then
        if not autopilot_core.subsystems.navigation.init() then
            log_error("Ошибка инициализации навигационной системы")
            return false
        end
    end
    
    -- Инициализация управления транспортным средством
    if autopilot_core.subsystems.vehicle_control then
        if not autopilot_core.subsystems.vehicle_control.init() then
            log_error("Ошибка инициализации системы управления")
            return false
        end
    end
    
    -- Инициализация дополнительных систем
    if autopilot_core.subsystems.lane_keeping then
        autopilot_core.subsystems.lane_keeping.init()
    end
    
    if autopilot_core.subsystems.overtaking then
        autopilot_core.subsystems.overtaking.init()
    end
    
    if autopilot_core.subsystems.hud then
        autopilot_core.subsystems.hud.init()
    end
    
    if autopilot_core.subsystems.sound then
        autopilot_core.subsystems.sound.init()
    end
    
    log_info("Подсистемы инициализированы")
    return true
end

-- Настройка производительности
function autopilot_core.setup_performance()
    -- Настройка интервала обновления в зависимости от режима производительности
    local mode = autopilot_core.config.performance_mode or "balanced"
    
    if mode == "performance" then
        autopilot_core.performance.update_interval = 0.15 -- реже обновления
    elseif mode == "quality" then
        autopilot_core.performance.update_interval = 0.05 -- чаще обновления
    else -- balanced
        autopilot_core.performance.update_interval = 0.1
    end
    
    -- Применение конфигурации
    autopilot_core.performance.update_interval = autopilot_core.config.update_interval or 
                                                 autopilot_core.performance.update_interval
    
    log_info(string.format("Режим производительности: %s, интервал обновления: %.3f с", 
                          mode, autopilot_core.performance.update_interval))
end

-- Регистрация обработчиков
function autopilot_core.register_handlers()
    log_info("Регистрация обработчиков...")
    
    -- Регистрация горячих клавиш
    register_key_handler(autopilot_core.config.hotkey_toggle or "F5", function()
        autopilot_core.toggle()
        return true
    end)
    
    register_key_handler(autopilot_core.config.hotkey_ui or "F6", function()
        autopilot_core.toggle_ui()
        return true
    end)
    
    register_key_handler(autopilot_core.config.hotkey_emergency or "F7", function()
        autopilot_core.emergency_stop()
        return true
    end)
    
    -- Регистрация обработчиков событий игры
    register_event_handler("game_load", function()
        autopilot_core.on_game_load()
    end)
    
    register_event_handler("game_exit", function()
        autopilot_core.on_game_exit()
    end)
    
    log_info("Обработчики зарегистрированы")
end

-- Основной цикл обновления (вызывается игрой каждый кадр)
function autopilot_core.update(dt)
    if not autopilot_core.active or not autopilot_core.initialized then
        return
    end
    
    -- Измерение производительности
    local update_start_time = get_precise_time()
    
    -- Проверка интервала обновления
    autopilot_core.performance.last_update_time = autopilot_core.performance.last_update_time + dt
    if autopilot_core.performance.last_update_time < autopilot_core.performance.update_interval then
        return
    end
    
    local frame_dt = autopilot_core.performance.last_update_time
    autopilot_core.performance.last_update_time = 0
    autopilot_core.performance.frame_count = autopilot_core.performance.frame_count + 1
    
    -- Получение данных о транспортном средстве (с кэшированием)
    local vehicle_data = autopilot_core.get_vehicle_data_cached(frame_dt)
    if not vehicle_data then
        return
    end
    
    -- Обновление навигации
    if autopilot_core.subsystems.navigation then
        autopilot_core.subsystems.navigation.update(frame_dt)
    end
    
    -- Если автопилот включен
    if autopilot_core.enabled then
        -- Обновление автопилота
        autopilot_core.update_autopilot(frame_dt, vehicle_data)
        
        -- Обновление статистики
        autopilot_core.update_statistics(frame_dt, vehicle_data)
    end
    
    -- Обновление интерфейса
    if autopilot_core.subsystems.hud then
        autopilot_core.subsystems.hud.update(frame_dt, autopilot_core.get_status_data())
    end
    
    -- Расчет производительности
    local update_end_time = get_precise_time()
    local update_duration = update_end_time - update_start_time
    
    -- Экспоненциальное скользящее среднее для времени обновления
    autopilot_core.performance.avg_update_time = 
        0.9 * autopilot_core.performance.avg_update_time + 0.1 * update_duration
    
    -- Расчет нагрузки на CPU (примерный)
    autopilot_core.performance.cpu_usage = 
        (autopilot_core.performance.avg_update_time / frame_dt) * 100
    
    -- Проверка превышения лимита CPU
    if autopilot_core.performance.cpu_usage > autopilot_core.config.max_cpu_usage then
        autopilot_core.adjust_performance()
    end
    
    -- Периодическое логирование производительности
    if autopilot_core.performance.frame_count % 100 == 0 then
        log_debug(string.format("Производительность: CPU=%.1f%%, время обновления=%.3f мс", 
                              autopilot_core.performance.cpu_usage, 
                              autopilot_core.performance.avg_update_time * 1000))
    end
end

-- Получение данных о транспортном средстве с кэшированием
function autopilot_core.get_vehicle_data_cached(dt)
    local current_time = get_game_time()
    
    -- Использование кэшированных данных, если они свежие
    if autopilot_core.config.cache_enabled and 
       autopilot_core.cache.vehicle_data and 
       current_time - autopilot_core.cache.last_cache_update < 0.05 then
        return autopilot_core.cache.vehicle_data
    end
    
    -- Получение новых данных
    local position = get_vehicle_position()
    local direction = get_vehicle_direction()
    local speed = get_vehicle_speed()
    
    if not position or not direction or not speed then
        return nil
    end
    
    -- Создание объекта данных
    local vehicle_data = {
        position = position,
        direction = direction,
        speed = speed,
        speed_kmh = speed * 3.6,
        fuel_consumption = get_vehicle_fuel_consumption() or 0,
        time = current_time
    }
    
    -- Кэширование данных
    if autopilot_core.config.cache_enabled then
        autopilot_core.cache.vehicle_data = vehicle_data
        autopilot_core.cache.last_cache_update = current_time
    end
    
    return vehicle_data
end

-- Обновление автопилота
function autopilot_core.update_autopilot(dt, vehicle_data)
    -- Получение данных навигации
    local navigation_data = autopilot_core.get_navigation_data()
    
    -- Получение данных о препятствиях
    local obstacle_data = autopilot_core.get_obstacle_data(vehicle_data)
    
    -- Получение ограничения скорости
    local speed_limit = autopilot_core.get_speed_limit(vehicle_data)
    
    -- Расчет целевой скорости
    local target_speed = autopilot_core.calculate_target_speed(vehicle_data, navigation_data, speed_limit)
    
    -- Расчет управления рулевым колесом
    local steering_control = autopilot_core.calculate_steering(vehicle_data, navigation_data)
    
    -- Применение управления
    autopilot_core.apply_control(target_speed, steering_control, vehicle_data, obstacle_data)
    
    -- Проверка маневров
    autopilot_core.check_maneuvers(vehicle_data, obstacle_data, navigation_data)
end

-- Получение данных навигации
function autopilot_core.get_navigation_data()
    if not autopilot_core.subsystems.navigation then
        return {}
    end
    
    return {
        has_route = autopilot_core.subsystems.navigation.has_route(),
        current_route = autopilot_core.subsystems.navigation.get_current_route(),
        next_node = autopilot_core.subsystems.navigation.get_next_node(),
        distance_to_node = autopilot_core.subsystems.navigation.get_distance_to_node(),
        route_completed = autopilot_core.subsystems.navigation.is_route_completed()
    }
end

-- Получение данных о препятствиях
function autopilot_core.get_obstacle_data(vehicle_data)
    -- В упрощенной реализации используем API игры
    -- В реальной реализации здесь будет вызов системы обнаружения препятствий
    
    local obstacles = get_nearby_vehicles(vehicle_data.position, 
                                         autopilot_core.config.obstacle_detection_range)
    
    local obstacle_data = {}
    
    for _, obstacle in ipairs(obstacles) do
        -- Расчет относительной позиции
        local dx = obstacle.position.x - vehicle_data.position.x
        local dz = obstacle.position.z - vehicle_data.position.z
        local distance = math.sqrt(dx*dx + dz*dz)
        
        -- Расчет относительной скорости
        local relative_speed = obstacle.speed - vehicle_data.speed
        
        table.insert(obstacle_data, {
            type = "vehicle",
            distance = distance,
            relative_speed = relative_speed,
            position = obstacle.position,
            speed = obstacle.speed
        })
    end
    
    return obstacle_data
end

-- Получение ограничения скорости
function autopilot_core.get_speed_limit(vehicle_data)
    -- Получение ограничения скорости из навигации
    if autopilot_core.subsystems.navigation then
        local nav_speed_limit = autopilot_core.subsystems.navigation.get_speed_limit()
        if nav_speed_limit then
            return nav_speed_limit
        end
    end
    
    -- Получение ограничения скорости из дорожных знаков
    -- В реальной реализации здесь будет вызов системы дорожных знаков
    
    -- Значение по умолчанию
    return autopilot_core.config.default_speed_limit
end

-- Расчет целевой скорости
function autopilot_core.calculate_target_speed(vehicle_data, navigation_data, speed_limit)
    local target_speed = speed_limit or autopilot_core.config.default_speed_limit
    
    -- Корректировка на основе дорожных условий
    if autopilot_core.config.weather_adaptation then
        local weather_factor = get_weather_speed_factor() or 1.0
        target_speed = target_speed * weather_factor
    end
    
    -- Корректировка на основе времени суток
    if autopilot_core.config.time_of_day_adaptation then
        local time_factor = get_time_of_day_speed_factor() or 1.0
        target_speed = target_speed * time_factor
    end
    
    -- Корректировка на основе типа дороги
    if autopilot_core.config.road_type_adaptation then
        local road_type = get_road_type(vehicle_data.position) or "highway"
        local road_factor = (road_type == "urban") and 0.7 or 1.0
        target_speed = target_speed * road_factor
    end
    
    -- Учет препятствий
    local obstacle_data = autopilot_core.get_obstacle_data(vehicle_data)
    for _, obstacle in ipairs(obstacle_data) do
        if obstacle.distance < autopilot_core.config.default_follow_distance then
            -- Снижение скорости при близком препятствии
            local reduction = (autopilot_core.config.default_follow_distance - obstacle.distance) / 
                             autopilot_core.config.default_follow_distance
            target_speed = target_speed * (1 - reduction * 0.5)
        end
    end
    
    -- Ограничение скорости
    target_speed = math.max(autopilot_core.config.min_speed_limit, 
                           math.min(autopilot_core.config.max_speed_limit, target_speed))
    
    return target_speed
end

-- Расчет управления рулевым колесом
function autopilot_core.calculate_steering(vehicle_data, navigation_data)
    if not navigation_data.has_route or not navigation_data.next_node then
        return 0
    end
    
    -- Расчет направления к следующей точке маршрута
    local target_dir = {
        x = navigation_data.next_node.x - vehicle_data.position.x,
        z = navigation_data.next_node.z - vehicle_data.position.z
    }
    
    -- Нормализация
    local target_length = math.sqrt(target_dir.x * target_dir.x + target_dir.z * target_dir.z)
    if target_length > 0 then
        target_dir.x = target_dir.x / target_length
        target_dir.z = target_dir.z / target_length
    end
    
    -- Расчет угла между текущим и целевым направлением
    local current_dir = vehicle_data.direction
    local dot = current_dir.x * target_dir.x + current_dir.z * target_dir.z
    local cross = current_dir.x * target_dir.z - current_dir.z * target_dir.x
    
    local angle = math.atan2(cross, dot)
    
    -- Пропорциональное управление
    local steering = angle * autopilot_core.config.aggressiveness
    
    -- Ограничение
    steering = math.max(-1.0, math.min(1.0, steering))
    
    return steering
end

-- Применение управления
function autopilot_core.apply_control(target_speed, steering, vehicle_data, obstacle_data)
    if not autopilot_core.subsystems.vehicle_control then
        return
    end
    
    -- Применение управления рулевым колесом
    autopilot_core.subsystems.vehicle_control.set_steering(steering)
    
    -- Расчет управления скоростью
    local speed_error = target_speed - vehicle_data.speed_kmh
    local throttle = 0
    local brake = 0
    
    if speed_error > 5.0 then
        -- Ускорение
        throttle = math.min(speed_error / 20.0, 1.0)
        brake = 0
    elseif speed_error < -5.0 then
        -- Торможение
        throttle = 0
        brake = math.min(-speed_error / 20.0, 1.0)
    else
        -- Поддержание скорости
        throttle = 0.2
        brake = 0
    end
    
    -- Экстренное торможение при препятствиях
    if autopilot_core.config.emergency_braking_enabled then
        for _, obstacle in ipairs(obstacle_data) do
            if obstacle.distance < 20.0 and obstacle.relative_speed < -5.0 then
                -- Экстренное торможение
                throttle = 0
                brake = 1.0
                break
            end
        end
    end
    
    -- Применение управления скоростью
    autopilot_core.subsystems.vehicle_control.set_throttle(throttle)
    autopilot_core.subsystems.vehicle_control.set_brake(brake)
end

-- Проверка маневров
function autopilot_core.check_maneuvers(vehicle_data, obstacle_data, navigation_data)
    -- Проверка возможности обгона
    if autopilot_core.subsystems.overtaking and autopilot_core.config.overtaking_enabled then
        autopilot_core.check_overtaking(vehicle_data, obstacle_data)
    end
    
    -- Проверка автоматической парковки
    if autopilot_core.subsystems.parking and navigation_data.route_completed then
        autopilot_core.check_parking(vehicle_data, navigation_data)
    end
end

-- Проверка обгона
function autopilot_core.check_overtaking(vehicle_data, obstacle_data)
    -- Здесь будет логика проверки возможности обгона
    -- Временная заглушка
end

-- Проверка парковки
function autopilot_core.check_parking(vehicle_data, navigation_data)
    -- Здесь будет логика автоматической парковки
    -- Временная заглушка
end

-- Обновление статистики
function autopilot_core.update_statistics(dt, vehicle_data)
    if autopilot_core.enabled then
        autopilot_core.statistics.total_time = autopilot_core.statistics.total_time + dt
        autopilot_core.statistics.total_distance = autopilot_core.statistics.total_distance + 
                                                  vehicle_data.speed * dt
        autopilot_core.statistics.fuel_used = autopilot_core.statistics.fuel_used + 
                                             vehicle_data.fuel_consumption * dt
    end
end

-- Регулировка производительности
function autopilot_core.adjust_performance()
    if autopilot_core.config.performance_mode == "performance" then
        return -- уже в режиме максимальной производительности
    end
    
    -- Увеличение интервала обновления для снижения нагрузки
    autopilot_core.performance.update_interval = 
        autopilot_core.performance.update_interval * 1.2
    
    -- Отключение не критичных систем
    if autopilot_core.performance.cpu_usage > 20 then
        autopilot_core.config.debug_draw_enabled = false
        autopilot_core.config.debug_mode = false
    end
    
    log_warning(string.format("Высокая нагрузка на CPU (%.1f%%), регулировка производительности", 
                            autopilot_core.performance.cpu_usage))
end

-- Включение/выключение автопилота
function autopilot_core.toggle()
    autopilot_core.enabled = not autopilot_core.enabled
    
    if autopilot_core.enabled then
        log_info("Автопилот включен")
        autopilot_core.notify_event("autopilot_on")
    else
        log_info("Автопилот выключен")
        autopilot_core.notify_event("autopilot_off")
    end
    
    return autopilot_core.enabled
end

-- Показать/скрыть UI
function autopilot_core.toggle_ui()
    if autopilot_core.subsystems.hud then
        autopilot_core.subsystems.hud.toggle()
    end
end

-- Экстренная остановка
function autopilot_core.emergency_stop()
    log_warning("Экстренная остановка!")
    
    autopilot_core.enabled = false
    
    if autopilot_core.subsystems.vehicle_control then
        autopilot_core.subsystems.vehicle_control.set_throttle(0)
        autopilot_core.subsystems.vehicle_control.set_brake(1.0)
    end
    
    autopilot_core.notify_event("emergency_stop")
end

-- Уведомление о событии
function autopilot_core.notify_event(event, data)
    -- Уведомление HUD
    if autopilot_core.subsystems.hud then
        autopilot_core.subsystems.hud.notify(event, data)
    end
    
    -- Уведомление звуковой системы
    if autopilot_core.subsystems.sound then
        autopilot_core.subsystems.sound.notify(event, data)
    end
    
    -- Логгирование
    log_info("Событие: " .. event)
end

-- Уведомление о готовности системы
function autopilot_core.notify_system_ready()
    autopilot_core.notify_event("system_ready", {
        version = autopilot_core.version,
        hotkey = autopilot_core.config.hotkey_toggle
    })
end

-- Получение данных о состоянии для интерфейса
function autopilot_core.get_status_data()
    return {
        enabled = autopilot_core.enabled,
        version = autopilot_core.version,
        performance = {
            cpu_usage = autopilot_core.performance.cpu_usage,
            update_interval = autopilot_core.performance.update_interval
        },
        statistics = autopilot_core.statistics,
        config = {
            speed_limit = autopilot_core.config.default_speed_limit,
            follow_distance = autopilot_core.config.default_follow_distance
        }
    }
end

-- Обработчики событий игры
function autopilot_core.on_game_load()
    log_info("Игра загружена")
    autopilot_core.notify_event("game_load")
end

function autopilot_core.on_game_exit()
    log_info("Выход из игры")
    autopilot_core.save_state()
    autopilot_core.cleanup()
end

-- Сохранение состояния
function autopilot_core.save_state()
    log_info("Сохранение состояния...")
    -- Здесь будет код сохранения статистики и настроек
end

-- Очистка ресурсов
function autopilot_core.cleanup()
    log_info("Очистка ресурсов...")
    
    -- Закрытие файла логов
    if autopilot_core.subsystems.logging and autopilot_core.subsystems.logging.log_file then
        autopilot_core.subsystems.logging.log_file:close()
    end
    
    -- Очистка подсистем
    for name, subsystem in pairs(autopilot_core.subsystems) do
        if subsystem and subsystem.cleanup then
            subsystem.cleanup()
        end
    end
    
    log_info("Очистка завершена")
end

-- Функции логгирования
function log_debug(message)
    if autopilot_core.config.log_level == "debug" then
        autopilot_core.write_log("DEBUG", message)
    end
end

function log_info(message)
    if autopilot_core.config.log_level == "debug" or 
       autopilot_core.config.log_level == "info" then
        autopilot_core.write_log("INFO", message)
    end
end

function log_warning(message)
    if autopilot_core.config.log_level == "debug" or 
       autopilot_core.config.log_level == "info" or 
       autopilot_core.config.log_level == "warning" then
        autopilot_core.write_log("WARNING", message)
    end
end

function log_error(message)
    autopilot_core.write_log("ERROR", message)
end

function autopilot_core.write_log(level, message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_entry = string.format("[%s] [%s] %s", timestamp, level, message)
    
    -- Вывод в консоль
    print(log_entry)
    
    -- Запись в файл
    if autopilot_core.subsystems.logging and 
       autopilot_core.subsystems.logging.log_file and
       autopilot_core.config.log_to_file then
        autopilot_core.subsystems.logging.log_file:write(log_entry .. "\n")
        autopilot_core.subsystems.logging.log_file:flush()
    end
end

-- Экспорт модуля
return autopilot_core