-- Система автоматической парковки для автопилота
-- Выполняет автоматический заезд в зону разгрузки/паркинга при достижении точки назначения

local automatic_parking = {
    -- Настройки
    enabled = true, -- включена ли система автоматической парковки
    parking_search_range = 200.0, -- дальность поиска парковочных мест (метры)
    max_parking_attempts = 3, -- максимальное количество попыток парковки
    
    -- Состояние парковки
    is_parking = false, -- выполняется ли парковка в данный момент
    parking_phase = "none", -- фаза парковки: none, searching, approaching, maneuvering, finalizing
    parking_spot = nil, -- выбранное парковочное место
    parking_attempts = 0, -- количество попыток парковки
    
    -- Параметры парковки
    parking_type = nil, -- тип парковки: parallel, perpendicular, diagonal, dock
    parking_difficulty = "medium", -- сложность парковки: easy, medium, hard
    
    -- Тайминги
    start_time = 0, -- время начала парковки
    phase_start_time = 0, -- время начала текущей фазы
    
    -- Статистика
    successful_parkings = 0,
    failed_parkings = 0,
    total_parking_time = 0
}

-- Инициализация системы автоматической парковки
function automatic_parking.init()
    log("Automatic Parking: Инициализация системы автоматической парковки")
    
    -- Загрузка конфигурации
    automatic_parking.load_config()
    
    -- Сброс состояния
    automatic_parking.reset()
    
    return true
end

-- Загрузка конфигурации
function automatic_parking.load_config()
    -- Здесь будет загрузка из конфигурационного файла
    automatic_parking.enabled = true
    automatic_parking.parking_search_range = 200.0
    automatic_parking.max_parking_attempts = 3
end

-- Сброс состояния
function automatic_parking.reset()
    automatic_parking.is_parking = false
    automatic_parking.parking_phase = "none"
    automatic_parking.parking_spot = nil
    automatic_parking.parking_attempts = 0
    automatic_parking.parking_type = nil
    automatic_parking.parking_difficulty = "medium"
    automatic_parking.start_time = 0
    automatic_parking.phase_start_time = 0
end

-- Проверка возможности автоматической парковки
function automatic_parking.check_parking_possible(destination_info, vehicle_data)
    if not automatic_parking.enabled then
        return false, "Система автоматической парковки отключена"
    end
    
    -- Проверка, достигнута ли точка назначения
    if not destination_info or not destination_info.reached then
        return false, "Точка назначения не достигнута"
    end
    
    -- Проверка наличия парковочных зон в точке назначения
    local parking_zones = automatic_parking.find_parking_zones(destination_info.position, vehicle_data.position)
    
    if #parking_zones == 0 then
        return false, "Парковочные зоны не найдены"
    end
    
    -- Выбор подходящего парковочного места
    local parking_spot, reason = automatic_parking.select_parking_spot(parking_zones, vehicle_data)
    
    if not parking_spot then
        return false, reason or "Не удалось выбрать парковочное место"
    end
    
    return true, parking_spot
end

-- Поиск парковочных зон
function automatic_parking.find_parking_zones(destination_position, vehicle_position)
    local parking_zones = get_parking_zones_near_position(destination_position.x, destination_position.z, 
                                                          automatic_parking.parking_search_range)
    local suitable_zones = {}
    
    for _, zone in ipairs(parking_zones) do
        -- Проверка типа парковочной зоны
        if automatic_parking.is_suitable_parking_type(zone.type) then
            -- Расчет расстояния до зоны
            local dx = zone.position.x - vehicle_position.x
            local dz = zone.position.z - vehicle_position.z
            local distance = math.sqrt(dx*dx + dz*dz)
            
            -- Проверка доступности
            if automatic_parking.check_zone_availability(zone) then
                table.insert(suitable_zones, {
                    id = zone.id,
                    type = zone.type,
                    position = zone.position,
                    orientation = zone.orientation,
                    size = zone.size,
                    difficulty = zone.difficulty or "medium",
                    distance = distance,
                    is_occupied = false
                })
            end
        end
    end
    
    -- Сортировка по расстоянию
    table.sort(suitable_zones, function(a, b)
        return a.distance < b.distance
    end)
    
    return suitable_zones
end

-- Проверка подходящего типа парковки
function automatic_parking.is_suitable_parking_type(parking_type)
    local suitable_types = {
        "dock", -- погрузочная рампа
        "parking", -- общая парковка
        "truck_parking", -- парковка для грузовиков
        "delivery" -- зона доставки
    }
    
    for _, suitable_type in ipairs(suitable_types) do
        if parking_type == suitable_type then
            return true
        end
    end
    
    return false
end

-- Проверка доступности парковочной зоны
function automatic_parking.check_zone_availability(zone)
    -- Проверка, не занята ли зона другими транспортными средствами
    local vehicles_in_zone = get_vehicles_in_area(zone.position, zone.size)
    
    if #vehicles_in_zone > 0 then
        return false
    end
    
    -- Проверка других препятствий
    local obstacles_in_zone = get_obstacles_in_area(zone.position, zone.size)
    
    if #obstacles_in_zone > 0 then
        return false
    end
    
    return true
end

-- Выбор парковочного места
function automatic_parking.select_parking_spot(parking_zones, vehicle_data)
    local vehicle_length = vehicle_data.length or 15.0 -- длина грузовика (метры)
    local vehicle_width = vehicle_data.width or 2.5 -- ширина грузовика (метры)
    
    for _, zone in ipairs(parking_zones) do
        -- Проверка размера парковочного места
        if automatic_parking.check_spot_size(zone, vehicle_length, vehicle_width) then
            -- Проверка сложности парковки
            if automatic_parking.check_parking_difficulty(zone, vehicle_data) then
                -- Расчет оптимального подъезда
                local approach_path = automatic_parking.calculate_approach_path(zone, vehicle_data.position)
                
                if approach_path then
                    return {
                        zone = zone,
                        approach_path = approach_path,
                        estimated_difficulty = zone.difficulty
                    }
                end
            end
        end
    end
    
    return nil, "Не найдено подходящих парковочных мест"
end

-- Проверка размера парковочного места
function automatic_parking.check_spot_size(zone, vehicle_length, vehicle_width)
    local min_length_multiplier = 1.2 -- минимальный запас по длине
    local min_width_multiplier = 1.5 -- минимальный запас по ширине
    
    if zone.size.length < vehicle_length * min_length_multiplier then
        return false
    end
    
    if zone.size.width < vehicle_width * min_width_multiplier then
        return false
    end
    
    return true
end

-- Проверка сложности парковки
function automatic_parking.check_parking_difficulty(zone, vehicle_data)
    -- Учитываем опыт водителя (если такая система есть)
    local driver_experience = get_driver_experience() or 1.0
    
    -- Корректировка сложности в зависимости от опыта
    local difficulty_levels = {
        easy = 0.5,
        medium = 1.0,
        hard = 1.5
    }
    
    local zone_difficulty = difficulty_levels[zone.difficulty] or 1.0
    
    -- Если сложность слишком высока для текущего опыта
    if zone_difficulty > driver_experience * 1.5 then
        return false
    end
    
    return true
end

-- Расчет пути подъезда
function automatic_parking.calculate_approach_path(zone, vehicle_position)
    -- Простой расчет прямолинейного подъезда
    -- В реальной реализации нужен более сложный алгоритм
    
    local approach_distance = 50.0 -- расстояние для подъезда
    local approach_angle = zone.orientation or 0
    
    -- Точка начала маневра
    local maneuver_start = {
        x = zone.position.x - math.sin(approach_angle) * approach_distance,
        y = zone.position.y,
        z = zone.position.z - math.cos(approach_angle) * approach_distance
    }
    
    -- Проверка доступности пути
    local path_clear = automatic_parking.check_path_clear(vehicle_position, maneuver_start, zone.position)
    
    if not path_clear then
        return nil
    end
    
    return {
        maneuver_start = maneuver_start,
        parking_position = zone.position,
        parking_orientation = approach_angle,
        waypoints = {maneuver_start, zone.position}
    }
end

-- Проверка доступности пути
function automatic_parking.check_path_clear(start_pos, intermediate_pos, end_pos)
    -- Проверка препятствий на пути
    local obstacles_on_path = get_obstacles_on_path(start_pos, end_pos, 5.0) -- 5 метров ширина коридора
    
    if #obstacles_on_path > 0 then
        return false
    end
    
    return true
end

-- Начало процесса парковки
function automatic_parking.start_parking(parking_spot, vehicle_data)
    if automatic_parking.is_parking then
        return false, "Парковка уже выполняется"
    end
    
    log("Automatic Parking: Начало процесса автоматической парковки")
    
    -- Сохранение параметров
    automatic_parking.is_parking = true
    automatic_parking.parking_phase = "searching"
    automatic_parking.parking_spot = parking_spot
    automatic_parking.parking_attempts = 1
    automatic_parking.parking_type = parking_spot.zone.type
    automatic_parking.parking_difficulty = parking_spot.estimated_difficulty
    automatic_parking.start_time = get_game_time()
    automatic_parking.phase_start_time = get_game_time()
    
    -- Звуковое оповещение
    play_sound("parking_start")
    
    -- Визуальное оповещение
    show_message("АВТОПАРКОВКА: Начало маневра")
    
    return true
end

-- Обновление процесса парковки
function automatic_parking.update(dt, vehicle_data)
    if not automatic_parking.is_parking then
        return
    end
    
    -- Проверка времени выполнения
    local current_time = get_game_time()
    local phase_duration = current_time - automatic_parking.phase_start_time
    
    -- Ограничение времени на фазу
    if phase_duration > automatic_parking.get_phase_time_limit(automatic_parking.parking_phase) then
        automatic_parking.handle_phase_timeout()
        return
    end
    
    -- Выполнение текущей фазы
    if automatic_parking.parking_phase == "searching" then
        automatic_parking.phase_searching(dt, vehicle_data)
    elseif automatic_parking.parking_phase == "approaching" then
        automatic_parking.phase_approaching(dt, vehicle_data)
    elseif automatic_parking.parking_phase == "maneuvering" then
        automatic_parking.phase_maneuvering(dt, vehicle_data)
    elseif automatic_parking.parking_phase == "finalizing" then
        automatic_parking.phase_finalizing(dt, vehicle_data)
    end
end

-- Получение ограничения времени для фазы
function automatic_parking.get_phase_time_limit(phase)
    local time_limits = {
        searching = 10.0,
        approaching = 30.0,
        maneuvering = 60.0,
        finalizing = 20.0
    }
    
    return time_limits[phase] or 30.0
end

-- Обработка таймаута фазы
function automatic_parking.handle_phase_timeout()
    log("Automatic Parking: Таймаут фазы " .. automatic_parking.parking_phase)
    
    if automatic_parking.parking_attempts < automatic_parking.max_parking_attempts then
        -- Повторная попытка
        automatic_parking.parking_attempts = automatic_parking.parking_attempts + 1
        automatic_parking.parking_phase = "searching"
        automatic_parking.phase_start_time = get_game_time()
        
        log("Automatic Parking: Повторная попытка парковки (" .. automatic_parking.parking_attempts .. ")")
        show_message("АВТОПАРКОВКА: Повторная попытка")
    else
        -- Прерывание парковки
        automatic_parking.abort_parking("Превышено время выполнения")
    end
end

-- Фаза поиска парковочного места
function automatic_parking.phase_searching(dt, vehicle_data)
    -- В этой фазе мы уже выбрали место, просто переходим к следующей фазе
    automatic_parking.parking_phase = "approaching"
    automatic_parking.phase_start_time = get_game_time()
    
    log("Automatic Parking: Переход к фазе подъезда")
    show_message("АВТОПАРКОВКА: Подъезд к месту парковки")
end

-- Фаза подъезда к месту парковки
function automatic_parking.phase_approaching(dt, vehicle_data)
    local target_pos = automatic_parking.parking_spot.approach_path.maneuver_start
    local current_pos = vehicle_data.position
    
    -- Расчет расстояния до точки подъезда
    local dx = target_pos.x - current_pos.x
    local dz = target_pos.z - current_pos.z
    local distance = math.sqrt(dx*dx + dz*dz)
    
    if distance < 5.0 then
        -- Достигли точки подъезда
        automatic_parking.parking_phase = "maneuvering"
        automatic_parking.phase_start_time = get_game_time()
        
        log("Automatic Parking: Переход к фазе маневрирования")
        show_message("АВТОПАРКОВКА: Маневрирование на месте")
        
        -- Включение аварийной сигнализации
        set_hazard_lights(true)
    else
        -- Движение к точке подъезда
        automatic_parking.move_to_position(target_pos, vehicle_data, 10.0) -- скорость 10 км/ч
    end
end

-- Фаза маневрирования на месте
function automatic_parking.phase_maneuvering(dt, vehicle_data)
    local target_pos = automatic_parking.parking_spot.zone.position
    local target_orientation = automatic_parking.parking_spot.approach_path.parking_orientation
    local current_pos = vehicle_data.position
    local current_orientation = vehicle_data.orientation
    
    -- Расчет расстояния до целевой позиции
    local dx = target_pos.x - current_pos.x
    local dz = target_pos.z - current_pos.z
    local distance = math.sqrt(dx*dx + dz*dz)
    
    -- Расчет разницы ориентации
    local orientation_diff = math.abs(target_orientation - current_orientation)
    while orientation_diff > math.pi do orientation_diff = orientation_diff - 2*math.pi end
    orientation_diff = math.abs(orientation_diff)
    
    if distance < 1.0 and orientation_diff < 0.1 then
        -- Успешно припарковались
        automatic_parking.parking_phase = "finalizing"
        automatic_parking.phase_start_time = get_game_time()
        
        log("Automatic Parking: Переход к фазе завершения")
        show_message("АВТОПАРКОВКА: Завершение маневра")
    else
        -- Выполнение маневра парковки
        automatic_parking.execute_parking_maneuver(target_pos, target_orientation, vehicle_data)
    end
end

-- Фаза завершения парковки
function automatic_parking.phase_finalizing(dt, vehicle_data)
    -- Остановка двигателя
    set_throttle(0)
    set_brake(1.0)
    
    -- Включение стояночного тормоза
    set_parking_brake(true)
    
    -- Выключение аварийной сигнализации
    set_hazard_lights(false)
    
    -- Завершение парковки
    automatic_parking.complete_parking("Парковка успешно завершена")
end

-- Движение к целевой позиции
function automatic_parking.move_to_position(target_pos, vehicle_data, target_speed_kmh)
    local current_pos = vehicle_data.position
    local current_speed = vehicle_data.speed * 3.6 -- км/ч
    
    -- Расчет направления
    local dx = target_pos.x - current_pos.x
    local dz = target_pos.z - current_pos.z
    local target_angle = math.atan2(dx, dz)
    
    -- Управление рулевым колесом
    local steering = automatic_parking.calculate_steering(current_pos, vehicle_data.orientation, target_angle)
    set_steering(steering)
    
    -- Управление скоростью
    if current_speed < target_speed_kmh - 2.0 then
        set_throttle(0.3)
        set_brake(0)
    elseif current_speed > target_speed_kmh + 2.0 then
        set_throttle(0)
        set_brake(0.2)
    else
        set_throttle(0.1)
    end
end

-- Расчет рулевого управления
function automatic_parking.calculate_steering(current_pos, current_orientation, target_angle)
    local angle_diff = target_angle - current_orientation
    
    -- Нормализация угла
    while angle_diff > math.pi do angle_diff = angle_diff - 2*math.pi end
    while angle_diff < -math.pi do angle_diff = angle_diff + 2*math.pi end
    
    -- Пропорциональное управление
    local steering = angle_diff * 0.5
    
    -- Ограничение
    steering = math.max(-1.0, math.min(1.0, steering))
    
    return steering
end

-- Выполнение маневра парковки
function automatic_parking.execute_parking_maneuver(target_pos, target_orientation, vehicle_data)
    -- В зависимости от типа парковки выполняем разные маневры
    
    if automatic_parking.parking_type == "dock" then
        automatic_parking.execute_dock_maneuver(target_pos, target_orientation, vehicle_data)
    else
        automatic_parking.execute_standard_maneuver(target_pos, target_orientation, vehicle_data)
    end
end

-- Маневр парковки к погрузочной рампе
function automatic_parking.execute_dock_maneuver(target_pos, target_orientation, vehicle_data)
    -- Прямолинейное движение назад к рампе
    set_steering(0)
    set_throttle(0)
    set_brake(0)
    
    -- Движение назад на низкой скорости
    set_reverse(true)
    set_throttle(0.2)
end

-- Стандартный маневр парковки
function automatic_parking.execute_standard_maneuver(target_pos, target_orientation, vehicle_data)
    -- Простой алгоритм парковки с несколькими маневрами
    local current_pos = vehicle_data.position
    local distance = calculate_distance(current_pos, target_pos)
    
    if distance > 10.0 then
        -- Подъезд на расстояние
        automatic_parking.move_to_position(target_pos, vehicle_data, 15.0)
    else
        -- Маневрирование на месте
        automatic_parking.maneuver_in_place(target_pos, target_orientation, vehicle_data)
    end
end

-- Маневрирование на месте
function automatic_parking.maneuver_in_place(target_pos, target_orientation, vehicle_data)
    -- Чередование движения вперед-назад с поворотами руля
    local maneuver_phase = math.floor(get_game_time() * 2) % 4
    
    if maneuver_phase == 0 then
        -- Движение вперед с поворотом влево
        set_steering(-0.8)
        set_reverse(false)
        set_throttle(0.3)
    elseif maneuver_phase == 1 then
        -- Движение назад с поворотом вправо
        set_steering(0.8)
        set_reverse(true)
        set_throttle(0.3)
    elseif maneuver_phase == 2 then
        -- Движение вперед с поворотом вправо
        set_steering(0.8)
        set_reverse(false)
        set_throttle(0.3)
    else
        -- Движение назад с поворотом влево
        set_steering(-0.8)
        set_reverse(true)
        set_throttle(0.3)
    end
end

-- Завершение парковки
function automatic_parking.complete_parking(reason)
    log("Automatic Parking: Завершение парковки - " .. reason)
    
    -- Полная остановка
    set_throttle(0)
    set_brake(1.0)
    set_parking_brake(true)
    set_engine(false) -- заглушить двигатель
    
    -- Сброс состояния
    automatic_parking.is_parking = false
    automatic_parking.parking_phase = "none"
    
    -- Обновление статистики
    automatic_parking.successful_parkings = automatic_parking.successful_parkings + 1
    automatic_parking.total_parking_time = automatic_parking.total_parking_time + (get_game_time() - automatic_parking.start_time)
    
    -- Звуковое оповещение
    play_sound("parking_complete")
    
    -- Визуальное оповещение
    show_message("АВТОПАРКОВКА: Успешно завершена!")
    
    -- Отключение автопилота
    local autopilot = require("autopilot")
    if autopilot then
        autopilot.enabled = false
        log("Automatic Parking: Автопилот отключен после успешной парковки")
    end
    
    return true
end

-- Прерывание парковки
function automatic_parking.abort_parking(reason)
    log("Automatic Parking: Прерывание парковки - " .. reason)
    
    -- Остановка
    set_throttle(0)
    set_brake(0.5)
    set_hazard_lights(false)
    
    -- Сброс состояния
    automatic_parking.is_parking = false
    automatic_parking.parking_phase = "none"
    
    -- Обновление статистики
    automatic_parking.failed_parkings = automatic_parking.failed_parkings + 1
    
    -- Звуковое оповещение
    play_sound("parking_abort")
    
    -- Визуальное оповещение
    show_message("АВТОПАРКОВКА: Прервана - " .. reason)
    
    return true
end

-- Включение/выключение системы автоматической парковки
function automatic_parking.toggle()
    automatic_parking.enabled = not automatic_parking.enabled
    
    if automatic_parking.enabled then
        log("Automatic Parking: Система автоматической парковки включена")
        show_message("Автопарковка: ВКЛ")
    else
        log("Automatic Parking: Система автоматической парковки выключена")
        show_message("Автопарковка: ВЫКЛ")
        
        -- Если парковка выполняется, прерываем ее
        if automatic_parking.is_parking then
            automatic_parking.abort_parking("Система отключена пользователем")
        end
    end
    
    return automatic_parking.enabled
end

-- Получение информации о состоянии для отображения
function automatic_parking.get_status_info()
    return {
        enabled = automatic_parking.enabled,
        is_parking = automatic_parking.is_parking,
        parking_phase = automatic_parking.parking_phase,
        parking_type = automatic_parking.parking_type,
        parking_attempts = automatic_parking.parking_attempts,
        successful_parkings = automatic_parking.successful_parkings,
        failed_parkings = automatic_parking.failed_parkings
    }
end

-- Вспомогательные функции
function log(message)
    print("[Automatic Parking] " .. message)
end

function show_message(text)
    print("[Automatic Parking] " .. text)
end

function play_sound(sound_name)
    -- Заглушка для воспроизведения звука
end

function calculate_distance(pos1, pos2)
    local dx = pos1.x - pos2.x
    local dz = pos1.z - pos2.z
    return math.sqrt(dx*dx + dz*dz)
end

return automatic_parking