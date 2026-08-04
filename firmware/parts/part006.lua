                       PIOS.doForAllComponents("display", function(disp)
                            disp.setFont(PIOS.theme.font)
                        end)
                    else -- * Иначе...
                        PIOS.logger("Не найден шрифт из темы: " .. PIOS.theme.accent .. value, "ERROR")
                    end
                else                        -- * Иначе...
                    PIOS.theme[key] = value -- Просто заменяем ключ темы
                end
            end

            PIOS.logger("Тема загружена из файла " .. PIOS.theme.accent .. path, "INFO")
        else -- * Иначе...
            PIOS.logger(PIOS.theme.errorForeground ..
                "Неправильная структура файла темы (" .. path .. "). Используется стандартная тема", "ERROR")
        end
    end
end

--- Вызывает точку входа модулей
--- @param point string Точка входа
--- @param arg any? Аргумент
--- @param silent boolean? Не отображать сообщение в консоли отладки? (по умолчанию false)
--- @return table<table<any>> results Результаты от модулей
local function callModulesEntrypoint(point, arg, silent)
    silent = silent or false

    if not silent then
        PIOS.logger(
            "Запуск точки входа " ..
            PIOS.theme.accent ..
            point .. PIOS.theme.foreground .. " для " .. PIOS.theme.accent .. #PIOS.modules .. PIOS.theme.foreground ..
            " мод.", "DEBUG")
    end
    local results = {}

    for index, module in ipairs(PIOS.modules) do
        local entrypoint = module[point]
        if entrypoint then
            local startClock = os.clock()
            local valid, moduleResult = pcall(entrypoint, module, arg)
            if not valid then
                PIOS.logger(
                    "Ошибка точки входа " .. PIOS.theme.accent .. point .. PIOS.theme.foreground .. " модуля " ..
                    PIOS.theme.accent .. module.name .. PIOS.theme.foreground .. ": " ..
                    PIOS.theme.errorForeground .. moduleResult,
                    "ERROR")

                if point ~= "onStop" then
                    callModulesEntrypoint("onStop", "error")
                end
                table.remove(PIOS.modules, index)
            end

            if valid then
                if not module.entrypointsClocks then
                    module.entrypointsClocks = {}
                end
                module.entrypointsClocks[point] = os.clock() - startClock

                local result = {
                    result = moduleResult,
                    module = module.name
                }

                table.insert(results, result)
            end
        end
    end

    return results
end

--- Загружает модули
--- @param fs table<function> API файловой системы
local function loadModules(fs)
    local toBoot = {}

    if fs.hasFolder("/PIOS/modules") then
        for _, file in ipairs(fs.getFileList("/PIOS/modules")) do -- * Первый заход: загружаем модули с bootAfter = system
            local moduleRaw = fs.readFile("/PIOS/modules/" .. file)

            local moduleFunc
            if PIOS.getFileExtension(file) == ".bin" then
                moduleFunc = enlua.load(moduleRaw)
            else
                moduleFunc = load(moduleRaw)
            end

            if moduleFunc then
                local startClock = os.clock()
                local valid, data = pcall(moduleFunc)
                if valid and data then
                    if not data.name then
                        data.name = file
                        PIOS.logger(
                            "В модуле " ..
                            PIOS.theme.accent ..
                            data.name .. PIOS.theme.foreground .. " не найдено поле отвечаю�