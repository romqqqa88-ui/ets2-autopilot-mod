-- Система звуковых оповещений для автопилота
-- Воспроизводит звуки для различных событий и состояний автопилота

local sound_notifications = {
    -- Настройки
    enabled = true, -- включены ли звуковые оповещения
    master_volume = 0.7, -- общая громкость (0.0 - 1.0)
    sound_volume = {
        notifications = 0.8, -- громкость уведомлений
        warnings = 0.9, -- громкость предупреждений
        alerts = 1.0, -- громкость тревог
        ui = 0.5 -- громкость звуков интерфейса
    },
    
    -- Звуковые файлы
    sound_files = {
        -- Основные события
        autopilot_on = "sound/autopilot_on.ogg",
        autopilot_off = "sound/autopilot_off.ogg",
        autopilot_engaged = "sound/engaged.ogg",
        autopilot_disengaged = "sound/disengaged.ogg",
        
        -- Предупреждения
        warning_general = "sound/warning.ogg",
        warning_obstacle = "sound/obstacle_warning.ogg",
        warning_speed = "sound/speed_warning.ogg",
        warning_lane = "sound/lane_warning.ogg",
        
        -- Уведомления
        notification_info = "sound/notification.ogg",
        notification_success = "sound/success.ogg",
        notification_error = "sound/error.ogg",
        
        -- Действия
        overtaking_start = "sound/overtaking_start.ogg",
        overtaking_complete = "sound/overtaking_complete.ogg",
        overtaking_abort = "sound/overtaking_abort.ogg",
        
        parking_start = "sound/parking_start.ogg",
        parking_complete = "sound/parking_complete.ogg",
        parking_abort = "sound/parking_abort.ogg",
        
        -- Дорожные знаки
        sign_speed_limit = "sound/speed_limit.ogg",
        sign_no_overtaking = "sound/no_overtaking.ogg",
        sign_stop = "sound/stop_sign.ogg",
        sign_yield = "sound/yield.ogg",
        
        -- Интерфейс
        ui_click = "sound/ui_click.ogg",
        ui_hover = "sound/ui_hover.ogg",
        ui_slider = "sound/ui_slider.ogg",
        
        -- Системные
        system_start = "sound/system_start.ogg",
        system_ready = "sound/system_ready.ogg",
        system_error = "sound/system_error.ogg"
    },
    
    -- Состояние воспроизведения
    playing_sounds = {},
    sound_queue = {},
    
    -- Ограничения
    max_concurrent_sounds = 5, -- максимальное количество одновременно воспроизводимых звуков
    min_time_between_same_sounds = 0.5, -- минимальное время между одинаковыми звуками (секунды)
    
    -- История воспроизведения
    sound_history = {},
    last_play_times = {},
    
    -- Статистика
    sounds_played = 0,
    sounds_blocked = 0
}

-- Инициализация системы звуковых оповещений
function sound_notifications.init()
    log("Sound Notifications: Инициализация системы звуковых оповещений")
    
    -- Загрузка конфигурации
    sound_notifications.load_config()
    
    -- Загрузка звуковых файлов
    sound_notifications.load_sounds()
    
    -- Сброс состояния
    sound_notifications.reset()
    
    -- Тестовое воспроизведение
    sound_notifications.play_system_start()
    
    return true
end

-- Загрузка конфигурации
function sound_notifications.load_config()
    -- Здесь будет загрузка из конфигурационного файла
    sound_notifications.enabled = true
    sound_notifications.master_volume = 0.7
    sound_notifications.sound_volume = {
        notifications = 0.8,
        warnings = 0.9,
        alerts = 1.0,
        ui = 0.5
    }
end

-- Загрузка звуковых файлов
function sound_notifications.load_sounds()
    log("Sound Notifications: Загрузка звуковых файлов")
    
    -- В реальной реализации здесь будет загрузка файлов из папки sound/
    -- Для демонстрации создаем заглушки
    
    for sound_name, file_path in pairs(sound_notifications.sound_files) do
        log("  Загрузка: " .. sound_name .. " -> " .. file_path)
        -- Здесь будет вызов API игры для загрузки звука
    end
    
    log("Sound Notifications: Загружено " .. count_table(sound_notifications.sound_files) .. " звуковых файлов")
end

-- Сброс состояния
function sound_notifications.reset()
    sound_notifications.playing_sounds = {}
    sound_notifications.sound_queue = {}
    sound_notifications.sound_history = {}
    sound_notifications.last_play_times = {}
    sound_notifications.sounds_played = 0
    sound_notifications.sounds_blocked = 0
end

-- Обновление системы звуковых оповещений
function sound_notifications.update(dt)
    if not sound_notifications.enabled then
        return
    end
    
    -- Обновление воспроизводимых звуков
    sound_notifications.update_playing_sounds(dt)
    
    -- Обработка очереди звуков
    sound_notifications.process_sound_queue()
    
    -- Очистка истории
    sound_notifications.cleanup_history()
end

-- Обновление воспроизводимых звуков
function sound_notifications.update_playing_sounds(dt)
    for i = #sound_notifications.playing_sounds, 1, -1 do
        local sound = sound_notifications.playing_sounds[i]
        
        -- Обновление времени воспроизведения
        sound.play_time = sound.play_time + dt
        
        -- Проверка завершения воспроизведения
        if sound.play_time >= sound.duration then
            table.remove(sound_notifications.playing_sounds, i)
            log("Sound Notifications: Звук завершен: " .. sound.name)
        end
    end
end

-- Обработка очереди звуков
function sound_notifications.process_sound_queue()
    if #sound_notifications.sound_queue == 0 then
        return
    end
    
    -- Проверка возможности воспроизведения
    if #sound_notifications.playing_sounds >= sound_notifications.max_concurrent_sounds then
        return
    end
    
    -- Воспроизведение следующего звука из очереди
    local sound_to_play = table.remove(sound_notifications.sound_queue, 1)
    
    if sound_notifications.can_play_sound(sound_to_play.name) then
        sound_notifications.play_sound_internal(sound_to_play)
    end
end

-- Очистка истории
function sound_notifications.cleanup_history()
    local current_time = get_game_time()
    local max_history_age = 60.0 -- 60 секунд
    
    for i = #sound_notifications.sound_history, 1, -1 do
        local history_entry = sound_notifications.sound_history[i]
        
        if current_time - history_entry.time > max_history_age then
            table.remove(sound_notifications.sound_history, i)
        end
    end
end

-- Проверка возможности воспроизведения звука
function sound_notifications.can_play_sound(sound_name)
    if not sound_notifications.enabled then
        return false
    end
    
    -- Проверка минимального времени между одинаковыми звуками
    local last_play_time = sound_notifications.last_play_times[sound_name]
    if last_play_time then
        local time_since_last_play = get_game_time() - last_play_time
        if time_since_last_play < sound_notifications.min_time_between_same_sounds then
            sound_notifications.sounds_blocked = sound_notifications.sounds_blocked + 1
            return false
        end
    end
    
    -- Проверка количества одновременно воспроизводимых звуков
    if #sound_notifications.playing_sounds >= sound_notifications.max_concurrent_sounds then
        return false
    end
    
    return true
end

-- Внутреннее воспроизведение звука
function sound_notifications.play_sound_internal(sound_info)
    -- Расчет громкости
    local volume = sound_notifications.master_volume * 
                   (sound_notifications.sound_volume[sound_info.category] or 0.8)
    
    -- Воспроизведение звука через API игры
    local success = play_sound_file(sound_info.file, volume, sound_info.loop)
    
    if success then
        -- Добавление в список воспроизводимых звуков
        table.insert(sound_notifications.playing_sounds, {
            name = sound_info.name,
            file = sound_info.file,
            category = sound_info.category,
            volume = volume,
            start_time = get_game_time(),
            play_time = 0,
            duration = sound_info.duration or 1.0
        })
        
        -- Обновление времени последнего воспроизведения
        sound_notifications.last_play_times[sound_info.name] = get_game_time()
        
        -- Добавление в историю
        table.insert(sound_notifications.sound_history, {
            name = sound_info.name,
            time = get_game_time(),
            volume = volume
        })
        
        -- Обновление статистики
        sound_notifications.sounds_played = sound_notifications.sounds_played + 1
        
        log("Sound Notifications: Воспроизведен звук: " .. sound_info.name .. 
            " (громкость: " .. string.format("%.2f", volume) .. ")")
        
        return true
    else
        log("Sound Notifications: Ошибка воспроизведения звука: " .. sound_info.name)
        return false
    end
end

-- Воспроизведение звука по имени
function sound_notifications.play_sound(sound_name, category, loop)
    if not sound_notifications.enabled then
        return false
    end
    
    -- Поиск файла звука
    local sound_file = sound_notifications.sound_files[sound_name]
    
    if not sound_file then
        log("Sound Notifications: Звук не найден: " .. sound_name)
        return false
    end
    
    -- Определение категории
    category = category or "notifications"
    
    -- Создание информации о звуке
    local sound_info = {
        name = sound_name,
        file = sound_file,
        category = category,
        loop = loop or false,
        duration = sound_notifications.get_sound_duration(sound_name)
    }
    
    -- Проверка возможности немедленного воспроизведения
    if sound_notifications.can_play_sound(sound_name) then
        return sound_notifications.play_sound_internal(sound_info)
    else
        -- Добавление в очередь
        table.insert(sound_notifications.sound_queue, sound_info)
        log("Sound Notifications: Звук добавлен в очередь: " .. sound_name)
        return true
    end
end

-- Получение длительности звука
function sound_notifications.get_sound_duration(sound_name)
    -- В реальной реализации здесь будет получение длительности из метаданных
    -- Для демонстрации используем приблизительные значения
    
    local durations = {
        autopilot_on = 1.5,
        autopilot_off = 1.0,
        warning_general = 0.8,
        warning_obstacle = 1.2,
        notification_info = 0.5,
        ui_click = 0.2,
        system_start = 2.0
    }
    
    return durations[sound_name] or 1.0
end

-- Оповещения о событиях автопилота
function sound_notifications.notify_autopilot_event(event, data)
    if not sound_notifications.enabled then
        return
    end
    
    local sound_to_play = nil
    local category = "notifications"
    
    if event == "autopilot_on" then
        sound_to_play = "autopilot_on"
        category = "alerts"
    elseif event == "autopilot_off" then
        sound_to_play = "autopilot_off"
        category = "alerts"
    elseif event == "autopilot_engaged" then
        sound_to_play = "autopilot_engaged"
        category = "notifications"
    elseif event == "autopilot_disengaged" then
        sound_to_play = "autopilot_disengaged"
        category = "notifications"
    elseif event == "destination_reached" then
        sound_to_play = "notification_success"
        category = "notifications"
    elseif event == "route_changed" then
        sound_to_play = "notification_info"
        category = "notifications"
    end
    
    if sound_to_play then
        sound_notifications.play_sound(sound_to_play, category)
    end
end

-- Оповещения о предупреждениях
function sound_notifications.notify_warning(warning_type, severity)
    if not sound_notifications.enabled then
        return
    end
    
    local sound_to_play = nil
    local category = "warnings"
    
    if warning_type == "obstacle" then
        sound_to_play = "warning_obstacle"
        if severity == "high" then
            category = "alerts"
        end
    elseif warning_type == "speed" then
        sound_to_play = "warning_speed"
    elseif warning_type == "lane" then
        sound_to_play = "warning_lane"
    elseif warning_type == "collision" then
        sound_to_play = "warning_general"
        category = "alerts"
    else
        sound_to_play = "warning_general"
    end
    
    if sound_to_play then
        sound_notifications.play_sound(sound_to_play, category)
    end
end

-- Оповещения о дорожных знаках
function sound_notifications.notify_traffic_sign(sign_type)
    if not sound_notifications.enabled then
        return
    end
    
    local sound_to_play = nil
    local category = "notifications"
    
    if sign_type == "speed_limit" then
        sound_to_play = "sign_speed_limit"
    elseif sign_type == "no_overtaking" then
        sound_to_play = "sign_no_overtaking"
        category = "warnings"
    elseif sign_type == "stop" then
        sound_to_play = "sign_stop"
        category = "warnings"
    elseif sign_type == "yield" then
        sound_to_play = "sign_yield"
    end
    
    if sound_to_play then
        sound_notifications.play_sound(sound_to_play, category)
    end
end

-- Оповещения о маневрах
function sound_notifications.notify_maneuver(maneuver_type, status)
    if not sound_notifications.enabled then
        return
    end
    
    local sound_to_play = nil
    local category = "notifications"
    
    if maneuver_type == "overtaking" then
        if status == "start" then
            sound_to_play = "overtaking_start"
        elseif status == "complete" then
            sound_to_play = "overtaking_complete"
        elseif status == "abort" then
            sound_to_play = "overtaking_abort"
            category = "warnings"
        end
    elseif maneuver_type == "parking" then
        if status == "start" then
            sound_to_play = "parking_start"
        elseif status == "complete" then
            sound_to_play = "parking_complete"
        elseif status == "abort" then
            sound_to_play = "parking_abort"
            category = "warnings"
        end
    elseif maneuver_type == "lane_change" then
        sound_to_play = "notification_info"
    end
    
    if sound_to_play then
        sound_notifications.play_sound(sound_to_play, category)
    end
end

-- Оповещения о системных событиях
function sound_notifications.notify_system_event(event)
    if not sound_notifications.enabled then
        return
    end
    
    local sound_to_play = nil
    local category = "notifications"
    
    if event == "system_start" then
        sound_to_play = "system_start"
    elseif event == "system_ready" then
        sound_to_play = "system_ready"
    elseif event == "system_error" then
        sound_to_play = "system_error"
        category = "alerts"
    elseif event == "config_saved" then
        sound_to_play = "notification_success"
    elseif event == "config_loaded" then
        sound_to_play = "notification_info"
    end
    
    if sound_to_play then
        sound_notifications.play_sound(sound_to_play, category)
    end
end

-- Звуки интерфейса
function sound_notifications.play_ui_sound(sound_type)
    if not sound_notifications.enabled or sound_notifications.sound_volume.ui <= 0 then
        return
    end
    
    local sound_to_play = nil
    
    if sound_type == "click" then
        sound_to_play = "ui_click"
    elseif sound_type == "hover" then
        sound_to_play = "ui_hover"
    elseif sound_type == "slider" then
        sound_to_play = "ui_slider"
    end
    
    if sound_to_play then
        sound_notifications.play_sound(sound_to_play, "ui")
    end
end

-- Тестовые звуки
function sound_notifications.play_system_start()
    sound_notifications.play_sound("system_start", "alerts")
end

function sound_notifications.play_test_sequence()
    log("Sound Notifications: Воспроизведение тестовой последовательности")
    
    -- Последовательность тестовых звуков
    local test_sequence = {
        {"autopilot_on", "alerts"},
        {"notification_info", "notifications"},
        {"warning_general", "warnings"},
        {"ui_click", "ui"},
        {"system_ready", "notifications"}
    }
    
    for i, test_sound in ipairs(test_sequence) do
        -- Задержка между звуками
        local delay = (i - 1) * 1.0 -- 1 секунда между звуками
        
        schedule_function(function()
            sound_notifications.play_sound(test_sound[1], test_sound[2])
        end, delay)
    end
end

-- Управление громкостью
function sound_notifications.set_master_volume(volume)
    volume = math.max(0.0, math.min(1.0, volume))
    sound_notifications.master_volume = volume
    
    -- Обновление громкости воспроизводимых звуков
    for _, sound in ipairs(sound_notifications.playing_sounds) do
        local new_volume = volume * (sound_notifications.sound_volume[sound.category] or 0.8)
        set_sound_volume(sound.name, new_volume)
    end
    
    log("Sound Notifications: Установлена общая громкость: " .. string.format("%.2f", volume))
end

function sound_notifications.set_category_volume(category, volume)
    volume = math.max(0.0, math.min(1.0, volume))
    sound_notifications.sound_volume[category] = volume
    
    -- Обновление громкости звуков этой категории
    for _, sound in ipairs(sound_notifications.playing_sounds) do
        if sound.category == category then
            local new_volume = sound_notifications.master_volume * volume
            set_sound_volume(sound.name, new_volume)
        end
    end
    
    log("Sound Notifications: Установлена громкость категории '" .. category .. "': " .. string.format("%.2f", volume))
end

-- Включение/выключение звуковых оповещений
function sound_notifications.toggle()
    sound_notifications.enabled = not sound_notifications.enabled
    
    if sound_notifications.enabled then
        log("Sound Notifications: Звуковые оповещения включены")
        sound_notifications.play_sound("system_ready", "notifications")
    else
        log("Sound Notifications: Звуковые оповещения выключены")
        -- Остановка всех звуков
        sound_notifications.stop_all_sounds()
    end
    
    return sound_notifications.enabled
end

-- Остановка всех звуков
function sound_notifications.stop_all_sounds()
    for _, sound in ipairs(sound_notifications.playing_sounds) do
        stop_sound(sound.name)
    end
    
    sound_notifications.playing_sounds = {}
    sound_notifications.sound_queue = {}
    
    log("Sound Notifications: Все звуки остановлены")
end

-- Получение информации о состоянии для отображения
function sound_notifications.get_status_info()
    return {
        enabled = sound_notifications.enabled,
        master_volume = sound_notifications.master_volume,
        playing_sounds_count = #sound_notifications.playing_sounds,
        queued_sounds_count = #sound_notifications.sound_queue,
        sounds_played = sound_notifications.sounds_played,
        sounds_blocked = sound_notifications.sounds_blocked
    }
end

-- Вспомогательные функции
function log(message)
    print("[Sound Notifications] " .. message)
end

function count_table(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

function schedule_function(func, delay)
    -- Заглушка для планирования выполнения функции с задержкой
    -- В реальной реализации используйте соответствующий API
    local start_time = get_game_time()
    
    local function check()
        if get_game_time() - start_time >= delay then
            func()
        end
    end
    
    -- Здесь нужно зарегистрировать check для периодического вызова
end

return sound_notifications