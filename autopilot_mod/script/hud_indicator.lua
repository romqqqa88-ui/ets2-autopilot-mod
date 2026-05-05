-- Визуальная индикация автопилота на HUD
-- Отображает статус, информацию и предупреждения на экране игры

local hud_indicator = {
    -- Настройки
    enabled = true, -- включена ли индикация
    position = {x = 20, y = 100}, -- позиция основного блока
    scale = 1.0, -- масштаб интерфейса
    opacity = 0.9, -- прозрачность
    
    -- Элементы HUD
    elements = {},
    
    -- Состояние автопилота
    autopilot_active = false,
    current_speed = 0,
    target_speed = 0,
    speed_limit = 0,
    follow_distance = 0,
    current_lane = 1,
    total_lanes = 2,
    
    -- Предупреждения
    warnings = {},
    notifications = {},
    
    -- Тайминги
    last_update = 0,
    update_interval = 0.1, -- секунд
    
    -- Анимации
    animations = {},
    
    -- Мини-карта
    minimap_enabled = true,
    minimap_lane_highlight = true
}

-- Инициализация HUD индикатора
function hud_indicator.init()
    log("HUD Indicator: Инициализация визуальной индикации")
    
    -- Загрузка конфигурации
    hud_indicator.load_config()
    
    -- Создание элементов HUD
    hud_indicator.create_elements()
    
    -- Сброс состояния
    hud_indicator.reset()
    
    return true
end

-- Загрузка конфигурации
function hud_indicator.load_config()
    -- Здесь будет загрузка из конфигурационного файла
    hud_indicator.enabled = true
    hud_indicator.position = {x = 20, y = 100}
    hud_indicator.scale = 1.0
    hud_indicator.opacity = 0.9
    hud_indicator.minimap_enabled = true
    hud_indicator.minimap_lane_highlight = true
end

-- Сброс состояния
function hud_indicator.reset()
    hud_indicator.autopilot_active = false
    hud_indicator.current_speed = 0
    hud_indicator.target_speed = 0
    hud_indicator.speed_limit = 0
    hud_indicator.follow_distance = 0
    hud_indicator.current_lane = 1
    hud_indicator.total_lanes = 2
    hud_indicator.warnings = {}
    hud_indicator.notifications = {}
    hud_indicator.animations = {}
end

-- Создание элементов HUD
function hud_indicator.create_elements()
    hud_indicator.elements = {
        main_panel = {
            type = "panel",
            position = hud_indicator.position,
            size = {width = 300, height = 180},
            visible = true,
            children = {}
        },
        
        status_indicator = {
            type = "status",
            position = {x = 10, y = 10},
            size = {width = 280, height = 40},
            visible = true
        },
        
        speed_display = {
            type = "speed",
            position = {x = 10, y = 60},
            size = {width = 140, height = 50},
            visible = true
        },
        
        lane_display = {
            type = "lane",
            position = {x = 160, y = 60},
            size = {width = 130, height = 50},
            visible = true
        },
        
        warning_panel = {
            type = "warnings",
            position = {x = 10, y = 120},
            size = {width = 280, height = 50},
            visible = true
        },
        
        notification_area = {
            type = "notifications",
            position = {x = hud_indicator.position.x, y = hud_indicator.position.y + 190},
            size = {width = 300, height = 100},
            visible = true
        }
    }
    
    log("HUD Indicator: Создано " .. #hud_indicator.elements .. " элементов HUD")
end

-- Обновление HUD индикатора
function hud_indicator.update(dt, autopilot_data, vehicle_data, navigation_data)
    hud_indicator.last_update = hud_indicator.last_update + dt
    
    if hud_indicator.last_update < hud_indicator.update_interval then
        return
    end
    
    hud_indicator.last_update = 0
    
    if not hud_indicator.enabled then
        return
    end
    
    -- Обновление данных
    hud_indicator.update_data(autopilot_data, vehicle_data, navigation_data)
    
    -- Обновление анимаций
    hud_indicator.update_animations(dt)
    
    -- Проверка предупреждений
    hud_indicator.check_warnings(autopilot_data, vehicle_data)
    
    -- Отрисовка HUD
    hud_indicator.draw()
end

-- Обновление данных
function hud_indicator.update_data(autopilot_data, vehicle_data, navigation_data)
    if autopilot_data then
        hud_indicator.autopilot_active = autopilot_data.enabled or false
        hud_indicator.target_speed = autopilot_data.target_speed or 0
        hud_indicator.follow_distance = autopilot_data.follow_distance or 0
    end
    
    if vehicle_data then
        hud_indicator.current_speed = vehicle_data.speed * 3.6 or 0 -- преобразование в км/ч
    end
    
    if navigation_data then
        hud_indicator.speed_limit = navigation_data.speed_limit or 0
    end
    
    -- Получение информации о полосах
    local lane_keeping = require("lane_keeping")
    if lane_keeping then
        local lane_info = lane_keeping.get_status_info()
        if lane_info then
            hud_indicator.current_lane = lane_info.current_lane or 1
            hud_indicator.total_lanes = lane_info.total_lanes or 2
        end
    end
end

-- Обновление анимаций
function hud_indicator.update_animations(dt)
    for i = #hud_indicator.animations, 1, -1 do
        local animation = hud_indicator.animations[i]
        animation.progress = animation.progress + dt / animation.duration
        
        if animation.progress >= 1.0 then
            table.remove(hud_indicator.animations, i)
        end
    end
end

-- Проверка предупреждений
function hud_indicator.check_warnings(autopilot_data, vehicle_data)
    -- Очистка старых предупреждений
    for i = #hud_indicator.warnings, 1, -1 do
        local warning = hud_indicator.warnings[i]
        if get_game_time() - warning.time > warning.duration then
            table.remove(hud_indicator.warnings, i)
        end
    end
    
    -- Проверка превышения скорости
    if hud_indicator.speed_limit > 0 then
        local speed_excess = hud_indicator.current_speed - hud_indicator.speed_limit
        if speed_excess > 10.0 then -- более 10 км/ч превышения
            hud_indicator.add_warning("Превышение скорости!", "speed", 2.0)
        end
    end
    
    -- Проверка препятствий
    local obstacle_detector = require("obstacle_detector")
    if obstacle_detector then
        local emergency, obstacle = obstacle_detector.needs_emergency_brake()
        if emergency then
            hud_indicator.add_warning("ОПАСНОСТЬ ВПЕРЕДИ!", "obstacle", 1.0)
        end
    end
    
    -- Проверка дорожных знаков
    local traffic_signs = require("traffic_signs")
    if traffic_signs then
        local signs_info = traffic_signs.get_status_info()
        if signs_info and signs_info.no_overtaking then
            hud_indicator.add_warning("Обгон запрещен", "sign", 3.0)
        end
    end
end

-- Добавление предупреждения
function hud_indicator.add_warning(text, type, duration)
    -- Проверка, нет ли уже такого предупреждения
    for _, warning in ipairs(hud_indicator.warnings) do
        if warning.text == text then
            warning.time = get_game_time() -- обновляем время
            return
        end
    end
    
    local warning = {
        text = text,
        type = type,
        time = get_game_time(),
        duration = duration or 3.0,
        animation = "fade_in"
    }
    
    table.insert(hud_indicator.warnings, warning)
    
    -- Анимация
    hud_indicator.add_animation({
        type = "warning_pulse",
        element = "warning_panel",
        duration = 0.5,
        progress = 0
    })
    
    log("HUD Indicator: Добавлено предупреждение: " .. text)
end

-- Добавление уведомления
function hud_indicator.add_notification(text, type, duration)
    local notification = {
        text = text,
        type = type or "info",
        time = get_game_time(),
        duration = duration or 5.0
    }
    
    table.insert(hud_indicator.notifications, notification)
    
    -- Ограничение количества уведомлений
    if #hud_indicator.notifications > 5 then
        table.remove(hud_indicator.notifications, 1)
    end
    
    -- Анимация
    hud_indicator.add_animation({
        type = "notification_slide",
        element = "notification_area",
        duration = 0.3,
        progress = 0
    })
end

-- Добавление анимации
function hud_indicator.add_animation(animation)
    table.insert(hud_indicator.animations, animation)
end

-- Отрисовка HUD
function hud_indicator.draw()
    if not hud_indicator.enabled then
        return
    end
    
    -- Основная панель
    hud_indicator.draw_main_panel()
    
    -- Индикатор статуса
    hud_indicator.draw_status_indicator()
    
    -- Отображение скорости
    hud_indicator.draw_speed_display()
    
    -- Отображение информации о полосе
    hud_indicator.draw_lane_display()
    
    -- Панель предупреждений
    hud_indicator.draw_warning_panel()
    
    -- Область уведомлений
    hud_indicator.draw_notification_area()
    
    -- Мини-карта (если включена)
    if hud_indicator.minimap_enabled then
        hud_indicator.draw_minimap_overlay()
    end
end

-- Отрисовка основной панели
function hud_indicator.draw_main_panel()
    local panel = hud_indicator.elements.main_panel
    local pos = panel.position
    local size = panel.size
    
    -- Фон панели
    draw_rect(pos.x, pos.y, size.width, size.height, 0x000000, hud_indicator.opacity * 0.7)
    
    -- Рамка
    draw_rect_outline(pos.x, pos.y, size.width, size.height, 2, 0x444488, hud_indicator.opacity)
    
    -- Заголовок
    draw_text(pos.x + 10, pos.y + 5, "АВТОПИЛОТ ETS 2", 0xFFFFFF, hud_indicator.opacity, "medium")
end

-- Отрисовка индикатора статуса
function hud_indicator.draw_status_indicator()
    local element = hud_indicator.elements.status_indicator
    local pos = {x = hud_indicator.position.x + element.position.x, 
                 y = hud_indicator.position.y + element.position.y}
    local size = element.size
    
    -- Фон
    local bg_color = hud_indicator.autopilot_active and 0x004400 or 0x440000
    draw_rect(pos.x, pos.y, size.width, size.height, bg_color, hud_indicator.opacity * 0.8)
    
    -- Текст статуса
    local status_text = hud_indicator.autopilot_active and "АКТИВЕН" or "ВЫКЛЮЧЕН"
    local status_color = hud_indicator.autopilot_active and 0x44FF44 or 0xFF4444
    
    draw_text(pos.x + size.width/2, pos.y + size.height/2 - 10, 
              "СТАТУС: " .. status_text, status_color, hud_indicator.opacity, "large", "center")
    
    -- Дополнительная информация
    if hud_indicator.autopilot_active then
        local mode_text = "РЕЖИМ: СЛЕДОВАНИЕ"
        draw_text(pos.x + size.width/2, pos.y + size.height/2 + 10, 
                  mode_text, 0xFFFFFF, hud_indicator.opacity * 0.9, "small", "center")
    end
end

-- Отрисовка отображения скорости
function hud_indicator.draw_speed_display()
    local element = hud_indicator.elements.speed_display
    local pos = {x = hud_indicator.position.x + element.position.x, 
                 y = hud_indicator.position.y + element.position.y}
    local size = element.size
    
    -- Фон
    draw_rect(pos.x, pos.y, size.width, size.height, 0x222222, hud_indicator.opacity * 0.8)
    
    -- Текущая скорость
    local speed_color = 0xFFFFFF
    if hud_indicator.speed_limit > 0 then
        local speed_ratio = hud_indicator.current_speed / hud_indicator.speed_limit
        if speed_ratio > 1.1 then
            speed_color = 0xFF4444 -- красный при превышении
        elseif speed_ratio > 1.0 then
            speed_color = 0xFFFF44 -- желтый при небольшом превышении
        else
            speed_color = 0x44FF44 -- зеленый в пределах
        end
    end
    
    draw_text(pos.x + 10, pos.y + 10, "СКОРОСТЬ", 0xAAAAAA, hud_indicator.opacity, "small")
    draw_text(pos.x + size.width/2, pos.y + 30, 
              string.format("%.0f", hud_indicator.current_speed), 
              speed_color, hud_indicator.opacity, "large", "center")
    
    -- Ограничение скорости
    if hud_indicator.speed_limit > 0 then
        draw_text(pos.x + size.width - 10, pos.y + 10, 
                  string.format("%.0f", hud_indicator.speed_limit), 
                  0x44AAFF, hud_indicator.opacity, "small", "right")
    end
end

-- Отрисовка отображения информации о полосе
function hud_indicator.draw_lane_display()
    local element = hud_indicator.elements.lane_display
    local pos = {x = hud_indicator.position.x + element.position.x, 
                 y = hud_indicator.position.y + element.position.y}
    local size = element.size
    
    -- Фон
    draw_rect(pos.x, pos.y, size.width, size.height, 0x222222, hud_indicator.opacity * 0.8)
    
    -- Информация о полосе
    draw_text(pos.x + 10, pos.y + 10, "ПОЛОСА", 0xAAAAAA, hud_indicator.opacity, "small")
    
    -- Визуализация полос
    local lane_width = 20
    local lane_spacing = 5
    local total_width = hud_indicator.total_lanes * lane_width + (hud_indicator.total_lanes - 1) * lane_spacing
    local start_x = pos.x + (size.width - total_width) / 2
    
    for i = 1, hud_indicator.total_lanes do
        local lane_x = start_x + (i - 1) * (lane_width + lane_spacing)
        local lane_color = (i == hud_indicator.current_lane) and 0x44FF44 or 0x666666
        
        draw_rect(lane_x, pos.y + 35, lane_width, 10, lane_color, hud_indicator.opacity)
        
        -- Номер полосы
        draw_text(lane_x + lane_width/2, pos.y + 50, tostring(i), 
                  (i == hud_indicator.current_lane) and 0xFFFFFF or 0x888888, 
                  hud_indicator.opacity, "small", "center")
    end
end

-- Отрисовка панели предупреждений
function hud_indicator.draw_warning_panel()
    local element = hud_indicator.elements.warning_panel
    local pos = {x = hud_indicator.position.x + element.position.x, 
                 y = hud_indicator.position.y + element.position.y}
    local size = element.size
    
    -- Фон
    local has_warnings = #hud_indicator.warnings > 0
    local bg_color = has_warnings and 0x442200 or 0x222222
    draw_rect(pos.x, pos.y, size.width, size.height, bg_color, hud_indicator.opacity * 0.8)
    
    -- Заголовок
    draw_text(pos.x + 10, pos.y + 5, "ПРЕДУПРЕЖДЕНИЯ", 0xAAAAAA, hud_indicator.opacity, "small")
    
    -- Отображение предупреждений
    if has_warnings then
        local warning = hud_indicator.warnings[#hud_indicator.warnings] -- самое свежее
        local warning_color = 0xFF4444
        
        -- Мигание для важных предупреждений
        local blink = math.floor(get_game_time() * 2) % 2 == 0
        if warning.type == "obstacle" and blink then
            warning_color = 0xFF8844
        end
        
        draw_text(pos.x + size.width/2, pos.y + size.height/2, 
                  warning.text, warning_color, hud_indicator.opacity, "medium", "center")
    else
        draw_text(pos.x + size.width/2, pos.y + size.height/2, 
                  "Нет предупреждений", 0x44FF44, hud_indicator.opacity * 0.7, "small", "center")
    end
end

-- Отрисовка области уведомлений
function hud_indicator.draw_notification_area()
    local element = hud_indicator.elements.notification_area
    local pos = element.position
    local size = element.size
    
    -- Отображение уведомлений
    for i, notification in ipairs(hud_indicator.notifications) do
        local y_offset = (i - 1) * 25
        local age = get_game_time() - notification.time
        local alpha = hud_indicator.opacity * (1.0 - age / notification.duration)
        
        if alpha > 0 then
            local bg_color = 0x000000
            local text_color = 0xFFFFFF
            
            if notification.type == "success" then
                bg_color = 0x004400
                text_color = 0x44FF44
            elseif notification.type == "warning" then
                bg_color = 0x442200
                text_color = 0xFFAA44
            elseif notification.type == "error" then
                bg_color = 0x440000
                text_color = 0xFF4444
            end
            
            draw_rect(pos.x, pos.y + y_offset, size.width, 22, bg_color, alpha * 0.7)
            draw_text(pos.x + 10, pos.y + y_offset + 5, notification.text, text_color, alpha, "small")
        end
    end
end

-- Отрисовка оверлея на мини-карте
function hud_indicator.draw_minimap_overlay()
    if not hud_indicator.minimap_lane_highlight then
        return
    end
    
    -- Получение позиции и размеров мини-карты
    local minimap_pos = get_minimap_position()
    local minimap_size = get_minimap_size()
    
    if not minimap_pos or not minimap_size then
        return
    end
    
    -- Визуализация текущей полосы на мини-карте
    if hud_indicator.autopilot_active then
        -- Расчет позиции полосы на мини-карте
        local lane_width = minimap_size.width / hud_indicator.total_lanes
        local lane_x = minimap_pos.x + (hud_indicator.current_lane - 1) * lane_width
        
        -- Подсветка текущей полосы
        draw_rect(lane_x, minimap_pos.y, lane_width, minimap_size.height, 
                  0x44FF44, hud_indicator.opacity * 0.3)
        
        -- Контур полосы
        draw_rect_outline(lane_x, minimap_pos.y, lane_width, minimap_size.height, 
                          2, 0x44FF44, hud_indicator.opacity * 0.7)
    end
end

-- Включение/выключение HUD
function hud_indicator.toggle()
    hud_indicator.enabled = not hud_indicator.enabled
    
    if hud_indicator.enabled then
        log("HUD Indicator: Визуальная индикация включена")
        hud_indicator.add_notification("HUD автопилота включен", "info", 3.0)
    else
        log("HUD Indicator: Визуальная индикация выключена")
    end
    
    return hud_indicator.enabled
end

-- Изменение позиции HUD
function hud_indicator.set_position(x, y)
    hud_indicator.position = {x = x, y = y}
    
    -- Обновление позиций элементов
    hud_indicator.create_elements()
    
    log("HUD Indicator: Позиция изменена на (" .. x .. ", " .. y .. ")")
end

-- Получение информации о состоянии для отображения
function hud_indicator.get_status_info()
    return {
        enabled = hud_indicator.enabled,
        autopilot_active = hud_indicator.autopilot_active,
        current_speed = hud_indicator.current_speed,
        speed_limit = hud_indicator.speed_limit,
        current_lane = hud_indicator.current_lane,
        total_lanes = hud_indicator.total_lanes,
        warnings_count = #hud_indicator.warnings,
        notifications_count = #hud_indicator.notifications
    }
end

-- Вспомогательные функции
function log(message)
    print("[HUD Indicator] " .. message)
end

return hud_indicator