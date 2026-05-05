-- Контроллер скорости для автопилота
-- Управляет ускорением, торможением и поддержанием скорости

local speed_controller = {
    current_speed = 0,
    target_speed = 80,
    max_acceleration = 0.8,
    max_deceleration = 0.5,
    cruise_control = true,
    
    -- PID контроллер
    kp = 0.8,
    ki = 0.1,
    kd = 0.2,
    
    integral = 0,
    previous_error = 0
}

-- Установка целевой скорости
function speed_controller.set_target_speed(speed)
    if speed >= 30 and speed <= 130 then
        speed_controller.target_speed = speed
        return true
    end
    return false
end

-- Расчет управления (возвращает throttle и brake)
function speed_controller.calculate(speed_kmh, dt)
    speed_controller.current_speed = speed_kmh
    
    local error = speed_controller.target_speed - speed_kmh
    
    -- PID расчет
    speed_controller.integral = speed_controller.integral + error * dt
    local derivative = (error - speed_controller.previous_error) / dt
    
    local output = speed_controller.kp * error + 
                   speed_controller.ki * speed_controller.integral + 
                   speed_controller.kd * derivative
    
    speed_controller.previous_error = error
    
    -- Преобразование в throttle/brake
    local throttle = 0
    local brake = 0
    
    if output > 0 then
        -- Нужно ускориться
        throttle = math.min(output / 100, speed_controller.max_acceleration)
        brake = 0
    else
        -- Нужно замедлиться
        throttle = 0
        brake = math.min(-output / 100, speed_controller.max_deceleration)
    end
    
    -- Учет дорожных условий
    throttle, brake = speed_controller.adjust_for_road_conditions(throttle, brake)
    
    return throttle, brake
end

-- Корректировка для дорожных условий
function speed_controller.adjust_for_road_conditions(throttle, brake)
    local road_slope = get_road_slope() or 0
    local surface_grip = get_surface_grip() or 1.0
    
    -- Учет уклона
    if road_slope > 0.05 then
        -- Подъем - увеличить throttle
        throttle = throttle * 1.3
    elseif road_slope < -0.05 then
        -- Спуск - увеличить brake
        brake = brake * 1.2
    end
    
    -- Учет сцепления
    throttle = throttle * surface_grip
    brake = brake * surface_grip
    
    return math.max(0, math.min(1, throttle)), math.max(0, math.min(1, brake))
end

-- Автоматическое определение целевой скорости на основе ограничений
function speed_controller.auto_adjust()
    local speed_limit = get_current_speed_limit() or speed_controller.target_speed
    local curvature = get_road_curvature() or 0
    
    -- Корректировка на основе кривизны дороги
    local adjusted_speed = speed_limit
    
    if curvature > 0.3 then
        adjusted_speed = adjusted_speed * 0.7
    elseif curvature > 0.1 then
        adjusted_speed = adjusted_speed * 0.85
    end
    
    -- Учет погодных условий
    local weather_factor = get_weather_factor() or 1.0
    adjusted_speed = adjusted_speed * weather_factor
    
    speed_controller.set_target_speed(adjusted_speed)
    
    return adjusted_speed
end

-- Экстренное торможение
function speed_controller.emergency_brake()
    return 1.0, 1.0 -- Полный brake, throttle 0
end

-- Плавное торможение до полной остановки
function speed_controller.brake_to_stop(distance, current_speed)
    local required_deceleration = (current_speed * current_speed) / (2 * distance)
    local brake_intensity = math.min(required_deceleration / 10, 1.0)
    
    return 0, brake_intensity
end

-- Включение/выключение круиз-контроля
function speed_controller.toggle_cruise_control()
    speed_controller.cruise_control = not speed_controller.cruise_control
    return speed_controller.cruise_control
end

-- Получение рекомендуемой скорости для поворота
function speed_controller.get_turn_speed(curvature_radius)
    if not curvature_radius or curvature_radius <= 0 then
        return speed_controller.target_speed
    end
    
    -- Формула безопасной скорости для поворота
    local g = 9.81
    local friction = 0.8 -- коэффициент трения
    local safe_speed = math.sqrt(friction * g * curvature_radius) * 3.6 -- в км/ч
    
    return math.min(safe_speed, speed_controller.target_speed)
end

return speed_controller