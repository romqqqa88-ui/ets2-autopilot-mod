-- Модуль логгирования для автопилота ETS 2
-- Поддерживает ротацию файлов, уровни логирования и оптимизацию производительности

local logging = {
    -- Конфигурация
    config = {
        log_level = "info",  -- debug, info, warning, error
        log_to_file = true,
        log_file_path = "logs/autopilot.log",
        max_file_size = 10 * 1024 * 1024,  -- 10 MB
        max_backup_files = 5,
        enable_console_output = true,
        timestamp_format = "%Y-%m-%d %H:%M:%S",
        performance_monitoring = true
    },
    
    -- Состояние
    state = {
        log_file = nil,
        current_file_size = 0,
        log_count = 0,
        error_count = 0,
        warning_count = 0,
        last_performance_check = 0,
        performance_stats = {
            avg_write_time = 0,
            max_write_time = 0,
            total_writes = 0
        }
    }
}

-- Инициализация логгирования
function logging.init(config_overrides)
    -- Применение переопределений конфигурации
    if config_overrides then
        for key, value in pairs(config_overrides) do
            logging.config[key] = value
        end
    end
    
    -- Создание директории для логов
    logging.ensure_log_directory()
    
    -- Открытие файла лога
    if logging.config.log_to_file then
        local success, file = pcall(io.open, logging.config.log_file_path, "a")
        if success and file then
            logging.state.log_file = file
            logging.state.current_file_size = file:seek("end")
            logging.log_info("Логгирование инициализировано", "logging")
        else
            logging.log_error("Не удалось открыть файл лога: " .. tostring(logging.config.log_file_path), "logging")
            logging.config.log_to_file = false
        end
    end
    
    -- Запись заголовка сессии
    logging.log_info("=== Сессия логгирования начата ===", "logging")
    logging.log_info(string.format("Уровень логирования: %s", logging.config.log_level), "logging")
    logging.log_info(string.format("Путь к файлу: %s", logging.config.log_file_path), "logging")
    
    return true
end

-- Обеспечение существования директории для логов
function logging.ensure_log_directory()
    local path = logging.config.log_file_path
    local dir = path:match("^(.*[/\\])")
    
    if dir and dir ~= "" then
        -- Создание директории рекурсивно
        local cmd = string.format('mkdir "%s" 2>nul', dir)
        os.execute(cmd)
    end
end

-- Проверка необходимости ротации файла
function logging.check_rotation()
    if not logging.config.log_to_file or not logging.state.log_file then
        return false
    end
    
    if logging.state.current_file_size >= logging.config.max_file_size then
        logging.rotate_log_file()
        return true
    end
    
    return false
end

-- Ротация файла лога
function logging.rotate_log_file()
    if not logging.config.log_to_file or not logging.state.log_file then
        return false
    end
    
    -- Закрытие текущего файла
    logging.state.log_file:close()
    
    -- Переименование существующих файлов
    for i = logging.config.max_backup_files - 1, 1, -1 do
        local old_name = string.format("%s.%d", logging.config.log_file_path, i)
        local new_name = string.format("%s.%d", logging.config.log_file_path, i + 1)
        
        if os.rename(old_name, new_name) then
            logging.log_debug(string.format("Переименован файл лога: %s -> %s", old_name, new_name), "logging")
        end
    end
    
    -- Переименование текущего файла в .1
    local first_backup = string.format("%s.1", logging.config.log_file_path)
    os.rename(logging.config.log_file_path, first_backup)
    
    -- Создание нового файла
    local success, file = pcall(io.open, logging.config.log_file_path, "w")
    if success and file then
        logging.state.log_file = file
        logging.state.current_file_size = 0
        logging.log_info("Файл лога ротирован", "logging")
        return true
    else
        logging.config.log_to_file = false
        logging.log_error("Не удалось создать новый файл лога после ротации", "logging")
        return false
    end
end

-- Запись лога
function logging.write_log(level, message, module)
    local timestamp = os.date(logging.config.timestamp_format)
    local module_str = module and string.format("[%s]", module) or ""
    local log_entry = string.format("[%s] [%s]%s %s", timestamp, level, module_str, message)
    
    -- Вывод в консоль
    if logging.config.enable_console_output then
        print(log_entry)
    end
    
    -- Запись в файл
    if logging.config.log_to_file and logging.state.log_file then
        local start_time = os.clock()
        
        logging.state.log_file:write(log_entry .. "\n")
        logging.state.log_file:flush()
        
        local write_time = os.clock() - start_time
        
        -- Обновление статистики производительности
        if logging.config.performance_monitoring then
            logging.update_performance_stats(write_time)
        end
        
        -- Обновление размера файла
        logging.state.current_file_size = logging.state.current_file_size + #log_entry + 1
        logging.state.log_count = logging.state.log_count + 1
        
        -- Проверка ротации
        if logging.state.current_file_size >= logging.config.max_file_size then
            logging.check_rotation()
        end
    end
    
    -- Обновление счетчиков
    if level == "ERROR" then
        logging.state.error_count = logging.state.error_count + 1
    elseif level == "WARNING" then
        logging.state.warning_count = logging.state.warning_count + 1
    end
    
    return true
end

-- Обновление статистики производительности
function logging.update_performance_stats(write_time)
    local stats = logging.state.performance_stats
    
    stats.total_writes = stats.total_writes + 1
    stats.avg_write_time = (stats.avg_write_time * (stats.total_writes - 1) + write_time) / stats.total_writes
    
    if write_time > stats.max_write_time then
        stats.max_write_time = write_time
    end
    
    -- Периодическая проверка производительности
    local current_time = os.time()
    if current_time - logging.state.last_performance_check > 60 then  -- Каждую минуту
        logging.check_performance()
        logging.state.last_performance_check = current_time
    end
end

-- Проверка производительности логгирования
function logging.check_performance()
    local stats = logging.state.performance_stats
    
    if stats.avg_write_time > 0.001 then  -- Если среднее время записи > 1 мс
        logging.log_warning(string.format("Высокое время записи логов: %.3f мс (макс: %.3f мс)", 
                                        stats.avg_write_time * 1000, stats.max_write_time * 1000), "logging")
        
        -- Автоматическая оптимизация
        if stats.avg_write_time > 0.005 then  -- > 5 мс
            logging.config.enable_console_output = false
            logging.log_warning("Отключен вывод в консоль для оптимизации производительности", "logging")
        end
    end
end

-- Функции логирования по уровням
function logging.log_debug(message, module)
    if logging.config.log_level == "debug" then
        return logging.write_log("DEBUG", message, module)
    end
    return false
end

function logging.log_info(message, module)
    if logging.config.log_level == "debug" or 
       logging.config.log_level == "info" then
        return logging.write_log("INFO", message, module)
    end
    return false
end

function logging.log_warning(message, module)
    if logging.config.log_level == "debug" or 
       logging.config.log_level == "info" or 
       logging.config.log_level == "warning" then
        return logging.write_log("WARNING", message, module)
    end
    return false
end

function logging.log_error(message, module)
    return logging.write_log("ERROR", message, module)
end

-- Получение статистики логгирования
function logging.get_stats()
    return {
        log_count = logging.state.log_count,
        error_count = logging.state.error_count,
        warning_count = logging.state.warning_count,
        file_size = logging.state.current_file_size,
        performance = logging.state.performance_stats
    }
end

-- Очистка логгирования
function logging.cleanup()
    if logging.state.log_file then
        logging.log_info("=== Сессия логгирования завершена ===", "logging")
        
        -- Запись итоговой статистики
        local stats = logging.get_stats()
        logging.log_info(string.format("Итоговая статистика: %d записей, %d ошибок, %d предупреждений", 
                                     stats.log_count, stats.error_count, stats.warning_count), "logging")
        
        logging.state.log_file:close()
        logging.state.log_file = nil
    end
    
    return true
end

-- Экспорт модуля
return logging