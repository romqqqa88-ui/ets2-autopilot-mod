-- Модуль парсинга навигационных данных для автопилота ETS 2
-- Интегрируется с встроенным навигатором игры для получения маршрута

local navigation_parser = {
    -- Конфигурация
    config = {
        lookahead_distance = 200.0,  -- дистанция просмотра вперед (метры)
        node_lookahead = 5,          -- количество узлов маршрута для анализа
        route_update_interval = 1.0, -- интервал обновления маршрута (секунды)
        use_game_navigation = true,  -- использовать встроенный навигатор игры
        alternative_routes = false,  -- анализ альтернативных маршрутов
        avoid_tolls = true,          -- избегать платных дорог
        avoid_ferries = true         -- избегать паромов
    },
    
    -- Состояние
    state = {
        current_route = nil,
        route_nodes = {},
        current_node_index = 1,
        total_distance = 0,
        estimated_time = 0,
        last_update_time = 0,
        route_valid = false,
        navigation_active = false
    },
    
    -- Кэш
    cache = {
        route_data = nil,
        last_cache_update = 0,
        cache_duration = 0.5  -- секунды
    }
}

-- Инициализация парсера навигации
function navigation_parser.init(config_overrides)
    -- Применение переопределений конфигурации
    if config_overrides then
        for key, value in pairs(config_overrides) do
            navigation_parser.config[key] = value
        end
    end
    
    -- Проверка доступности навигатора игры
    navigation_parser.state.navigation_active = navigation_parser.check_navigation_available()
    
    if not navigation_parser.state.navigation_active then
        navigation_parser.log_warning("Встроенный навигатор игры недоступен", "navigation")
        return false
    end
    
    navigation_parser.log_info("Парсер навигации инициализирован", "navigation")
    return true
end

-- Проверка доступности навигатора игры
function navigation_parser.check_navigation_available()
    -- Использование API игры для проверки навигатора
    -- В реальной реализации здесь будет вызов игрового API
    return true  -- Временная заглушка
end

-- Получение текущего маршрута из навигатора игры
function navigation_parser.get_current_route()
    local current_time = os.clock()
    
    -- Использование кэша для оптимизации производительности
    if navigation_parser.cache.route_data and 
       current_time - navigation_parser.cache.last_cache_update < navigation_parser.cache.cache_duration then
        return navigation_parser.cache.route_data
    end
    
    -- Получение данных маршрута из игры
    local route_data = navigation_parser.fetch_route_from_game()
    
    if not route_data then
        navigation_parser.state.route_valid = false
        return nil
    end
    
    -- Парсинг данных маршрута
    local parsed_route = navigation_parser.parse_route_data(route_data)
    
    if parsed_route then
        navigation_parser.state.current_route = parsed_route
        navigation_parser.state.route_nodes = parsed_route.nodes or {}
        navigation_parser.state.total_distance = parsed_route.total_distance or 0
        navigation_parser.state.estimated_time = parsed_route.estimated_time or 0
        navigation_parser.state.route_valid = true
        
        -- Обновление кэша
        navigation_parser.cache.route_data = parsed_route
        navigation_parser.cache.last_cache_update = current_time
    else
        navigation_parser.state.route_valid = false
    end
    
    return navigation_parser.state.current_route
end

-- Получение данных маршрута из игры (заглушка для API)
function navigation_parser.fetch_route_from_game()
    -- В реальной реализации здесь будет вызов игрового API
    -- Например: get_navigation_route(), get_route_nodes(), etc.
    
    -- Временная заглушка с тестовыми данными
    return {
        has_route = true,
        destination = "Берлин",
        total_distance = 350.5,  -- км
        estimated_time = 4.5,    -- часа
        nodes = {
            {x = 100, z = 200, type = "highway", speed_limit = 130},
            {x = 150, z = 250, type = "highway", speed_limit = 130},
            {x = 200, z = 300, type = "national", speed_limit = 90},
            {x = 250, z = 350, type = "urban", speed_limit = 50}
        },
        waypoints = 4,
        avoid_tolls = navigation_parser.config.avoid_tolls,
        avoid_ferries = navigation_parser.config.avoid_ferries
    }
end

-- Парсинг данных маршрута
function navigation_parser.parse_route_data(route_data)
    if not route_data or not route_data.has_route then
        return nil
    end
    
    local parsed = {
        destination = route_data.destination or "Неизвестно",
        total_distance = route_data.total_distance or 0,
        estimated_time = route_data.estimated_time or 0,
        nodes = {},
        waypoints = route_data.waypoints or 0,
        metadata = {
            avoid_tolls = route_data.avoid_tolls or false,
            avoid_ferries = route_data.avoid_ferries or false,
            timestamp = os.time()
        }
    }
    
    -- Парсинг узлов маршрута
    if route_data.nodes and #route_data.nodes > 0 then
        for i, node in ipairs(route_data.nodes) do
            table.insert(parsed.nodes, {
                index = i,
                position = {x = node.x or 0, z = node.z or 0},
                type = node.type or "unknown",
                speed_limit = node.speed_limit or 90,
                is_intersection = node.is_intersection or false,
                is_toll = node.is_toll or false
            })
        end
    end
    
    -- Расчет дополнительной информации
    parsed.average_speed = parsed.total_distance > 0 and 
                          parsed.total_distance / math.max(parsed.estimated_time, 0.1) or 0
    
    navigation_parser.log_info(string.format("Маршрут распарсен: %s, %.1f км, %.1f ч", 
                                           parsed.destination, parsed.total_distance, parsed.estimated_time), 
                             "navigation")
    
    return parsed
end

-- Получение следующего узла маршрута
function navigation_parser.get_next_node()
    if not navigation_parser.state.route_valid or 
       #navigation_parser.state.route_nodes == 0 then
        return nil
    end
    
    local current_index = navigation_parser.state.current_node_index
    
    if current_index > #navigation_parser.state.route_nodes then
        return nil  -- Маршрут завершен
    end
    
    return navigation_parser.state.route_nodes[current_index]
end

-- Получение расстояния до следующего узла
function navigation_parser.get_distance_to_node(vehicle_position)
    local next_node = navigation_parser.get_next_node()
    
    if not next_node or not vehicle_position then
        return nil
    end
    
    -- Расчет евклидова расстояния
    local dx = next_node.position.x - vehicle_position.x
    local dz = next_node.position.z - vehicle_position.z
    
    return math.sqrt(dx*dx + dz*dz)
end

-- Проверка завершения маршрута
function navigation_parser.is_route_completed()
    if not navigation_parser.state.route_valid then
        return true  -- Если маршрута нет, считаем завершенным
    end
    
    return navigation_parser.state.current_node_index > #navigation_parser.state.route_nodes
end

-- Обновление текущего узла на основе позиции транспортного средства
function navigation_parser.update_current_node(vehicle_position)
    if not navigation_parser.state.route_valid or not vehicle_position then
        return false
    end
    
    local nodes = navigation_parser.state.route_nodes
    local current_index = navigation_parser.state.current_node_index
    
    -- Поиск ближайшего узла впереди по маршруту
    for i = current_index, #nodes do
        local node = nodes[i]
        local distance = navigation_parser.get_distance_to_node(vehicle_position)
        
        if distance and distance < 50.0 then  -- Порог достижения узла (50 метров)
            navigation_parser.state.current_node_index = i + 1
            
            navigation_parser.log_debug(string.format("Достигнут узел %d, следующий: %d", 
                                                    i, navigation_parser.state.current_node_index), 
                                      "navigation")
            return true
        end
    end
    
    return false
end

-- Получение ограничения скорости для текущей позиции
function navigation_parser.get_speed_limit_at_position(position)
    if not position or not navigation_parser.state.route_valid then
        return navigation_parser.config.default_speed_limit or 90.0
    end
    
    local next_node = navigation_parser.get_next_node()
    
    if next_node and next_node.speed_limit then
        return next_node.speed_limit
    end
    
    -- Поиск ближайшего узла для определения ограничения скорости
    local nearest_node = navigation_parser.find_nearest_node(position)
    
    if nearest_node and nearest_node.speed_limit then
        return nearest_node.speed_limit
    end
    
    return navigation_parser.config.default_speed_limit or 90.0
end

-- Поиск ближайшего узла маршрута
function navigation_parser.find_nearest_node(position)
    if not position or not navigation_parser.state.route_valid then
        return nil
    end
    
    local nodes = navigation_parser.state.route_nodes
    local nearest_node = nil
    local min_distance = math.huge
    
    for _, node in ipairs(nodes) do
        local dx = node.position.x - position.x
        local dz = node.position.z - position.z
        local distance = math.sqrt(dx*dx + dz*dz)
        
        if distance < min_distance then
            min_distance = distance
            nearest_node = node
        end
    end
    
    return nearest_node
end

-- Получение направления к следующему узлу
function navigation_parser.get_direction_to_next_node(vehicle_position, vehicle_direction)
    if not vehicle_position or not vehicle_direction then
        return 0
    end
    
    local next_node = navigation_parser.get_next_node()
    
    if not next_node then
        return 0
    end
    
    -- Расчет вектора к цели
    local target_vector = {
        x = next_node.position.x - vehicle_position.x,
        z = next_node.position.z - vehicle_position.z
    }
    
    -- Нормализация векторов
    local target_length = math.sqrt(target_vector.x*target_vector.x + target_vector.z*target_vector.z)
    local vehicle_length = math.sqrt(vehicle_direction.x*vehicle_direction.x + vehicle_direction.z*vehicle_direction.z)
    
    if target_length == 0 or vehicle_length == 0 then
        return 0
    end
    
    target_vector.x = target_vector.x / target_length
    target_vector.z = target_vector.z / target_length
    
    local vehicle_norm = {
        x = vehicle_direction.x / vehicle_length,
        z = vehicle_direction.z / vehicle_length
    }
    
    -- Расчет угла между векторами
    local dot_product = target_vector.x * vehicle_norm.x + target_vector.z * vehicle_norm.z
    local cross_product = target_vector.x * vehicle_norm.z - target_vector.z * vehicle_norm.x
    
    -- Ограничение dot product для избежания ошибок численной точности
    dot_product = math.max(-1.0, math.min(1.0, dot_product))
    
    local angle = math.acos(dot_product)
    
    -- Определение направления поворота
    if cross_product < 0 then
        angle = -angle
    end
    
    return angle
end

-- Обновление парсера
function navigation_parser.update(dt, vehicle_position)
    local current_time = os.clock()
    
    -- Проверка необходимости обновления маршрута
    if current_time - navigation_parser.state.last_update_time > navigation_parser.config.route_update_interval then
        navigation_parser.get_current_route()
        navigation_parser.state.last_update_time = current_time
    end
    
    -- Обновление текущего узла
    if vehicle_position then
        navigation_parser.update_current_node(vehicle_position)
    end
    
    return navigation_parser.state.route_valid
end

-- Функции логгирования
function navigation_parser.log_debug(message, module)
    -- Использование глобальной системы логгирования
    if _G.log_debug then
        _G.log_debug(message, module or "navigation")
    end
end

function navigation_parser.log_info(message, module)
    if _G.log_info then
        _G.log_info(message, module or "navigation")
    end
end

function navigation_parser.log_warning(message, module)
    if _G.log_warning then
        _G.log_warning(message, module or "navigation")
    end
end

function navigation_parser.log_error(message, module)
    if _G.log_error then
        _G.log_error(message, module or "navigation")
    end
end

-- Очистка парсера
function navigation_parser.cleanup()
    navigation_parser.state.current_route = nil
    navigation_parser.state.route_nodes = {}
    navigation_parser.state.route_valid = false
    
    navigation_parser.log_info("Парсер навигации очищен", "navigation")
    return true
end

-- Экспорт модуля
return navigation_parser