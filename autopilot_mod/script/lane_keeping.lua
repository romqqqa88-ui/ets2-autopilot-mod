-- Система удержания полосы движения для автопилота
-- Обеспечивает движение в пределах текущей полосы с учетом разметки

local lane_keeping = {
    -- Настройки
    lane_width = 3.5, -- стандартная ширина полосы (метры)
    lane_change_threshold = 0.3, -- порог для начала смены полосы
    max_lateral_offset = 1.5, -- максимальное боковое смещение (м)
    
    -- Текущее состояние
    current_lane = 1, -- номер текущей полосы (1 - правая, 2 - левая и т.д.)
    total_lanes = 2, -- общее количество полос
    lane_center = 0, -- центр текущей полосы в локальных координатах
    lateral_offset = 0, -- текущее боковое смещение от центра полосы
    
    -- Данные дороги
    road_edges = {}, -- границы дороги
    lane_markings = {}, -- разметка полос
    
    -- Параметры управления
    steering_correction = 0,
    lane_keeping_active = true,
    
    -- Статистика
    lane_departure_count = 0,
    last_departure_time = 0
}

-- Инициализация системы удержания полосы
function lane_keeping.init()
    log("Lane Keeping: Инициализация системы удержания полосы")
    
    -- Загрузка конфигурации
    lane_keeping.load_config()
    
    -- Сброс состояния
    lane_keeping.reset()
    
    return true
end

-- Загрузка конфигурации
function lane_keeping.load_config()
    -- Здесь будет загрузка из конфигурационного файла
    lane_keeping.lane_width = 3.5
    lane_keeping.max_lateral_offset = 1.5
    lane_keeping.lane_change_threshold = 0.3
end

-- Сброс состояния
function lane_keeping.reset()
    lane_keeping.current_lane = 1
    lane_keeping.total_lanes = 2
    lane_keeping.lane_center = 0
    lane_keeping.lateral_offset = 0
    lane_keeping.steering_correction = 0
    lane_keeping.lane_departure_count = 0
end

-- Обновление данных о дороге
function lane_keeping.update_road_data(vehicle_position, vehicle_direction)
    -- Получение информации о дороге под транспортным средством
    local road_info = get_road_info_at_position(vehicle_position.x, vehicle_position.z)
    
    if not road_info then
        return false
    end
    
    -- Обновление информации о полосах
    lane_keeping.total_lanes = road_info.lane_count or 2
    lane_keeping.lane_width = road_info.lane_width or 3.5
    
    -- Определение текущей полосы
    lane_keeping.determine_current_lane(vehicle_position, road_info)
    
    -- Получение разметки
    lane_keeping.update_lane_markings(vehicle_position, road_info)
    
    -- Расчет центра текущей полосы
    lane_keeping.calculate_lane_center(vehicle_position, vehicle_direction)
    
    -- Расчет бокового смещения
    lane_keeping.calculate_lateral_offset(vehicle_position)
    
    return true
end

-- Определение текущей полосы
function lane_keeping.determine_current_lane(vehicle_position, road_info)
    if not road_info.lanes then
        lane_keeping.current_lane = 1
        return
    end
    
    -- Поиск ближайшей полосы
    local closest_lane = 1
    local min_distance = math.huge
    
    for i, lane in ipairs(road_info.lanes) do
        local distance = math.abs(lane.center_x - vehicle_position.x)
        if distance < min_distance then
            min_distance = distance
            closest_lane = i
        end
    end
    
    lane_keeping.current_lane = closest_lane
end

-- Обновление данных о разметке
function lane_keeping.update_lane_markings(vehicle_position, road_info)
    lane_keeping.lane_markings = {}
    
    if road_info.markings then
        for _, marking in ipairs(road_info.markings) do
            table.insert(lane_keeping.lane_markings, {
                type = marking.type, -- solid, dashed, double
                position = marking.position,
                width = marking.width or 0.15
            })
        end
    end
end

-- Расчет центра полосы
function lane_keeping.calculate_lane_center(vehicle_position, vehicle_direction)
    -- В упрощенной реализации считаем, что центр полосы совпадает с центром дороги
    -- В реальной реализации нужно учитывать положение полосы относительно центра дороги
    
    local road_center = get_road_center_at_position(vehicle_position.x, vehicle_position.z)
    
    if not road_center then
        lane_keeping.lane_center = 0
        return
    end
    
    -- Для правой полосы (1) - смещение вправо от центра дороги
    -- Для левой полосы (2) - смещение влево от центра дороги
    local lane_offset = (lane_keeping.current_lane - (lane_keeping.total_lanes + 1) / 2) * lane_keeping.lane_width
    
    lane_keeping.lane_center = road_center + lane_offset
end

-- Расчет бокового смещения
function lane_keeping.calculate_lateral_offset(vehicle_position)
    lane_keeping.lateral_offset = vehicle_position.x - lane_keeping.lane_center
end

-- Расчет коррекции рулевого управления
function lane_keeping.calculate_steering_correction()
    if not lane_keeping.lane_keeping_active then
        return 0
    end
    
    -- Пропорциональный контроль
    local kp = 0.3 -- коэффициент пропорциональности
    local correction = -lane_keeping.lateral_offset * kp / lane_keeping.lane_width
    
    -- Ограничение коррекции
    correction = math.max(-0.5, math.min(0.5, correction))
    
    -- Учет скорости (меньшая коррекция на высокой скорости)
    local speed = get_vehicle_speed() or 0
    local speed_factor = math.max(0.3, 1.0 - speed / 100.0)
    correction = correction * speed_factor
    
    lane_keeping.steering_correction = correction
    
    -- Проверка выезда из полосы
    lane_keeping.check_lane_departure()
    
    return correction
end

-- Проверка выезда из полосы
function lane_keeping.check_lane_departure()
    local departure_threshold = lane_keeping.lane_width * 0.4 -- 40% от ширины полосы
    
    if math.abs(lane_keeping.lateral_offset) > departure_threshold then
        local current_time = get_game_time()
        
        -- Защита от частых срабатываний
        if current_time - lane_keeping.last_departure_time > 1.0 then
            lane_keeping.lane_departure_count = lane_keeping.lane_departure_count + 1
            lane_keeping.last_departure_time = current_time
            
            log("Lane Keeping: Выезд из полосы! Смещение: " .. string.format("%.2f", lane_keeping.lateral_offset) .. " м")
            
            -- Визуальное и звуковое предупреждение
            if lane_keeping.lane_departure_count > 3 then
                show_message("ВНИМАНИЕ: Частые выезды из полосы!")
            end
        end
    end
end

-- Проверка необходимости смены полосы
function lane_keeping.check_lane_change_needed()
    -- Проверяем, нужно ли сменить полосу для обгона или поворота
    
    -- Если есть препятствие впереди
    local obstacle_ahead = lane_keeping.check_obstacle_ahead()
    
    -- Если приближается поворот
    local turn_coming = lane_keeping.check_upcoming_turn()
    
    -- Если нужно сменить полосу для следования по маршруту
    local route_lane = lane_keeping.get_recommended_lane_from_route()
    
    local target_lane = lane_keeping.current_lane
    
    if obstacle_ahead and lane_keeping.current_lane == 1 and lane_keeping.total_lanes > 1 then
        -- Препятствие впереди в правой полосе, можно перестроиться влево
        target_lane = 2
    elseif turn_coming == "left" and lane_keeping.current_lane ~= lane_keeping.total_lanes then
        -- Поворот налево, нужно перестроиться в левую полосу
        target_lane = lane_keeping.total_lanes
    elseif turn_coming == "right" and lane_keeping.current_lane ~= 1 then
        -- Поворот направо, нужно перестроиться в правую полосу
        target_lane = 1
    elseif route_lane and route_lane ~= lane_keeping.current_lane then
        -- Рекомендуемая полоса из маршрута
        target_lane = route_lane
    end
    
    if target_lane ~= lane_keeping.current_lane then
        return true, target_lane
    end
    
    return false, lane_keeping.current_lane
end

-- Проверка препятствия впереди
function lane_keeping.check_obstacle_ahead()
    -- Используем систему обнаружения препятствий
    local obstacle_detector = require("obstacle_detector")
    
    if obstacle_detector and #obstacle_detector.obstacles > 0 then
        for _, obstacle in ipairs(obstacle_detector.obstacles) do
            -- Проверяем, находится ли препятствие в нашей полосе
            if obstacle.distance < 50.0 and math.abs(obstacle.lateral_offset) < lane_keeping.lane_width * 0.5 then
                -- Проверяем скорость препятствия
                if obstacle.relative_speed < -5.0 then -- движется медленнее нас
                    return true
                end
            end
        end
    end
    
    return false
end

-- Проверка приближающегося поворота
function lane_keeping.check_upcoming_turn()
    local navigation = require("navigation_integration")
    
    if not navigation or #navigation.current_route == 0 then
        return nil
    end
    
    -- Анализируем следующие точки маршрута
    local lookahead = 5
    local segment = navigation.get_route_segment(lookahead)
    
    if #segment < 3 then
        return nil
    end
    
    -- Расчет направления поворота
    local total_angle = 0
    local turn_direction = nil
    
    for i = 2, #segment - 1 do
        local p1 = segment[i-1].position
        local p2 = segment[i].position
        local p3 = segment[i+1].position
        
        local v1 = {x = p2.x - p1.x, z = p2.z - p1.z}
        local v2 = {x = p3.x - p2.x, z = p3.z - p2.z}
        
        local cross = v1.x * v2.z - v1.z * v2.x
        
        if math.abs(cross) > 0.1 then
            total_angle = total_angle + (cross > 0 and 1 or -1)
        end
    end
    
    if total_angle > 0.5 then
        turn_direction = "left"
    elseif total_angle < -0.5 then
        turn_direction = "right"
    end
    
    return turn_direction
end

-- Получение рекомендуемой полосы из маршрута
function lane_keeping.get_recommended_lane_from_route()
    -- В упрощенной реализации возвращаем nil
    -- В реальной реализации нужно анализировать маршрут и дорожные знаки
    return nil
end

-- Выполнение смены полосы
function lane_keeping.execute_lane_change(target_lane)
    if target_lane == lane_keeping.current_lane then
        return false
    end
    
    log("Lane Keeping: Начало смены полосы с " .. lane_keeping.current_lane .. " на " .. target_lane)
    
    -- Расчет целевого смещения
    local lane_diff = target_lane - lane_keeping.current_lane
    local target_offset = lane_diff * lane_keeping.lane_width
    
    -- Плавное перестроение
    local current_time = get_game_time()
    lane_keeping.lane_change_start_time = current_time
    lane_keeping.lane_change_target = target_lane
    lane_keeping.lane_change_progress = 0
    
    -- Включение поворотника
    if lane_diff > 0 then
        set_turn_signal("left")
    else
        set_turn_signal("right")
    end
    
    return true
end

-- Обновление процесса смены полосы
function lane_keeping.update_lane_change(dt)
    if not lane_keeping.lane_change_target then
        return false
    end
    
    local progress = lane_keeping.lane_change_progress or 0
    progress = progress + dt * 0.5 -- скорость смены полосы
    
    if progress >= 1.0 then
        -- Завершение смены полосы
        lane_keeping.current_lane = lane_keeping.lane_change_target
        lane_keeping.lane_change_target = nil
        lane_keeping.lane_change_progress = nil
        
        -- Выключение поворотника
        set_turn_signal("off")
        
        log("Lane Keeping: Смена полосы завершена. Текущая полоса: " .. lane_keeping.current_lane)
        
        return true
    end
    
    lane_keeping.lane_change_progress = progress
    
    -- Временное отключение удержания полосы во время смены
    lane_keeping.lane_keeping_active = false
    
    return false
end

-- Включение/выключение системы удержания полосы
function lane_keeping.toggle()
    lane_keeping.lane_keeping_active = not lane_keeping.lane_keeping_active
    
    if lane_keeping.lane_keeping_active then
        log("Lane Keeping: Система удержания полосы включена")
        show_message("Удержание полосы: ВКЛ")
    else
        log("Lane Keeping: Система удержания полосы выключена")
        show_message("Удержание полосы: ВЫКЛ")
    end
    
    return lane_keeping.lane_keeping_active
end

-- Получение информации о состоянии для отображения
function lane_keeping.get_status_info()
    return {
        current_lane = lane_keeping.current_lane,
        total_lanes = lane_keeping.total_lanes,
        lateral_offset = lane_keeping.lateral_offset,
        lane_keeping_active = lane_keeping.lane_keeping_active,
        lane_departure_count = lane_keeping.lane_departure_count,
        lane_change_in_progress = lane_keeping.lane_change_target ~= nil
    }
end

-- Визуализация для отладки
function lane_keeping.debug_draw()
    if not lane_keeping.debug_mode then
        return
    end
    
    local vehicle_pos = get_vehicle_position()
    
    -- Отрисовка центра полосы
    if vehicle_pos then
        local lane_center_pos = {
            x = lane_keeping.lane_center,
            y = vehicle_pos.y + 0.5,
            z = vehicle_pos.z
        }
        
        draw_line_3d(vehicle_pos, lane_center_pos, {r = 0, g = 255, b = 0})
        draw_sphere(lane_center_pos, 0.5, {r = 0, g = 255, b = 0})
        
        -- Отрисовка границ полосы
        local left_bound = lane_keeping.lane_center - lane_keeping.lane_width / 2
        local right_bound = lane_keeping.lane_center + lane_keeping.lane_width / 2
        
        local left_pos = {x = left_bound, y = vehicle_pos.y + 0.3, z = vehicle_pos.z}
        local right_pos = {x = right_bound, y = vehicle_pos.y + 0.3, z = vehicle_pos.z}
        
        draw_sphere(left_pos, 0.3, {r = 255, g = 255, b = 0})
        draw_sphere(right_pos, 0.3, {r = 255, g = 255, b = 0})
        
        -- Текст информации
        draw_text_3d({x = vehicle_pos.x, y = vehicle_pos.y + 3, z = vehicle_pos.z},
            string.format("Полоса: %d/%d | Смещение: %.2f м", 
                lane_keeping.current_lane, lane_keeping.total_lanes, lane_keeping.lateral_offset),
            {r = 255, g = 255, b = 255})
    end
end

-- Вспомогательные функции
function log(message)
    print("[Lane Keeping] " .. message)
end

function show_message(text)
    print("[Lane Keeping] " .. text)
end

return lane_keeping