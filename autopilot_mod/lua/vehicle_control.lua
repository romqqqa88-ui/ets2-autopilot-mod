-- Модуль управления транспортным средством для автопилота ETS 2
-- Обеспечивает плавное управление рулевым колесом, скоростью и другими системами

local vehicle_control = {
    -- Конфигурация
    config = {
        -- Настройки управления рулевым колесом
        steering_sensitivity = 0.8,      -- чувствительность рулевого управления (0.1-1.0)
        steering_smoothing = 0.3,        -- сглаживание рулевого управления
        max_steering_angle = 0.8,        -- максимальный угол поворота руля
        steering_deadzone = 0.05,        -- мертвая зона рулевого управления
        
        -- Настройки управления скоростью
        speed_control_p = 0.5,           -- пропорциональный коэффициент ПИД-регулятора
        speed_control_i = 0.1,           -- интегральный коэффициент
        speed_control_d = 0.2,           -- дифференциальный коэффициент
        speed_tolerance = 2.0,           -- допуск по скорости (км/ч)
        max_acceleration = 0.8,          -- максимальное ускорение (0-1)
        max_braking = 1.0,               -- максимальное торможение (0-1)
        
        -- Настройки трансмиссии
        automatic_gearshift = true,      -- автоматическое переключение передач
        eco_mode = true,                 -- экономичный режим вождения
        engine_braking = true,           -- использование торможения двигателем
        
        -- Настройки безопасности
        collision_avoidance = true,      -- система избегания столкновений
        stability_control = true,        -- система контроля устойчивости
        traction_control = true,         -- система контроля тяги
        abs_enabled = true,              -- ABS
        
        -- Настройки адаптации
        adaptive_control = true,         -- адаптивное управление
        learning_enabled = true,         -- обучение стилю вождения
        weather_adaptation = true        -- адаптация к погодным условиям
    },
    
    -- Состояние
    state = {
        -- Управление рулевым колесом
        current_steering = 0.0,
        target_steering = 0.0,
        steering_history = {},
        
        -- Управление скоростью
        current_throttle = 0.0,
        current_brake = 0.0,
        target_speed = 0.0,
        speed_error_integral = 0.0,
        last_speed_error = 0.0,
        
        -- Управление трансмиссией
        current_gear = 1,
        target_gear = 1,
        rpm = 0.0,
        engine_load = 0.0,
        
        -- Состояние безопасности
        collision_risk = 0.0,
        stability_risk = 0.0,
        traction_risk = 0.0,
        
        -- Статистика
        total_distance = 0.0,
        total_fuel_used = 0.0,
        average_speed = 0.0,
        driving_time = 0.0,
        
        -- Флаги
        initialized = false,
        active = false,
        emergency_brake = false
    },
    
    -- Кэш
    cache = {
        vehicle_data = nil,
        last_update_time = 0,
        update_interval = 0.05  -- секунды
    }
}

-- Инициализация системы управления
function vehicle_control.init(config_overrides)
    -- Применение переопределений конфигурации
    if config_overrides then
        for key, value in pairs(config_overrides) do
            vehicle_control.config[key] = value
        end
    end
    
    -- Инициализация истории рулевого управления
    vehicle_control.state.steering_history = {}
    
    -- Сброс состояния
    vehicle_control.reset_state()
    
    vehicle_control.state.initialized = true
    vehicle_control.state.active = true
    
    vehicle_control.log_info("Система управления транспортным средством инициализирована", "vehicle")
    
    return true
end

-- Сброс состояния управления
function vehicle_control.reset_state()
    vehicle_control.state.current_steering = 0.0
    vehicle_control.state.target_steering = 0.0
    vehicle_control.state.current_throttle = 0.0
    vehicle_control.state.current_brake = 0.0
    vehicle_control.state.target_speed = 0.0
    vehicle_control.state.speed_error_integral = 0.0
    vehicle_control.state.last_speed_error = 0.0
    vehicle_control.state.emergency_brake = false
    
    vehicle_control.log_debug("Состояние управления сброшено", "vehicle")
end

-- Установка целевого угла рулевого колеса
function vehicle_control.set_steering(target_angle, immediate)
    if not vehicle_control.state.active then
        return false
    end
    
    -- Ограничение угла поворота
    target_angle = math.max(-vehicle_control.config.max_steering_angle, 
                           math.min(vehicle_control.config.max_steering_angle, target_angle))
    
    -- Применение мертвой зоны
    if math.abs(target_angle) < vehicle_control.config.steering_deadzone then
        target_angle = 0.0
    end
    
    vehicle_control.state.target_steering = target_angle
    
    -- Немедленное применение
    if immediate then
        vehicle_control.state.current_steering = target_angle
        vehicle_control.apply_steering()
    end
    
    return true
end

-- Применение рулевого управления
function vehicle_control.apply_steering()
    if not vehicle_control.state.active then
        return false
    end
    
    -- Плавное изменение угла рулевого колеса
    local smoothing = vehicle_control.config.steering_smoothing
    local current = vehicle_control.state.current_steering
    local target = vehicle_control.state.target_steering
    
    local new_steering = current + (target - current) * smoothing
    
    -- Ограничение скорости изменения
    local max_change = 0.1  -- максимальное изменение за кадр
    local change = new_steering - current
    
    if math.abs(change) > max_change then
        new_steering = current + math.sign(change) * max_change
    end
    
    vehicle_control.state.current_steering = new_steering
    
    -- Сохранение в истории для анализа
    table.insert(vehicle_control.state.steering_history, new_steering)
    
    -- Ограничение размера истории
    if #vehicle_control.state.steering_history > 100 then
        table.remove(vehicle_control.state.steering_history, 1)
    end
    
    -- Применение рулевого управления через API игры
    -- set_vehicle_steering(new_steering)
    
    return true
end

-- Установка целевой скорости
function vehicle_control.set_target_speed(speed_kmh)
    if not vehicle_control.state.active then
        return false
    end
    
    vehicle_control.state.target_speed = math.max(0.0, speed_kmh)
    
    vehicle_control.log_debug(string.format("Установлена целевая скорость: %.1f км/ч", speed_kmh), "vehicle")
    
    return true
end

-- Управление скоростью с помощью ПИД-регулятора
function vehicle_control.control_speed(current_speed_kmh, dt)
    if not vehicle_control.state.active or dt <= 0 then
        return 0.0, 0.0
    end
    
    local target_speed = vehicle_control.state.target_speed
    
    -- Расчет ошибки скорости
    local speed_error = target_speed - current_speed_kmh
    
    -- Пропорциональная составляющая
    local p_term = vehicle_control.config.speed_control_p * speed_error
    
    -- Интегральная составляющая (с антивиндовпом)
    vehicle_control.state.speed_error_integral = vehicle_control.state.speed_error_integral + speed_error * dt
    
    -- Ограничение интегральной составляющей
    local max_integral = 50.0  -- максимальное значение интеграла
    vehicle_control.state.speed_error_integral = math.max(-max_integral, 
                                                         math.min(max_integral, 
                                                                 vehicle_control.state.speed_error_integral))
    
    local i_term = vehicle_control.config.speed_control_i * vehicle_control.state.speed_error_integral
    
    -- Дифференциальная составляющая
    local speed_error_derivative = (speed_error - vehicle_control.state.last_speed_error) / dt
    vehicle_control.state.last_speed_error = speed_error
    
    local d_term = vehicle_control.config.speed_control_d * speed_error_derivative
    
    -- Суммарное управляющее воздействие
    local control_output = p_term + i_term + d_term
    
    -- Преобразование в управление дросселем/тормозом
    local throttle = 0.0
    local brake = 0.0
    
    if control_output > 0 then
        -- Ускорение
        throttle = math.min(control_output / 100.0, vehicle_control.config.max_acceleration)
        brake = 0.0
    else
        -- Торможение
        throttle = 0.0
        brake = math.min(-control_output / 100.0, vehicle_control.config.max_braking)
    end
    
    -- Применение мертвой зоны
    if math.abs(speed_error) < vehicle_control.config.speed_tolerance then
        throttle = 0.1  -- минимальный газ для поддержания скорости
        brake = 0.0
    end
    
    -- Экстренное торможение
    if vehicle_control.state.emergency_brake then
        throttle = 0.0
        brake = vehicle_control.config.max_braking
    end
    
    -- Ограничение значений
    throttle = math.max(0.0, math.min(1.0, throttle))
    brake = math.max(0.0, math.min(1.0, brake))
    
    vehicle_control.state.current_throttle = throttle
    vehicle_control.state.current_brake = brake
    
    return throttle, brake
end

-- Применение управления скоростью
function vehicle_control.apply_speed_control(throttle, brake)
    if not vehicle_control.state.active then
        return false
    end
    
    -- Применение через API игры
    -- set_vehicle_throttle(throttle)
    -- set_vehicle_brake(brake)
    
    -- Логирование при значительных изменениях
    if math.abs(throttle - vehicle_control.state.current_throttle) > 0.1 or
       math.abs(brake - vehicle_control.state.current_brake) > 0.1 then
        vehicle_control.log_debug(string.format("Управление скоростью: газ=%.2f, тормоз=%.2f", 
                                              throttle, brake), "vehicle")
    end
    
    vehicle_control.state.current_throttle = throttle
    vehicle_control.state.current_brake = brake
    
    return true
end

-- Управление передачами
function vehicle_control.control_gearshift(current_rpm, current_speed_kmh)
    if not vehicle_control.state.active or not vehicle_control.config.automatic_gearshift then
        return vehicle_control.state.current_gear
    end
    
    local new_gear = vehicle_control.state.current_gear
    
    -- Логика переключения передач
    if current_rpm > 2500 then
        -- Повышение передачи
        new_gear = math.min(new_gear + 1, 12)  -- Максимум 12 передач
    elseif current_rpm < 1500 and current_speed_kmh > 20 then
        -- Понижение передачи
        new_gear = math.max(new_gear - 1, 1)  -- Минимум 1 передача
    end
    
    -- Экономичный режим (раннее переключение)
    if vehicle_control.config.eco_mode and current_rpm > 2000 then
        new_gear = math.min(new_gear + 1, 12)
    end
    
    -- Применение переключения передачи
    if new_gear ~= vehicle_control.state.current_gear then
        vehicle_control.state.current_gear = new_gear
        -- set_vehicle_gear(new_gear)
        
        vehicle_control.log_debug(string.format("Переключение передачи: %d -> %d (RPM: %.0f)", 
                                              vehicle_control.state.current_gear, new_gear, current_rpm), 
                                "vehicle")
    end
    
    return new_gear
end

-- Проверка риска столкновения
function vehicle_control.check_collision_risk(obstacle_data, vehicle_data)
    if not vehicle_control.config.collision_avoidance or not obstacle_data then
        return 0.0
    end
    
    local max_risk = 0.0
    
    for _, obstacle in ipairs(obstacle_data) do
        if obstacle.distance < 50.0 then  -- Ближе 50 метров
            -- Расчет времени до столкновения (TTC)
            local relative_speed = obstacle.relative_speed or 0
            local ttc = obstacle.distance / math.max(math.abs(relative_speed), 1.0)
            
            -- Расчет риска (0-1)
            local risk = 0.0
            
            if ttc < 3.0 then  -- Меньше 3 секунд до столкновения
                risk = 1.0 - (ttc / 3.0)
            end
            
            -- Учет направления
            if obstacle.type == "vehicle" and relative_speed < -5.0 then
                risk = risk * 1.5  -- Увеличение риска для движущихся навстречу
            end
            
            max_risk = math.max(max_risk, risk)
        end
    end
    
    vehicle_control.state.collision_risk = max_risk
    
    -- Активация экстренного торможения
    if max_risk > 0.8 then
        vehicle_control.state.emergency_brake = true
        vehicle_control.log_warning("Активировано экстренное торможение (риск столкновения: " .. 
                                  string.format("%.1f%%)", max_risk * 100), "vehicle")
    elseif max_risk < 0.3 then
        vehicle_control.state.emergency_brake = false
    end
    
    return max_risk
end

-- Проверка устойчивости транспортного средства
function vehicle_control.check_stability(vehicle_data)
    if not vehicle_control.config.stability_control or not vehicle_data then
        return 0.0
    end
    
    local risk = 0.0
    
    -- Проверка заноса
    local lateral_acceleration = vehicle_data.lateral_acceleration or 0
    if math.abs(lateral_acceleration) > 5.0 then  -- Высокое боковое ускорение
        risk = math.min(math.abs(lateral_acceleration) / 10.0, 1.0)
    end
    
    -- Проверка скорости в повороте
    local steering_angle = math.abs(vehicle_control.state.current_steering)
    local speed = vehicle_data.speed_kmh or 0
    
    if steering_angle > 0.3 and speed > 80.0 then  -- Резкий поворот на высокой скорости
        risk = math.max(risk, 0.7)
    end
    
    vehicle_control.state.stability_risk = risk
    
    -- Коррекция управления при высоком риске
    if risk > 0.5 then
        -- Снижение скорости и выравнивание руля
        local speed_reduction = risk * 0.5  -- Снижение скорости на 50% при максимальном риске
        vehicle_control.state.target_speed = vehicle_control.state.target_speed * (1.0 - speed_reduction)
        
        -- Плавное выравнивание руля
        vehicle_control.state.target_steering = vehicle_control.state.target_steering * 0.5
    end
    
    return risk
end

-- Обновление системы управления
function vehicle_control.update(dt, vehicle_data, obstacle_data)
    if not vehicle_control.state.active or dt <= 0 then
        return false
    end
    
    local current_time = os.clock()
    
    -- Использование кэша для оптимизации производительности
    if vehicle_control.cache.vehicle_data and 
       current_time - vehicle_control.cache.last_update_time < vehicle_control.cache.update_interval then
        vehicle_data = vehicle_control.cache.vehicle_data
    else
        vehicle_control.cache.vehicle_data = vehicle_data
        vehicle_control.cache.last_update_time = current_time
    end
    
    if not vehicle_data then
        return false
    end
    
    -- Проверка безопасности
    local collision_risk = vehicle_control.check_collision_risk(obstacle_data, vehicle_data)
    local stability_risk = vehicle_control.check_stability(vehicle_data)
    
    -- Применение рулевого управления
    vehicle_control.apply_steering()
    
    -- Управление скоростью
    local current_speed = vehicle_data.speed_kmh or 0
    local throttle, brake = vehicle_control.control_speed(current_speed, dt)
    vehicle_control.apply_speed_control(throttle, brake)
    
    -- Управление передачами
    if vehicle_data.rpm then
        vehicle_control.control_gearshift(vehicle_data.rpm, current_speed)
    end
    
    -- Обновление статистики
    vehicle_control.update_statistics(dt, vehicle_data)
    
    -- Адаптивное управление
    if vehicle_control.config.adaptive_control then
        vehicle_control.adaptive_control(dt, vehicle_data)
    end
    
    return true
end

-- Адаптивное управление
function vehicle_control.adaptive_control(dt, vehicle_data)
    -- Адаптация к стилю вождения
    local avg_speed = vehicle_control.state.average_speed
    local current_speed = vehicle_data.speed_kmh or 0
    
    -- Адаптация чувствительности рулевого управления
    if current_speed > 100.0 then
        -- На высокой скорости - меньшая чувствительность
        vehicle_control.config.steering_sensitivity = 0.6
    else
        -- На низкой скорости - большая чувствительность
        vehicle_control.config.steering_sensitivity = 0.8
    end
    
    -- Адаптация к погодным условиям
    if vehicle_control.config.weather_adaptation then
        -- В реальной реализации здесь будет получение данных о погоде из игры
        local weather_intensity = 0.5  -- Временная заглушка
        
        if weather_intensity > 0.7 then
            -- Дождь/снег - увеличение дистанции и снижение скорости
            vehicle_control.config.speed_tolerance = 5.0
            vehicle_control.config.max_acceleration = 0.5
            vehicle_control.config.max_braking = 0.8
        end
    end
end

-- Обновление статистики
function vehicle_control.update_statistics(dt, vehicle_data)
    vehicle_control.state.driving_time = vehicle_control.state.driving_time + dt
    vehicle_control.state.total_distance = vehicle_control.state.total_distance + 
                                          (vehicle_data.speed or 0) * dt
    
    if vehicle_data.fuel_consumption then
        vehicle_control.state.total_fuel_used = vehicle_control.state.total_fuel_used + 
                                               vehicle_data.fuel_consumption * dt
    end
    
    -- Расчет средней скорости
    if vehicle_control.state.driving_time > 0 then
        vehicle_control.state.average_speed = vehicle_control.state.total_distance / 
                                             vehicle_control.state.driving_time * 3.6  -- в км/ч
    end
end

-- Получение статистики управления
function vehicle_control.get_stats()
    return {
        driving_time = vehicle_control.state.driving_time,
        total_distance = vehicle_control.state.total_distance,
        total_fuel_used = vehicle_control.state.total_fuel_used,
        average_speed = vehicle_control.state.average_speed,
        current_gear = vehicle_control.state.current_gear,
        collision_risk = vehicle_control.state.collision_risk,
        stability_risk = vehicle_control.state.stability_risk
    }
end

-- Остановка системы управления
function vehicle_control.stop()
    vehicle_control.state.active = false
    
    -- Плавный останов
    vehicle_control.state.target_speed = 0.0
    vehicle_control.state.target_steering = 0.0
    
    vehicle_control.log_info("Система управления остановлена", "vehicle")
    
    return true
end

-- Очистка системы управления
function vehicle_control.cleanup()
    vehicle_control.stop()
    vehicle_control.reset_state()
    
    vehicle_control.state.initialized = false
    
    vehicle_control.log_info("Система управления очищена", "vehicle")
    
    return true
end

-- Вспомогательная функция: знак числа
function math.sign(x)
    if x > 0 then return 1
    elseif x < 0 then return -1
    else return 0 end
end

-- Функции логгирования
function vehicle_control.log_debug(message, module)
    if _G.log_debug then
        _G.log_debug(message, module or "vehicle")
    end
end

function vehicle_control.log_info(message, module)
    if _G.log_info then
        _G.log_info(message, module or "vehicle")
    end
end

function vehicle_control.log_warning(message, module)
    if _G.log_warning then
        _G.log_warning(message, module or "vehicle")
    end
end

function vehicle_control.log_error(message, module)
    if _G.log_error then
        _G.log_error(message, module or "vehicle")
    end
end

-- Экспорт модуля
return vehicle_control