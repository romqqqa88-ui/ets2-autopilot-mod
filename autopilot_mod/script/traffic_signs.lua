-- Система реакции на дорожные знаки для автопилота
-- Обнаруживает и интерпретирует дорожные знаки, применяя соответствующие ограничения

local traffic_signs = {
    -- Настройки
    detection_range = 100.0, -- дальность обнаружения знаков (метры)
    update_interval = 0.5, -- интервал обновления (секунды)
    
    -- Обнаруженные знаки
    active_signs = {}, -- знаки, которые сейчас влияют на поведение
    recent_signs = {}, -- недавно обнаруженные знаки (для логирования)
    
    -- Текущие ограничения
    current_speed_limit = nil, -- текущее ограничение скорости (км/ч)
    speed_limit_source = nil, -- источник ограничения скорости
    no_overtaking = false, -- запрет обгона
    no_stopping = false, -- запрет остановки
    special_restrictions = {}, -- специальные ограничения
    
    -- Временные ограничения
    temporary_restrictions = {}, -- временные ограничения (ремонт, события)
    
    -- Статистика
    signs_detected = 0,
    violations_prevented = 0,
    
    -- Кэш
    last_update = 0,
    last_position = nil
}

-- Инициализация системы дорожных знаков
function traffic_signs.init()
    log("Traffic Signs: Инициализация системы дорожных знаков")
    
    -- Загрузка конфигурации
    traffic_signs.load_config()
    
    -- Сброс состояния
    traffic_signs.reset()
    
    return true
end

-- Загрузка конфигурации
function traffic_signs.load_config()
    -- Здесь будет загрузка из конфигурационного файла
    traffic_signs.detection_range = 100.0
    traffic_signs.update_interval = 0.5
end

-- Сброс состояния
function traffic_signs.reset()
    traffic_signs.active_signs = {}
    traffic_signs.recent_signs = {}
    traffic_signs.current_speed_limit = nil
    traffic_signs.speed_limit_source = nil
    traffic_signs.no_overtaking = false
    traffic_signs.no_stopping = false
    traffic_signs.special_restrictions = {}
    traffic_signs.temporary_restrictions = {}
    traffic_signs.signs_detected = 0
    traffic_signs.violations_prevented = 0
end

-- Обновление системы дорожных знаков
function traffic_signs.update(dt, vehicle_position, vehicle_speed)
    traffic_signs.last_update = traffic_signs.last_update + dt
    
    if traffic_signs.last_update < traffic_signs.update_interval then
        return
    end
    
    traffic_signs.last_update = 0
    
    -- Сохранение текущей позиции
    traffic_signs.last_position = vehicle_position
    
    -- Обнаружение знаков в радиусе
    local detected_signs = traffic_signs.detect_signs(vehicle_position)
    
    -- Обработка обнаруженных знаков
    traffic_signs.process_detected_signs(detected_signs, vehicle_position, vehicle_speed)
    
    -- Обновление активных ограничений
    traffic_signs.update_active_restrictions(vehicle_position)
    
    -- Проверка соблюдения ограничений
    traffic_signs.check_compliance(vehicle_speed)
    
    -- Очистка устаревших знаков
    traffic_signs.cleanup_old_signs()
end

-- Обнаружение дорожных знаков
function traffic_signs.detect_signs(position)
    local signs = get_traffic_signs_near_position(position.x, position.z, traffic_signs.detection_range)
    local detected = {}
    
    for _, sign in ipairs(signs) do
        -- Расчет расстояния до знака
        local dx = sign.position.x - position.x
        local dz = sign.position.z - position.z
        local distance = math.sqrt(dx*dx + dz*dz)
        
        -- Расчет угла относительно направления движения
        local angle = math.atan2(dx, dz)
        
        -- Фильтрация знаков (только впереди и по бокам)
        if math.abs(angle) < math.pi * 0.75 then -- 135 градусов
            table.insert(detected, {
                id = sign.id,
                type = sign.type,
                subtype = sign.subtype,
                value = sign.value,
                position = sign.position,
                distance = distance,
                angle = angle,
                first_seen = get_game_time()
            })
        end
    end
    
    return detected
end

-- Обработка обнаруженных знаков
function traffic_signs.process_detected_signs(detected_signs, vehicle_position, vehicle_speed)
    for _, sign in ipairs(detected_signs) do
        -- Проверка, не обрабатывали ли мы уже этот знак
        local already_processed = false
        
        for _, active_sign in ipairs(traffic_signs.active_signs) do
            if active_sign.id == sign.id then
                already_processed = true
                break
            end
        end
        
        if not already_processed then
            -- Обработка нового знака
            traffic_signs.process_sign(sign, vehicle_position, vehicle_speed)
            
            -- Добавление в список недавно обнаруженных
            table.insert(traffic_signs.recent_signs, sign)
            traffic_signs.signs_detected = traffic_signs.signs_detected + 1
            
            -- Ограничение размера списка
            if #traffic_signs.recent_signs > 20 then
                table.remove(traffic_signs.recent_signs, 1)
            end
        end
    end
end

-- Обработка конкретного знака
function traffic_signs.process_sign(sign, vehicle_position, vehicle_speed)
    log("Traffic Signs: Обнаружен знак: " .. sign.type .. " (расстояние: " .. string.format("%.1f", sign.distance) .. " м)")
    
    -- Определение типа знака и применение соответствующих ограничений
    if sign.type == "speed_limit" then
        traffic_signs.process_speed_limit(sign, vehicle_position)
    elseif sign.type == "no_overtaking" then
        traffic_signs.process_no_overtaking(sign, vehicle_position)
    elseif sign.type == "no_stopping" then
        traffic_signs.process_no_stopping(sign, vehicle_position)
    elseif sign.type == "stop" then
        traffic_signs.process_stop_sign(sign, vehicle_position)
    elseif sign.type == "yield" then
        traffic_signs.process_yield_sign(sign, vehicle_position)
    elseif sign.type == "priority_road" then
        traffic_signs.process_priority_road(sign, vehicle_position)
    elseif sign.type == "no_entry" then
        traffic_signs.process_no_entry(sign, vehicle_position)
    elseif sign.type == "one_way" then
        traffic_signs.process_one_way(sign, vehicle_position)
    elseif sign.type == "roundabout" then
        traffic_signs.process_roundabout(sign, vehicle_position)
    else
        -- Обработка других типов знаков
        traffic_signs.process_other_sign(sign, vehicle_position)
    end
    
    -- Добавление знака в активные
    table.insert(traffic_signs.active_signs, sign)
    
    -- Визуальное и звуковое оповещение
    traffic_signs.notify_sign_detection(sign)
end

-- Обработка знака ограничения скорости
function traffic_signs.process_speed_limit(sign, vehicle_position)
    local speed_limit = sign.value or 50 -- значение по умолчанию
    
    -- Проверка, является ли это ограничение более строгим, чем текущее
    if not traffic_signs.current_speed_limit or speed_limit < traffic_signs.current_speed_limit then
        traffic_signs.current_speed_limit = speed_limit
        traffic_signs.speed_limit_source = {
            type = "sign",
            sign_id = sign.id,
            position = sign.position
        }
        
        log("Traffic Signs: Установлено ограничение скорости: " .. speed_limit .. " км/ч")
        show_message("Ограничение скорости: " .. speed_limit .. " км/ч")
    end
end

-- Обработка знака "Обгон запрещен"
function traffic_signs.process_no_overtaking(sign, vehicle_position)
    traffic_signs.no_overtaking = true
    
    -- Отключение системы обгона, если она активна
    local overtaking = require("overtaking")
    if overtaking and overtaking.enabled then
        overtaking.enabled = false
        log("Traffic Signs: Обгон запрещен, система обгона отключена")
        show_message("ВНИМАНИЕ: Обгон запрещен!")
    end
    
    -- Добавление в специальные ограничения
    traffic_signs.special_restrictions.no_overtaking = {
        sign_id = sign.id,
        position = sign.position,
        start_time = get_game_time()
    }
end

-- Обработка знака "Остановка запрещена"
function traffic_signs.process_no_stopping(sign, vehicle_position)
    traffic_signs.no_stopping = true
    
    traffic_signs.special_restrictions.no_stopping = {
        sign_id = sign.id,
        position = sign.position,
        start_time = get_game_time()
    }
    
    log("Traffic Signs: Остановка запрещена")
end

-- Обработка знака "STOP"
function traffic_signs.process_stop_sign(sign, vehicle_position)
    -- Расчет расстояния до знака
    local distance_to_sign = sign.distance
    
    if distance_to_sign < 30.0 then
        -- Необходимо остановиться перед знаком
        traffic_signs.special_restrictions.stop_required = {
            sign_id = sign.id,
            position = sign.position,
            stop_position = {
                x = sign.position.x,
                y = sign.position.y,
                z = sign.position.z - 5.0 -- останавливаемся за 5 метров до знака
            },
            stop_time = get_game_time()
        }
        
        log("Traffic Signs: Требуется остановка перед знаком STOP")
        show_message("STOP: Требуется полная остановка")
    end
end

-- Обработка знака "Уступи дорогу"
function traffic_signs.process_yield_sign(sign, vehicle_position)
    traffic_signs.special_restrictions.yield_required = {
        sign_id = sign.id,
        position = sign.position,
        yield_time = get_game_time()
    }
    
    log("Traffic Signs: Уступи дорогу")
    show_message("Уступи дорогу")
end

-- Обработка знака "Главная дорога"
function traffic_signs.process_priority_road(sign, vehicle_position)
    traffic_signs.special_restrictions.priority_road = {
        sign_id = sign.id,
        position = sign.position,
        priority = true
    }
    
    log("Traffic Signs: Главная дорога")
end

-- Обработка знака "Въезд запрещен"
function traffic_signs.process_no_entry(sign, vehicle_position)
    -- Критическое ограничение - необходимо изменить маршрут
    traffic_signs.special_restrictions.no_entry = {
        sign_id = sign.id,
        position = sign.position,
        critical = true
    }
    
    log("Traffic Signs: ВЪЕЗД ЗАПРЕЩЕН! Требуется изменение маршрута")
    show_message("ВНИМАНИЕ: Въезд запрещен!")
    
    -- Здесь должна быть логика изменения маршрута
end

-- Обработка знака "Одностороннее движение"
function traffic_signs.process_one_way(sign, vehicle_position)
    local direction = sign.value or "forward" -- forward или backward
    
    traffic_signs.special_restrictions.one_way = {
        sign_id = sign.id,
        position = sign.position,
        direction = direction
    }
    
    log("Traffic Signs: Одностороннее движение: " .. direction)
end

-- Обработка знака "Круговое движение"
function traffic_signs.process_roundabout(sign, vehicle_position)
    traffic_signs.special_restrictions.roundabout = {
        sign_id = sign.id,
        position = sign.position,
        roundabout_time = get_game_time()
    }
    
    log("Traffic Signs: Круговое движение")
    show_message("Круговое движение")
end

-- Обработка других типов знаков
function traffic_signs.process_other_sign(sign, vehicle_position)
    -- Общая обработка для других типов знаков
    traffic_signs.special_restrictions[sign.type] = {
        sign_id = sign.id,
        position = sign.position,
        value = sign.value
    }
    
    log("Traffic Signs: Обнаружен знак типа: " .. sign.type)
end

-- Обновление активных ограничений
function traffic_signs.update_active_restrictions(vehicle_position)
    -- Проверка, не уехали ли мы далеко от знаков ограничения скорости
    if traffic_signs.speed_limit_source and traffic_signs.speed_limit_source.type == "sign" then
        local source_pos = traffic_signs.speed_limit_source.position
        local dx = source_pos.x - vehicle_position.x
        local dz = source_pos.z - vehicle_position.z
        local distance = math.sqrt(dx*dx + dz*dz)
        
        -- Если уехали далеко от знака, сбрасываем ограничение
        if distance > 500.0 then -- 500 метров
            traffic_signs.current_speed_limit = nil
            traffic_signs.speed_limit_source = nil
            log("Traffic Signs: Ограничение скорости снято (уехали далеко от знака)")
        end
    end
    
    -- Проверка временных ограничений
    traffic_signs.check_temporary_restrictions(vehicle_position)
end

-- Проверка временных ограничений
function traffic_signs.check_temporary_restrictions(vehicle_position)
    local current_time = get_game_time()
    
    -- Проверка зон ремонта дорог
    local construction_zones = get_construction_zones_near_position(vehicle_position.x, vehicle_position.z, 200.0)
    
    for _, zone in ipairs(construction_zones) do
        if not traffic_signs.temporary_restrictions[zone.id] then
            -- Новое временное ограничение
            traffic_signs.temporary_restrictions[zone.id] = {
                type = "construction",
                speed_limit = zone.speed_limit or 30,
                position = zone.position,
                detected_time = current_time
            }
            
            -- Установка ограничения скорости
            if not traffic_signs.current_speed_limit or zone.speed_limit < traffic_signs.current_speed_limit then
                traffic_signs.current_speed_limit = zone.speed_limit
                traffic_signs.speed_limit_source = {
                    type = "construction",
                    zone_id = zone.id,
                    position = zone.position
                }
                
                log("Traffic Signs: Зона ремонта дороги, ограничение скорости: " .. zone.speed_limit .. " км/ч")
                show_message("Ремонт дороги: " .. zone.speed_limit .. " км/ч")
            end
        end
    end
end

-- Проверка соблюдения ограничений
function traffic_signs.check_compliance(vehicle_speed)
    local speed_kmh = vehicle_speed * 3.6 -- преобразование в км/ч
    
    -- Проверка ограничения скорости
    if traffic_signs.current_speed_limit then
        local tolerance = 5.0 -- допустимое превышение (км/ч)
        
        if speed_kmh > traffic_signs.current_speed_limit + tolerance then
            log("Traffic Signs: Превышение скорости! Текущая: " .. string.format("%.1f", speed_kmh) .. 
                " км/ч, ограничение: " .. traffic_signs.current_speed_limit .. " км/ч")
            
            -- Предупреждение
            if speed_kmh > traffic_signs.current_speed_limit + 10.0 then
                show_message("ПРЕДУПРЕЖДЕНИЕ: Превышение скорости!")
                traffic_signs.violations_prevented = traffic_signs.violations_prevented + 1
            end
        end
    end
    
    -- Проверка других ограничений
    traffic_signs.check_other_compliance()
end

-- Проверка соблюдения других ограничений
function traffic_signs.check_other_compliance()
    -- Проверка запрета обгона
    if traffic_signs.no_overtaking then
        local overtaking = require("overtaking")
        if overtaking and overtaking.is_overtaking then
            log("Traffic Signs: Нарушение! Обгон при запрещающем знаке")
            show_message("НАРУШЕНИЕ: Обгон запрещен!")
            
            -- Прерывание обгона
            overtaking.abort_overtaking("Обгон запрещен дорожным знаком")
        end
    end
    
    -- Проверка требования остановки
    if traffic_signs.special_restrictions.stop_required then
        local stop_info = traffic_signs.special_restrictions.stop_required
        local distance_to_stop = calculate_distance_to_position(stop_info.stop_position)
        
        if distance_to_stop < 10.0 then
            -- Требуется полная остановка
            local current_speed = get_vehicle_speed() or 0
            
            if current_speed > 1.0 then -- больше 1 м/с
                log("Traffic Signs: Требуется остановка перед знаком STOP")
                show_message("STOP: Остановитесь!")
            else
                -- Остановка выполнена
                traffic_signs.special_restrictions.stop_required = nil
                log("Traffic Signs: Остановка перед знаком STOP выполнена")
            end
        end
    end
end

-- Очистка устаревших знаков
function traffic_signs.cleanup_old_signs()
    local current_time = get_game_time()
    local max_age = 300.0 -- 5 минут
    
    -- Очистка активных знаков
    for i = #traffic_signs.active_signs, 1, -1 do
        local sign = traffic_signs.active_signs[i]
        
        if current_time - sign.first_seen > max_age then
            table.remove(traffic_signs.active_signs, i)
        end
    end
    
    -- Очистка специальных ограничений
    for key, restriction in pairs(traffic_signs.special_restrictions) do
        if restriction.start_time and current_time - restriction.start_time > max_age then
            traffic_signs.special_restrictions[key] = nil
            
            -- Сброс запрета обгона
            if key == "no_overtaking" then
                traffic_signs.no_overtaking = false
                log("Traffic Signs: Запрет обгона снят")
            end
        end
    end
end

-- Уведомление об обнаружении знака
function traffic_signs.notify_sign_detection(sign)
    -- Звуковое оповещение для важных знаков
    local important_signs = {
        "speed_limit", "no_overtaking", "stop", "no_entry"
    }
    
    for _, important_type in ipairs(important_signs) do
        if sign.type == important_type then
            play_sound("traffic_sign_" .. sign.type)
            break
        end
    end
    
    -- Визуальное оповещение на HUD
    if sign.type == "speed_limit" then
        show_hud_notification("Ограничение скорости: " .. (sign.value or "?") .. " км/ч", 3.0)
    elseif sign.type == "no_overtaking" then
        show_hud_notification("Обгон запрещен", 3.0)
    elseif sign.type == "stop" then
        show_hud_notification("STOP", 3.0)
    end
end

-- Получение текущего ограничения скорости
function traffic_signs.get_current_speed_limit()
    return traffic_signs.current_speed_limit
end

-- Получение информации о состоянии для отображения
function traffic_signs.get_status_info()
    return {
        current_speed_limit = traffic_signs.current_speed_limit,
        no_overtaking = traffic_signs.no_overtaking,
        no_stopping = traffic_signs.no_stopping,
        active_signs_count = #traffic_signs.active_signs,
        signs_detected = traffic_signs.signs_detected,
        violations_prevented = traffic_signs.violations_prevented
    }
end

-- Визуализация для отладки
function traffic_signs.debug_draw()
    if not traffic_signs.debug_mode then
        return
    end
    
    -- Отрисовка недавно обнаруженных знаков
    for _, sign in ipairs(traffic_signs.recent_signs) do
        local color = {r = 255, g = 255, b = 0} -- желтый
        
        if sign.type == "speed_limit" then
            color = {r = 0, g = 255, b = 0} -- зеленый
        elseif sign.type == "no_overtaking" then
            color = {r = 255, g = 0, b = 0} -- красный
        elseif sign.type == "stop" then
            color = {r = 255, g = 0, b = 0} -- красный
        end
        
        draw_sphere(sign.position, 1.0, color)
        draw_text_3d(sign.position, sign.type .. (sign.value and (" " .. sign.value) or ""), color)
    end
    
    -- Отображение текущего ограничения скорости
    if traffic_signs.current_speed_limit then
        local vehicle_pos = get_vehicle_position()
        if vehicle_pos then
            draw_text_3d(
                {x = vehicle_pos.x, y = vehicle_pos.y + 4, z = vehicle_pos.z},
                "Огр. скорости: " .. traffic_signs.current_speed_limit .. " км/ч",
                {r = 255, g = 255, b = 255}
            )
        end
    end
end

-- Вспомогательные функции
function log(message)
    print("[Traffic Signs] " .. message)
end

function show_message(text)
    print("[Traffic Signs] " .. text)
end

function play_sound(sound_name)
    -- Заглушка для воспроизведения звука
end

function show_hud_notification(text, duration)
    -- Заглушка для отображения уведомления на HUD
    print("[HUD] " .. text)
end

return traffic_signs