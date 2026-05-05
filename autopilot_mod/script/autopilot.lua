-- Autopilot Mod for Euro Truck Simulator 2
-- Основной скрипт управления автопилотом

local autopilot = {
    enabled = false,
    speed_limit = 90.0,
    follow_distance = 50.0,
    aggressiveness = 0.5,
    
    -- Внутренние переменные
    target_speed = 0,
    steering_angle = 0,
    brake_intensity = 0,
    throttle_intensity = 0,
    
    -- Навигационные данные
    current_route = {},
    next_node_index = 1,
    distance_to_node = 0,
    
    -- Состояние игры
    game_speed = 0,
    game_time = 0,
    player_truck = nil
}

-- Инициализация мода
function autopilot.init()
    log("Autopilot Mod: Инициализация...")
    
    -- Регистрация команд консоли
    register_console_command("autopilot_toggle", "Включить/выключить автопилот", autopilot.toggle)
    register_console_command("autopilot_speed", "Установить ограничение скорости", autopilot.set_speed_cmd)
    register_console_command("autopilot_ui", "Показать/скрыть интерфейс", autopilot.toggle_ui)
    
    -- Создание UI
    autopilot.create_ui()
    
    log("Autopilot Mod: Инициализация завершена")
end

-- Создание пользовательского интерфейса
function autopilot.create_ui()
    -- UI создается через файл autopilot.ui
    -- Эта функция может добавлять динамические элементы
end

-- Включение/выключение автопилота
function autopilot.toggle()
    autopilot.enabled = not autopilot.enabled
    
    if autopilot.enabled then
        log("Autopilot: Включен")
        autopilot.on_enable()
    else
        log("Autopilot: Выключен")
        autopilot.on_disable()
    end
    
    -- Обновление UI
    autopilot.update_ui()
end

-- Включение автопилота
function autopilot.on_enable()
    -- Получение текущего маршрута из навигатора
    autopilot.get_current_route()
    
    -- Сброс управления
    autopilot.target_speed = autopilot.speed_limit
    autopilot.steering_angle = 0
    autopilot.brake_intensity = 0
    autopilot.throttle_intensity = 0
    
    -- Запуск основного цикла
    autopilot.start_update_loop()
end

-- Выключение автопилота
function autopilot.on_disable()
    -- Остановка цикла обновления
    autopilot.stop_update_loop()
    
    -- Сброс управления
    set_throttle(0)
    set_brake(0)
    set_steering(0)
end

-- Получение текущего маршрута из навигатора
function autopilot.get_current_route()
    autopilot.current_route = {}
    autopilot.next_node_index = 1
    
    -- Используем API навигатора для получения точек маршрута
    local route = get_navigation_route()
    
    if route and #route > 0 then
        for i, node in ipairs(route) do
            table.insert(autopilot.current_route, {
                x = node.x,
                y = node.y,
                z = node.z,
                speed_limit = node.speed_limit or autopilot.speed_limit
            })
        end
        log("Autopilot: Маршрут загружен, точек: " .. #autopilot.current_route)
    else
        log("Autopilot: Маршрут не найден. Установите точку назначения в навигаторе.")
        autopilot.enabled = false
    end
end

-- Основной цикл обновления
function autopilot.update(dt)
    if not autopilot.enabled then
        return
    end
    
    -- Получение данных о грузовике
    local truck = get_player_truck()
    if not truck then
        return
    end
    
    -- Получение позиции и направления
    local pos = truck.position
    local dir = truck.direction
    local speed = truck.speed * 3.6 -- преобразование в км/ч
    
    -- Поиск следующей точки маршрута
    local next_node = autopilot.current_route[autopilot.next_node_index]
    if not next_node then
        -- Маршрут завершен
        autopilot.on_route_complete()
        return
    end
    
    -- Расчет расстояния до следующей точки
    local dx = next_node.x - pos.x
    local dz = next_node.z - pos.z
    local distance = math.sqrt(dx*dx + dz*dz)
    
    -- Если близко к точке, переходим к следующей
    if distance < 10.0 then
        autopilot.next_node_index = autopilot.next_node_index + 1
        log("Autopilot: Достигнута точка " .. (autopilot.next_node_index - 1))
        return
    end
    
    -- Расчет угла к точке
    local target_angle = math.atan2(dx, dz)
    local current_angle = math.atan2(dir.x, dir.z)
    local angle_diff = target_angle - current_angle
    
    -- Нормализация угла
    while angle_diff > math.pi do angle_diff = angle_diff - 2*math.pi end
    while angle_diff < -math.pi do angle_diff = angle_diff + 2*math.pi end
    
    -- Управление рулевым колесом
    autopilot.steering_angle = angle_diff * autopilot.aggressiveness
    autopilot.steering_angle = math.max(-1.0, math.min(1.0, autopilot.steering_angle))
    
    -- Управление скоростью
    local target_speed = math.min(autopilot.speed_limit, next_node.speed_limit or autopilot.speed_limit)
    autopilot.target_speed = target_speed
    
    if speed < target_speed - 5 then
        -- Ускориться
        autopilot.throttle_intensity = 0.8
        autopilot.brake_intensity = 0.0
    elseif speed > target_speed + 5 then
        -- Замедлиться
        autopilot.throttle_intensity = 0.0
        autopilot.brake_intensity = 0.3
    else
        -- Поддерживать скорость
        autopilot.throttle_intensity = 0.2
        autopilot.brake_intensity = 0.0
    end
    
    -- Применение управления
    set_steering(autopilot.steering_angle)
    set_throttle(autopilot.throttle_intensity)
    set_brake(autopilot.brake_intensity)
    
    -- Обновление UI
    autopilot.update_ui_values(speed, distance, autopilot.next_node_index, #autopilot.current_route)
end

-- Завершение маршрута
function autopilot.on_route_complete()
    log("Autopilot: Маршрут завершен!")
    autopilot.enabled = false
    
    -- Плавная остановка
    set_throttle(0)
    set_brake(0.5)
    set_steering(0)
    
    -- Уведомление
    show_message("Автопилот: Маршрут завершен")
end

-- Запуск цикла обновления
function autopilot.start_update_loop()
    -- Регистрация callback для обновления каждый кадр
    register_update("autopilot_update", autopilot.update)
end

-- Остановка цикла обновления
function autopilot.stop_update_loop()
    unregister_update("autopilot_update")
end

-- UI функции
function autopilot.update_ui()
    -- Обновление состояния UI
    if autopilot.ui_visible then
        -- Код обновления UI элементов
    end
end

function autopilot.update_ui_values(speed, distance, current_node, total_nodes)
    -- Обновление значений в UI
end

function autopilot.toggle_ui()
    autopilot.ui_visible = not autopilot.ui_visible
end

-- Командные функции
function autopilot.set_speed_cmd(speed_str)
    local speed = tonumber(speed_str)
    if speed and speed >= 30 and speed <= 130 then
        autopilot.speed_limit = speed
        log("Autopilot: Ограничение скорости установлено на " .. speed .. " км/ч")
    else
        log("Autopilot: Некорректное значение скорости. Используйте от 30 до 130 км/ч")
    end
end

-- Вспомогательные функции
function log(message)
    print("[Autopilot] " .. message)
end

function show_message(text)
    -- Показать сообщение на экране
    print("[Autopilot MSG] " .. text)
end

-- Инициализация при загрузке игры
function on_game_load()
    autopilot.init()
end

-- Обработка событий
function on_key_press(key)
    if key == "F5" then
        -- Горячая клавиша для включения/выключения автопилота
        autopilot.toggle()
    elseif key == "F6" then
        -- Горячая клавиша для показа UI
        autopilot.toggle_ui()
    end
end

-- Экспорт функций для использования в других скриптах
return autopilot