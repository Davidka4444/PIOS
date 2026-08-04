return {
    name = "HMC", -- * Имя модуля
    version = "1.0", -- * Версия модуля
    description =
    "Библиотека, которая позволяет загружать/выгружать модули не перезагружая ПК", -- * Описание модуля
    bootAfter = "system", -- * После чего запускать модуль (system - после запуска системы, otherModules - после запуска остальных модулей. Полезно, если в модуле используются внешние модули-библиотеки)
    allowPSUP = true, -- * Разрешить PSUP (PIOS Self-Update Protocol) обновлять данный модуль?

    -- # Точки входа
    onStart = function(self) -- * При запуске модуля (включении ПК)...
        --- Загружает модуль
        --- @param file string Файл модуля
        self.loadModule = function(file)
            local moduleRaw = PIOS.fs.readFile("/PIOS/modules/" .. file)

            local moduleFunc = load(moduleRaw)
            if moduleFunc then
                local valid, data = pcall(moduleFunc)
                if valid and data then
                    if not data.name then
                        data.name = file
                        PIOS.logger(
                            "В модуле " ..
                            PIOS.theme.accent ..
                            data.name .. PIOS.theme.foreground .. " не найдено поле отвечающее за имя",
                            "WARN")
                    elseif not data.version then
                        data.version = "0.0"
                        PIOS.logger(
                            "В модуле " ..
                            PIOS.theme.accent ..
                            data.name .. PIOS.theme.foreground .. " не найдено поле отвечающее за версию",
                            "WARN")
                    elseif not data.description then
                        data.description = ""
                        PIOS.logger(
                            "В модуле " ..
                            PIOS.theme.accent ..
                            data.name .. PIOS.theme.foreground .. " не найдено поле отвечающее за описание",
                            "WARN")
                    elseif data.bootAfter ~= "system" and data.bootAfter ~= "otherModules" then
                        data.bootAfter = "system"
                        PIOS.logger(
                            "В модуле " ..
                            PIOS.theme.accent ..
                            data.name .. PIOS.theme.foreground .. " поле отвечающее за режим запуска неверно",
                            "WARN")
                    end

                    function data.addCall(name, func)
                        PIOS[name] = func
                    end

                    data.callModulesEntrypoint = self.callModulesEntrypoint

                    table.insert(PIOS.modules, data)
                    PIOS.logger(
                        "Модуль загружен: " ..
                        PIOS.theme.accent .. data.name .. " v" .. data.version ..
                        PIOS.theme.foreground .. ": " .. PIOS.theme.accent .. data.description, "INFO")

                    PIOS.logger(
                        "Запуск точки входа " ..
                        PIOS.theme.accent ..
                        "onStart" ..
                        PIOS.theme.foreground ..
                        " модуля " .. PIOS.theme.accent .. data.name, "DEBUG")

                    local entrypoint = data.onStart
                    if entrypoint then
                        local valid, moduleResult = pcall(entrypoint, data)
                        if not valid then
                            PIOS.logger(
                                "Ошибка точки входа " ..
                                PIOS.theme.accent .. "onStart" .. PIOS.theme.foreground .. " модуля " ..
                                PIOS.theme.accent .. data.name .. PIOS.theme.foreground .. ": " ..
                                PIOS.theme.errorForeground .. moduleResult,
                                "ERROR")
                        end
                    end
                else
                    PIOS.logger(
                        "Ошибка сборки модуля " ..
                        PIOS.theme.accent ..
                        file .. PIOS.theme.foreground .. ": " .. PIOS.theme.errorForeground .. file,
                        "ERROR")
                end
            else
                PIOS.logger("Ошибка сборки модуля " .. PIOS.theme.accent .. file, "ERROR")
            end
        end

        --- Отгружает модуль
        --- @param name string Имя
        --- @param reason string? Причина (по умолчанию unload)
        self.unloadModule = function(name, reason)
            local data
            local index

            local reason = reason or "unload"
            for i, module in ipairs(PIOS.modules) do
                if module.name == name then
                    data = module
                    index = i
                    break
                end
            end

            PIOS.logger(
                "Запуск точки входа " ..
                PIOS.theme.accent ..
                "onStart" ..
                PIOS.theme.foreground ..
                " модуля " .. PIOS.theme.accent .. data.name, "DEBUG")

            local entrypoint = data.onStop
            if entrypoint then
                local valid, moduleResult = pcall(entrypoint, data, reason)
                if not valid then
                    PIOS.logger(
                        "Ошибка точки входа " ..
                        PIOS.theme.accent .. "onStop" .. PIOS.theme.foreground .. " модуля " ..
                        PIOS.theme.accent .. data.name .. PIOS.theme.foreground .. ": " ..
                        PIOS.theme.errorForeground .. moduleResult,
                        "ERROR")
                end
            end

            table.remove(PIOS.modules, index)
            PIOS.logger("Модуль отгружен: " .. PIOS.theme.accent .. data.name, "INFO")
        end

        --- Убивает модуль
        --- @param name string Имя
        self.killModule = function(name)
            local data
            local index
            for i, module in ipairs(PIOS.modules) do
                if module.name == name then
                    data = module
                    index = i
                    break
                end
            end

            table.remove(PIOS.modules, index)
            PIOS.logger("Модуль убит: " .. PIOS.theme.accent .. data.name, "INFO")
        end

        self.addCall("loadModule", self.loadModule)
        self.addCall("unloadModule", self.unloadModule)
        self.addCall("killModule", self.killModule)
    end
}
