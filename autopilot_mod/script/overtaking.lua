-- Система обгона для автопилота
-- Выполняет безопасные маневры обгона с учетом ПДД и дорожной ситуации

local overtaking = {
    -- Настройки
    enabled = true, -- включена ли система обгона
    min_speed_difference = 10.0, -- минимальная разница скоростей для обгона (км/ч)
    safe_overtaking_distance = 30.0, -- безопасная дистанция для обгона (м)
    min_clearance_ahead = 100.0, -- минимальное свободное пространство впереди (м)
    min_clearance_behind = 50.0, -- минимальное свободное пространство сзади (м)
    
    -- Состояние обгона
    is_overtaking = false, -- выполняется ли обгон в данный момент
    overtaking_phase = "none", -- фаза обгона: none, preparing, changing_lane, passing, returning
    target_vehicle = nil, -- ID транспортного средства, которое обгоняем
    start_time = 0, -- время начала обгона
    
    -- Параметры текущего маневра
    original_lane = 1, -- исходная полоса
    target_lane = 2, -- полоса для обгона
    overtaking_speed = 0, -- скорость во время обгона
    
    -- Ограничения
    max_overtaking_speed = 110.0, -- максимальная скорость при обгоне
    overtaking_duration_limit = 30.0, -- максимальная длительность обгона (сек)
    
    -- Статистика
    completed_overtakes = 0,
    aborted_overtakes = 0,
    last_overtake_time = 0
}

-- Инициализация системы обгона
function overtaking.init()
    log("Overtaking: Инициализация системы обгона")
    
    -- Загрузка конфигурации
    overtaking.load_config()
    
    -- Сброс состояния
    overtaking.reset()
    
    return true
end

-- Загрузка конфигурации
function overtaking.load_config()
    -- Здесь будет загрузка из конфигурационного файла
    overtaking.enabled = true
    overtaking.min_speed_difference = 10.0
    overtaking.safe_overtaking_distance = 30.0
    overtaking.min_clearance_ahead = 100.0
    overtaking.min_clearance_behind = 50.0
end

-- Сброс состояния
function overtaking.reset()
    overtaking.is_overtaking = false
    overtaking.overtaking_phase = "none"
    overtaking.target_vehicle = nil
    overtaking.start_time = 0
    overtaking.original_lane = 1
    overtaking.target_lane = 2
    overtaking.overtaking_speed = 0
end

-- Проверка возможности обгона
function overtaking.check_overtaking_possible(vehicle_data, obstacle_data)
    if not overtaking.enabled then
        return false, "Система обгона отключена"
    end
    
    -- Проверка дорожных условий
    if not overtaking.check_road_conditions(vehicle_data) then
        return false, "Дорожные условия не позволяют обгон"
    end
    
    -- Проверка наличия подходящего транспортного средства для обгона
    local target_vehicle, reason = overtaking.find_overtaking_target(vehicle_data, obstacle_data)
    
    if not target_vehicle then
        return false, reason or "Нет подходящей цели для обгона"
    end
    
    -- Проверка безопасности обгона
    local safe, safety_reason = overtaking.check_safety(vehicle_data, target_vehicle)
    
    if not safe then
        return false, safety_reason
    end
    
    return true, target_vehicle
end

-- Проверка дорожных условий
function overtaking.check_road_conditions(vehicle_data)
    -- Проверка типа дороги
    local road_type = get_road_type_at_position(vehicle_data.position.x, vehicle_data.position.z)
    
    -- Запрет обгона на некоторых типах дорог
    local prohibited_roads = {
        "urban", -- городские дороги
        "residential", -- жилые зоны
        "parking" -- парковки
    }
    
    for _, prohibited in ipairs(prohibited_roads) do
        if road_type == prohibited then
            return false, "Обгон запрещен на этом типе дороги: " .. road_type
        end
    end
    
    -- Проверка разметки
    local markings = get_lane_markings_at_position(vehicle_data.position.x, vehicle_data.position.z)
    
    for _, marking in ipairs(markings) do
        if marking.type == "solid" or marking.type == "double_solid" then
            return false, "Сплошная линия разметки - обгон запрещен"
        end
    end
    
    -- Проверка дорожных знаков
    local signs = get_traffic_signs_near_position(vehicle_data.position.x, vehicle_data.position.z, 50.0)
    
    for _, sign in ipairs(signs) do
        if sign.type == "no_overtaking" or sign.type == "no_overtaking_trucks" then
            return false, "Дорожный знак запрещает обгон"
        end
    end
    
    -- Проверка видимости
    local visibility = get_visibility_range()
    if visibility < 200.0 then
        return false, "Недостаточная видимость для обгона"
    end
    
    return true
end

-- Поиск цели для обгона
function overtaking.find_overtaking_target(vehicle_data, obstacle_data)
    local my_speed = vehicle_data.speed * 3.6 -- преобразование в км/ч
    
    -- Поиск медленно движущегося транспортного средства впереди
    for _, obstacle in ipairs(obstacle_data) do
        if obstacle.type == "vehicle" then
            -- Проверка, находится ли в нашей полосе
            if math.abs(obstacle.lateral_offset) < 2.0 then
                -- Проверка расстояния
                if obstacle.distance > 20.0 and obstacle.distance < 80.0 then
                    -- Проверка разницы скоростей
                    local obstacle_speed = obstacle.speed * 3.6 -- км/ч
                    local speed_difference = my_speed - obstacle_speed
                    
                    if speed_difference > overtaking.min_speed_difference then
                        -- Проверка, не обгоняем ли мы уже это транспортное средство
                        if not overtaking.is_currently_overtaking(obstacle.id) then
                            return obstacle, "Найдена подходящая цель для обгона"
                        end
                    end
                end
            end
        end
    end
    
    return nil, "Не найдено подходящих целей для обгона"
end

-- Проверка безопасности обгона
function overtaking.check_safety(vehicle_data, target_vehicle)
    -- Проверка свободного пространства в полосе для обгона
    local clearance_ahead, clearance_behind = overtaking.check_lane_clearance(vehicle_data, target_vehicle)
    
    if clearance_ahead < overtaking.min_clearance_ahead then
        return false, "Недостаточно свободного пространства впереди: " .. string.format("%.1f", clearance_ahead) .. " м"
    end
    
    if clearance_behind < overtaking.min_clearance_behind then
        return false, "Недостаточно свободного пространства сзади: " .. string.format("%.1f", clearance_behind) .. " м"
    end
    
    -- Проверка встречного транспорта
    local oncoming_traffic = overtaking.check_oncoming_traffic(vehicle_data)
    
    if oncoming_traffic then
        return false, "Обнаружен встречный транспорт"
    end
    
    -- Проверка скорости
    local my_speed = vehicle_data.speed * 3.6
    local max_allowed_speed = get_speed_limit_at_position(vehicle_data.position.x, vehicle_data.position.z) or 90.0
    
    if my_speed > max_allowed_speed + 10.0 then
        return false, "Скорость слишком высока для безопасного обгона"
    end
    
    return true
end

-- Проверка свободного пространства в полосе для обгона
function overtaking.check_lane_clearance(vehicle_data, target_vehicle)
    -- Получаем информацию о транспортных средствах в соседней полосе
    local lane_vehicles = get_vehicles_in_lane(vehicle_data.lane + 1, vehicle_data.position.z, 150.0)
    
    local clearance_ahead = 150.0 -- по умолчанию
    local clearance_behind = 150.0
    
    for _, vehicle in ipairs(lane_vehicles) do
        local distance = vehicle.position.z - vehicle_data.position.z
        
        if distance > 0 then -- впереди
            clearance_ahead = math.min(clearance_ahead, distance)
        else -- сзади
            clearance_behind = math.min(clearance_behind, math.abs(distance))
        end
    end
    
    return clearance_ahead, clearance_behind
end

-- Проверка встречного транспорта
function overtaking.check_oncoming_traffic(vehicle_data)
    -- В упрощенной реализации проверяем только наличие транспортных средств на встречной полосе
    -- В реальной реализации нужно учитывать расстояние и скорость
    
    local oncoming_lane = vehicle_data.lane - 1
    
    if oncoming_lane >= 1 then
        local oncoming_vehicles = get_vehicles_in_lane(oncoming_lane, vehicle_data.position.z, 200.0)
        
        for _, vehicle in ipairs(oncoming_vehicles) do
            local distance = vehicle.position.z - vehicle_data.position.z
            
            if distance < 150.0 and distance > -50.0 then
                return true -- встречное транспортное средство обнаружено
            end
        end
    end
    
    return false
end

-- Начало маневра обгона
function overtaking.start_overtaking(vehicle_data, target_vehicle)
    if overtaking.is_overtaking then
        return false, "Обгон уже выполняется"
    end
    
    log("Overtaking: Начало маневра обгона")
    
    -- Сохранение параметров
    overtaking.is_overtaking = true
    overtaking.overtaking_phase = "preparing"
    overtaking.target_vehicle = target_vehicle.id
    overtaking.start_time = get_game_time()
    overtaking.original_lane = vehicle_data.lane
    overtaking.target_lane = vehicle_data.lane + 1
    overtaking.overtaking_speed = vehicle_data.speed * 3.6 + 15.0 -- на 15 км/ч быстрее
    
    -- Ограничение максимальной скорости
    overtaking.overtaking_speed = math.min(overtaking.overtaking_speed, overtaking.max_overtaking_speed)
    
    -- Включение левого поворотника
    set_turn_signal("left")
    
    -- Звуковое оповещение
    play_sound("overtaking_start")
    
    -- Визуальное оповещение
    show_message("ОБГОН: Начало маневра")
    
    return true
end

-- Обновление маневра обгона
function overtaking.update(dt, vehicle_data, obstacle_data)
    if not overtaking.is_overtaking then
        return
    end
    
    -- Проверка времени выполнения
    local current_time = get_game_time()
    if current_time - overtaking.start_time > overtaking.overtaking_duration_limit then
        overtaking.abort_overtaking("Превышено время выполнения маневра")
        return
    end
    
    -- Выполнение текущей фазы
    if overtaking.overtaking_phase == "preparing" then
        overtaking.phase_preparing(dt, vehicle_data)
    elseif overtaking.overtaking_phase == "changing_lane" then
        overtaking.phase_changing_lane(dt, vehicle_data)
    elseif overtaking.overtaking_phase == "passing" then
        overtaking.phase_passing(dt, vehicle_data, obstacle_data)
    elseif overtaking.overtaking_phase == "returning" then
        overtaking.phase_returning(dt, vehicle_data)
    end
end

-- Фаза подготовки
function overtaking.phase_preparing(dt, vehicle_data)
    -- Увеличение скорости до обгонной
    local target_speed = overtaking.overtaking_speed
    local current_speed = vehicle_data.speed * 3.6
    
    if current_speed < target_speed - 5.0 then
        -- Ускоряемся
        set_throttle(0.8)
        set_brake(0)
    else
        -- Переходим к следующей фазе
        overtaking.overtaking_phase = "changing_lane"
        log("Overtaking: Переход к фазе смены полосы")
    end
end

-- Фаза смены полосы
function overtaking.phase_changing_lane(dt, vehicle_data)
    -- Используем систему удержания полосы для перестроения
    local lane_keeping = require("lane_keeping")
    
    if lane_keeping then
        -- Инициируем смену полосы
        lane_keeping.execute_lane_change(overtaking.target_lane)
        
        -- Проверяем завершение смены полосы
        if lane_keeping.current_lane == overtaking.target_lane then
            overtaking.overtaking_phase = "passing"
            log("Overtaking: Переход к фазе обгона")
        end
    else
        -- Упрощенная реализация
        overtaking.overtaking_phase = "passing"
    end
end

-- Фаза обгона
function overtaking.phase_passing(dt, vehicle_data, obstacle_data)
    -- Поиск целевого транспортного средства
    local target_found = false
    
    for _, obstacle in ipairs(obstacle_data) do
        if obstacle.id == overtaking.target_vehicle then
            target_found = true
            
            -- Проверка, обогнали ли мы уже целевое транспортное средство
            if obstacle.distance < -10.0 then -- мы впереди
                overtaking.overtaking_phase = "returning"
                log("Overtaking: Цель обогнана, переход к фазе возвращения")
                break
            end
            
            -- Поддержание скорости обгона
            local current_speed = vehicle_data.speed * 3.6
            if current_speed < overtaking.overtaking_speed - 2.0 then
                set_throttle(0.7)
            elseif current_speed > overtaking.overtaking_speed + 2.0 then
                set_throttle(0)
                set_brake(0.2)
            else
                set_throttle(0.3)
            end
            
            break
        end
    end
    
    -- Если целевое транспортное средство не найдено
    if not target_found then
        overtaking.complete_overtaking("Целевое транспортное средство больше не обнаружено")
    end
end

-- Фаза возвращения
function overtaking.phase_returning(dt, vehicle_data)
    -- Возвращение в исходную полосу
    local lane_keeping = require("lane_keeping")
    
    if lane_keeping then
        -- Проверяем безопасность возвращения
        local safe_to_return = overtaking.check_safe_return(vehicle_data)
        
        if safe_to_return then
            -- Инициируем возвращение
            lane_keeping.execute_lane_change(overtaking.original_lane)
            
            -- Проверяем завершение возвращения
            if lane_keeping.current_lane == overtaking.original_lane then
                overtaking.complete_overtaking("Обгон успешно завершен")
            end
        else
            -- Ждем безопасной возможности для возвращения
            set_throttle(0.2) -- поддерживаем скорость
        end
    else
        -- Упрощенная реализация
        overtaking.complete_overtaking("Обгон завершен (упрощенный режим)")
    end
end

-- Проверка безопасности возвращения
function overtaking.check_safe_return(vehicle_data)
    -- Проверяем, нет ли транспортных средств сзади в исходной полосе
    local vehicles_behind = get_vehicles_behind_in_lane(overtaking.original_lane, vehicle_data.position.z, 50.0)
    
    if #vehicles_behind > 0 then
        return false
    end
    
    -- Проверяем дистанцию до обгоняемого транспортного средства
    local safe_distance = 30.0
    -- Здесь должна быть проверка расстояния до обгоняемого ТС
    
    return true
end

-- Завершение обгона
function overtaking.complete_overtaking(reason)
    log("Overtaking: Завершение обгона - " .. reason)
    
    -- Выключение поворотника
    set_turn_signal("off")
    
    -- Сброс состояния
    overtaking.is_overtaking = false
    overtaking.overtaking_phase = "none"
    overtaking.target_vehicle = nil
    
    -- Обновление статистики
    overtaking.completed_overtakes = overtaking.completed_overtakes + 1
    overtaking.last_overtake_time = get_game_time()
    
    -- Звуковое оповещение
    play_sound("overtaking_complete")
    
    -- Визуальное оповещение
    show_message("ОБГОН: Маневр завершен")
    
    return true
end

-- Прерывание обгона
function overtaking.abort_overtaking(reason)
    log("Overtaking: Прерывание обгона - " .. reason)
    
    -- Выключение поворотника
    set_turn_signal("off")
    
    -- Возвращение в исходную полосу (если возможно)
    local lane_keeping = require("lane_keeping")
    if lane_keeping and lane_keeping.current_lane ~= overtaking.original_lane then
        lane_keeping.execute_lane_change(overtaking.original_lane)
    end
    
    -- Сброс состояния
    overtaking.is_overtaking = false
    overtaking.overtaking_phase = "none"
    overtaking.target_vehicle = nil
    
    -- Обновление статистики
    overtaking.aborted_overtakes = overtaking.aborted_overtakes + 1
    
    -- Звуковое оповещение
    play_sound("overtaking_abort")
    
    -- Визуальное оповещение
    show_message("ОБГОН: Маневр прерван - " .. reason)
    
    return true
end

-- Проверка, выполняется ли обгон в данный момент
function overtaking.is_currently_overtaking(vehicle_id)
    return overtaking.is_overtaking and overtaking.target_vehicle == vehicle_id
end

-- Включение/выключение системы обгона
function overtaking.toggle()
    overtaking.enabled = not overtaking.enabled
    
    if overtaking.enabled then
        log("Overtaking: Система обгона включена")
        show_message("Обгон: ВКЛ")
    else
        log("Overtaking: Система обгона выключена")
        show_message("Обгон: ВЫКЛ")
        
        -- Если обгон выполняется, прерываем его
        if overtaking.is_overtaking then
            overtaking.abort_overtaking("Система обгона отключена пользователем")
        end
    end
    
    return overtaking.enabled
end

-- Получение информации о состоянии для отображения
function overtaking.get_status_info()
    return {
        enabled = overtaking.enabled,
        is_overtaking = overtaking.is_overtaking,
        overtaking_phase = overtaking.overtaking_phase,
        completed_overtakes = overtaking.completed_overtakes,
        aborted_overtakes = overtaking.aborted_overtakes
    }
end

-- Вспомогательные функции
function log(message)
    print("[Overtaking] " .. message)
end

function show_message(text)
    print("[Overtaking] " .. text)
end

function play_sound(sound_name)
    -- Заглушка для воспроизведения звука
end

return overtaking