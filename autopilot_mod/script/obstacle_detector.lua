-- Детектор препятствий для автопилота
-- Обнаруживает другие транспортные средства, пешеходов и объекты на дороге

local obstacle_detector = {
    detection_range = 100.0, -- метров
    lateral_range = 5.0, -- метров по бокам
    update_interval = 0.2, -- секунд
    
    -- Обнаруженные препятствия
    obstacles = {},
    
    -- Пороги реакции
    safe_distance = 30.0, -- безопасная дистанция (м)
    warning_distance = 50.0, -- дистанция предупреждения (м)
    emergency_distance = 15.0, -- экстренная дистанция (м)
    
    -- Состояние
    last_update = 0
}

-- Обновление обнаружения препятствий
function obstacle_detector.update(dt, vehicle_position, vehicle_direction, vehicle_speed)
    obstacle_detector.last_update = obstacle_detector.last_update + dt
    
    if obstacle_detector.last_update < obstacle_detector.update_interval then
        return
    end
    
    obstacle_detector.last_update = 0
    
    -- Очистка предыдущих данных
    obstacle_detector.obstacles = {}
    
    -- Получение объектов в радиусе обнаружения
    local nearby_vehicles = get_nearby_vehicles(vehicle_position, obstacle_detector.detection_range)
    local nearby_pedestrians = get_nearby_pedestrians(vehicle_position, obstacle_detector.detection_range * 0.5)
    local nearby_objects = get_nearby_objects(vehicle_position, obstacle_detector.detection_range)
    
    -- Анализ транспортных средств
    for _, vehicle in ipairs(nearby_vehicles) do
        if vehicle.id ~= get_player_vehicle_id() then -- исключаем сам игровой грузовик
            local obstacle = obstacle_detector.analyze_vehicle(vehicle, vehicle_position, vehicle_direction, vehicle_speed)
            if obstacle then
                table.insert(obstacle_detector.obstacles, obstacle)
            end
        end
    end
    
    -- Анализ пешеходов
    for _, pedestrian in ipairs(nearby_pedestrians) do
        local obstacle = obstacle_detector.analyze_pedestrian(pedestrian, vehicle_position, vehicle_direction)
        if obstacle then
            table.insert(obstacle_detector.obstacles, obstacle)
        end
    end
    
    -- Анализ статических объектов
    for _, object in ipairs(nearby_objects) do
        local obstacle = obstacle_detector.analyze_object(object, vehicle_position, vehicle_direction)
        if obstacle then
            table.insert(obstacle_detector.obstacles, obstacle)
        end
    end
    
    -- Сортировка по опасности
    table.sort(obstacle_detector.obstacles, function(a, b)
        return a.danger_level > b.danger_level
    end)
end

-- Анализ транспортного средства
function obstacle_detector.analyze_vehicle(vehicle, player_pos, player_dir, player_speed)
    local rel_pos = {
        x = vehicle.position.x - player_pos.x,
        y = vehicle.position.y - player_pos.y,
        z = vehicle.position.z - player_pos.z
    }
    
    -- Расстояние до объекта
    local distance = math.sqrt(rel_pos.x*rel_pos.x + rel_pos.z*rel_pos.z)
    
    -- Угол относительно направления игрока
    local forward = {x = player_dir.x, z = player_dir.z}
    local dot = rel_pos.x * forward.x + rel_pos.z * forward.z
    local angle = math.acos(dot / (distance * math.sqrt(forward.x*forward.x + forward.z*forward.z)))
    
    -- Боковое смещение
    local lateral = math.abs(math.sin(angle) * distance)
    
    -- Относительная скорость
    local relative_speed = vehicle.speed - player_speed
    
    -- Определение опасности
    local danger_level = 0
    local action = "none"
    
    if distance < obstacle_detector.emergency_distance and lateral < 3.0 then
        danger_level = 3 -- экстренная ситуация
        action = "emergency_brake"
    elseif distance < obstacle_detector.safe_distance and lateral < 4.0 then
        danger_level = 2 -- опасная ситуация
        action = "brake_or_change_lane"
    elseif distance < obstacle_detector.warning_distance and lateral < 5.0 then
        danger_level = 1 -- предупреждение
        action = "reduce_speed"
    end
    
    -- Учет относительной скорости
    if relative_speed < -10 then -- объект движется медленнее
        danger_level = danger_level + 1
    end
    
    return {
        type = "vehicle",
        id = vehicle.id,
        position = vehicle.position,
        speed = vehicle.speed,
        distance = distance,
        lateral_offset = lateral,
        angle = angle,
        relative_speed = relative_speed,
        danger_level = math.min(danger_level, 3),
        recommended_action = action,
        time_to_collision = obstacle_detector.calculate_ttc(distance, relative_speed)
    }
end

-- Анализ пешехода
function obstacle_detector.analyze_pedestrian(pedestrian, player_pos, player_dir)
    local rel_pos = {
        x = pedestrian.position.x - player_pos.x,
        z = pedestrian.position.z - player_pos.z
    }
    
    local distance = math.sqrt(rel_pos.x*rel_pos.x + rel_pos.z*rel_pos.z)
    local lateral = math.abs(rel_pos.x)
    
    local danger_level = 0
    local action = "none"
    
    if distance < 20.0 and lateral < 3.0 then
        danger_level = 3
        action = "emergency_brake"
    elseif distance < 30.0 and lateral < 5.0 then
        danger_level = 2
        action = "brake"
    end
    
    return {
        type = "pedestrian",
        id = pedestrian.id,
        position = pedestrian.position,
        distance = distance,
        lateral_offset = lateral,
        danger_level = danger_level,
        recommended_action = action
    }
end

-- Анализ статического объекта
function obstacle_detector.analyze_object(object, player_pos, player_dir)
    local rel_pos = {
        x = object.position.x - player_pos.x,
        z = object.position.z - player_pos.z
    }
    
    local distance = math.sqrt(rel_pos.x*rel_pos.x + rel_pos.z*rel_pos.z)
    local lateral = math.abs(rel_pos.x)
    
    local danger_level = 0
    local action = "none"
    
    if distance < 25.0 and lateral < 2.5 then
        danger_level = 3
        action = "change_lane"
    elseif distance < 40.0 and lateral < 3.0 then
        danger_level = 2
        action = "reduce_speed"
    end
    
    return {
        type = "object",
        id = object.id,
        position = object.position,
        distance = distance,
        lateral_offset = lateral,
        danger_level = danger_level,
        recommended_action = action
    }
end

-- Расчет времени до столкновения
function obstacle_detector.calculate_ttc(distance, relative_speed)
    if relative_speed <= 0 then
        return math.huge -- никогда не столкнется
    end
    return distance / relative_speed
end

-- Получение самого опасного препятствия
function obstacle_detector.get_most_dangerous()
    if #obstacle_detector.obstacles == 0 then
        return nil
    end
    return obstacle_detector.obstacles[1]
end

-- Проверка необходимости экстренного торможения
function obstacle_detector.needs_emergency_brake()
    for _, obstacle in ipairs(obstacle_detector.obstacles) do
        if obstacle.danger_level >= 3 then
            return true, obstacle
        end
    end
    return false, nil
end

-- Проверка необходимости смены полосы
function obstacle_detector.needs_lane_change()
    for _, obstacle in ipairs(obstacle_detector.obstacles) do
        if obstacle.recommended_action == "change_lane" or 
           (obstacle.recommended_action == "brake_or_change_lane" and obstacle.distance > 20) then
            return true, obstacle
        end
    end
    return false, nil
end

-- Рекомендация по скорости на основе препятствий
function obstacle_detector.recommended_speed(current_speed, target_speed)
    local most_dangerous = obstacle_detector.get_most_dangerous()
    
    if not most_dangerous then
        return target_speed
    end
    
    if most_dangerous.danger_level >= 2 then
        -- Уменьшить скорость пропорционально опасности
        local reduction = 0.3 * most_dangerous.danger_level
        return target_speed * (1 - reduction)
    end
    
    return target_speed
end

-- Визуализация препятствий (для отладки)
function obstacle_detector.debug_draw()
    for _, obstacle in ipairs(obstacle_detector.obstacles) do
        local color = {r = 255, g = 0, b = 0}
        
        if obstacle.danger_level == 3 then
            color = {r = 255, g = 0, b = 0} -- красный
        elseif obstacle.danger_level == 2 then
            color = {r = 255, g = 165, b = 0} -- оранжевый
        elseif obstacle.danger_level == 1 then
            color = {r = 255, g = 255, b = 0} -- желтый
        end
        
        draw_sphere(obstacle.position, 2.0, color)
        draw_text_3d(obstacle.position, 
            string.format("%s: %.1fm", obstacle.type, obstacle.distance), 
            color)
    end
end

return obstacle_detector