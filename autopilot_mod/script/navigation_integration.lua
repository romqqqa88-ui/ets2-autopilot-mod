-- Интеграция с навигатором ETS 2
-- Получение данных о маршруте, точках поворотов и ограничениях скорости

local navigation = {
    current_route = {},
    route_length = 0,
    current_node_index = 1,
    destination_reached = false,
    
    -- Настройки
    node_lookahead = 3, -- количество точек вперед для планирования
    reroute_threshold = 50.0, -- метров, порог для перепланирования
    
    -- Данные навигатора
    has_destination = false,
    destination = nil,
    estimated_time = 0,
    distance_remaining = 0,
    
    -- Кэш
    last_update = 0,
    update_interval = 1.0 -- секунд
}

-- Инициализация интеграции с навигатором
function navigation.init()
    log("Navigation: Инициализация интеграции с навигатором")
    
    -- Проверка доступности API навигатора
    if not navigation.is_navigation_available() then
        log("Navigation: API навигатора недоступно")
        return false
    end
    
    return true
end

-- Проверка доступности навигатора
function navigation.is_navigation_available()
    -- Проверяем, доступны ли функции навигатора
    return pcall(function() return get_navigation_state() end)
end

-- Обновление данных навигатора
function navigation.update(dt)
    navigation.last_update = navigation.last_update + dt
    
    if navigation.last_update < navigation.update_interval then
        return
    end
    
    navigation.last_update = 0
    
    -- Получение текущего состояния навигатора
    local nav_state = get_navigation_state()
    
    if nav_state then
        navigation.has_destination = nav_state.has_destination
        navigation.destination = nav_state.destination
        navigation.estimated_time = nav_state.estimated_time or 0
        navigation.distance_remaining = nav_state.distance_remaining or 0
        
        -- Если есть пункт назначения, обновляем маршрут
        if navigation.has_destination then
            navigation.update_route()
        else
            navigation.current_route = {}
            navigation.route_length = 0
            navigation.current_node_index = 1
        end
    end
end

-- Обновление маршрута из навигатора
function navigation.update_route()
    local route_data = get_navigation_route()
    
    if not route_data or #route_data == 0 then
        log("Navigation: Данные маршрута не получены")
        return
    end
    
    -- Преобразование данных маршрута
    local new_route = {}
    
    for i, node in ipairs(route_data) do
        table.insert(new_route, {
            index = i,
            position = {x = node.x, y = node.y, z = node.z},
            type = node.type or "road",
            speed_limit = node.speed_limit or navigation.get_speed_limit_at(node.x, node.z),
            lane_count = node.lane_count or 2,
            is_intersection = node.is_intersection or false,
            is_tollgate = node.is_tollgate or false,
            is_ferry = node.is_ferry or false
        })
    end
    
    navigation.current_route = new_route
    navigation.route_length = #new_route
    
    -- Сброс индекса текущей точки
    navigation.adjust_current_node_index()
    
    log(string.format("Navigation: Маршрут обновлен, точек: %d, длина: %.1f км", 
        navigation.route_length, navigation.distance_remaining / 1000))
end

-- Получение ограничения скорости в точке
function navigation.get_speed_limit_at(x, z)
    -- Используем API игры для получения ограничения скорости
    local speed_limit = get_speed_limit_at_position(x, z)
    
    if speed_limit and speed_limit > 0 then
        return speed_limit
    end
    
    -- Значения по умолчанию в зависимости от типа дороги
    local road_type = get_road_type_at_position(x, z)
    
    if road_type == "highway" then
        return 110.0
    elseif road_type == "national" then
        return 90.0
    elseif road_type == "urban" then
        return 50.0
    else
        return 80.0
    end
end

-- Корректировка индекса текущей точки на основе позиции игрока
function navigation.adjust_current_node_index()
    local player_pos = get_player_position()
    if not player_pos or #navigation.current_route == 0 then
        return
    end
    
    -- Поиск ближайшей точки маршрута
    local closest_index = 1
    local closest_distance = math.huge
    
    for i = math.max(1, navigation.current_node_index - 5), 
             math.min(#navigation.current_route, navigation.current_node_index + 20) do
        local node = navigation.current_route[i]
        local dx = node.position.x - player_pos.x
        local dz = node.position.z - player_pos.z
        local distance = math.sqrt(dx*dx + dz*dz)
        
        if distance < closest_distance then
            closest_distance = distance
            closest_index = i
        end
    end
    
    -- Устанавливаем точку немного впереди, чтобы не "залипать" на пройденных
    navigation.current_node_index = math.min(closest_index + 2, #navigation.current_route)
end

-- Получение следующей точки маршрута для следования
function navigation.get_next_node(lookahead)
    lookahead = lookahead or 0
    
    local target_index = navigation.current_node_index + lookahead
    
    if target_index > #navigation.current_route then
        return nil
    end
    
    return navigation.current_route[target_index]
end

-- Получение сегмента маршрута для планирования
function navigation.get_route_segment(count)
    count = count or navigation.node_lookahead
    
    local segment = {}
    local start_index = navigation.current_node_index
    
    for i = start_index, math.min(start_index + count - 1, #navigation.current_route) do
        table.insert(segment, navigation.current_route[i])
    end
    
    return segment
end

-- Расчет кривизны дороги впереди
function navigation.calculate_road_curvature(lookahead_nodes)
    lookahead_nodes = lookahead_nodes or 5
    
    local segment = navigation.get_route_segment(lookahead_nodes)
    
    if #segment < 3 then
        return 0
    end
    
    -- Расчет углов между сегментами
    local total_angle = 0
    
    for i = 2, #segment - 1 do
        local p1 = segment[i-1].position
        local p2 = segment[i].position
        local p3 = segment[i+1].position
        
        local v1 = {x = p2.x - p1.x, z = p2.z - p1.z}
        local v2 = {x = p3.x - p2.x, z = p3.z - p2.z}
        
        local dot = v1.x * v2.x + v1.z * v2.z
        local mag1 = math.sqrt(v1.x*v1.x + v1.z*v1.z)
        local mag2 = math.sqrt(v2.x*v2.x + v2.z*v2.z)
        
        if mag1 > 0 and mag2 > 0 then
            local angle = math.acos(dot / (mag1 * mag2))
            total_angle = total_angle + angle
        end
    end
    
    return total_angle / (#segment - 2)
end

-- Проверка, достигнута ли точка назначения
function navigation.check_destination_reached()
    if not navigation.has_destination or #navigation.current_route == 0 then
        return false
    end
    
    local player_pos = get_player_position()
    local last_node = navigation.current_route[#navigation.current_route]
    
    if not player_pos or not last_node then
        return false
    end
    
    local dx = last_node.position.x - player_pos.x
    local dz = last_node.position.z - player_pos.z
    local distance = math.sqrt(dx*dx + dz*dz)
    
    navigation.destination_reached = distance < 50.0 -- метров
    
    if navigation.destination_reached then
        log("Navigation: Пункт назначения достигнут!")
    end
    
    return navigation.destination_reached
end

-- Перепланирование маршрута при отклонении
function navigation.check_reroute_needed(player_pos)
    if #navigation.current_route == 0 then
        return false
    end
    
    -- Находим расстояние до ближайшей точки маршрута
    local min_distance = math.huge
    
    for i = math.max(1, navigation.current_node_index - 3),
             math.min(#navigation.current_route, navigation.current_node_index + 10) do
        local node = navigation.current_route[i]
        local dx = node.position.x - player_pos.x
        local dz = node.position.z - player_pos.z
        local distance = math.sqrt(dx*dx + dz*dz)
        
        if distance < min_distance then
            min_distance = distance
        end
    end
    
    -- Если отклонение слишком велико, требуется перепланирование
    if min_distance > navigation.reroute_threshold then
        log(string.format("Navigation: Отклонение от маршрута %.1f м, требуется перепланирование", min_distance))
        return true
    end
    
    return false
end

-- Получение рекомендуемой скорости на основе маршрута
function navigation.get_recommended_speed(lookahead)
    local node = navigation.get_next_node(lookahead)
    
    if not node then
        return nil
    end
    
    -- Учет типа дороги и ограничений
    local base_speed = node.speed_limit or 80.0
    
    -- Корректировка на основе кривизны
    local curvature = navigation.calculate_road_curvature(3)
    if curvature > 0.5 then
        base_speed = base_speed * 0.7
    elseif curvature > 0.2 then
        base_speed = base_speed * 0.85
    end
    
    -- Учет перекрестков
    if node.is_intersection then
        base_speed = math.min(base_speed, 40.0)
    end
    
    return base_speed
end

-- Визуализация маршрута (для отладки)
function navigation.debug_draw_route()
    if #navigation.current_route == 0 then
        return
    end
    
    -- Рисуем линии между точками маршрута
    for i = 1, #navigation.current_route - 1 do
        local node1 = navigation.current_route[i]
        local node2 = navigation.current_route[i+1]
        
        draw_line_3d(node1.position, node2.position, {r = 0, g = 255, b = 0})
        
        -- Текущая точка выделена
        if i == navigation.current_node_index then
            draw_sphere(node1.position, 3.0, {r = 255, g = 0, b = 0})
        else
            draw_sphere(node1.position, 1.5, {r = 0, g = 200, b = 0})
        end
    end
    
    -- Последняя точка (пункт назначения)
    local last_node = navigation.current_route[#navigation.current_route]
    draw_sphere(last_node.position, 4.0, {r = 255, g = 255, b = 0})
    
    -- Информация о маршруте
    local player_pos = get_player_position()
    if player_pos then
        draw_text_3d({x = player_pos.x, y = player_pos.y + 5, z = player_pos.z},
            string.format("Маршрут: %d/%d точек, осталось: %.1f км", 
                navigation.current_node_index, #navigation.current_route,
                navigation.distance_remaining / 1000),
            {r = 255, g = 255, b = 255})
    end
end

-- Вспомогательная функция логирования
function log(message)
    print("[Navigation] " .. message)
end

return navigation