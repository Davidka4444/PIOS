�ее за имя",
                            "WARN")
                    end

                    if not data.version then
                        data.version = "0.0"
                        PIOS.logger(
                            "В модуле " ..
                            PIOS.theme.accent ..
                            data.name .. PIOS.theme.foreground .. " не найдено поле отвечающее за версию",
                            "WARN")
                    end

                    if not data.description then
                        data.description = ""
                        PIOS.logger(
                            "В модуле " ..
                            PIOS.theme.accent ..
                            data.name .. PIOS.theme.foreground .. " не найдено поле отвечающее за описание",
                            "WARN")
                    end

                    if data.bootAfter ~= "system" and data.bootAfter ~= "otherModules" then
                        data.bootAfter = "system"
                        PIOS.logger(
                            "В модуле " ..
                            PIOS.theme.accent ..
                            data.name .. PIOS.theme.foreground .. " поле отвечающее за режим запуска неверно",
                            "WARN")
                    end

                    data.addCall = function(name, func)
                        PIOS[name] = func
                        PIOS.logger("Зарегистрирован вызов PIOS: " .. PIOS.theme.accent .. name, "DEBUG")
                    end
                    data.callModulesEntrypoint = callModulesEntrypoint
                    data.loadingTime = startClock - os.clock()
                    data.file = file

                    if data.bootAfter == "system" then
                        table.insert(PIOS.modules, data)
                        PIOS.logger(
                            "Модуль загружен в режиме запуска " ..
                            PIOS.theme.accent .. data.bootAfter .. PIOS.theme.foreground .. ": " ..
                            PIOS.theme.accent .. data.name .. " v" .. data.version ..
                            PIOS.theme.foreground .. ": " .. PIOS.theme.accent .. data.description, "INFO")
                    else
                        table.insert(toBoot, data)
                    end
                else
                    PIOS.logger(
                        "Ошибка сборки модуля " ..
                        PIOS.theme.accent .. file .. PIOS.theme.foreground .. ": " .. PIOS.theme.errorForeground .. file,
                        "ERROR")
                end
            else
                PIOS.logger("Ошибка сборки модуля " .. PIOS.theme.accent .. file, "ERROR")
            end
        end

        for _, data in ipairs(toBoot) do -- * Второй заход: загружаем модули с bootAfter = otherModules
            table.insert(PIOS.modules, data)
            PIOS.logger(
                "Модуль загружен в режиме запуска " ..
                PIOS.theme.accent .. data.bootAfter .. PIOS.theme.foreground .. ": " ..
                PIOS.theme.accent .. data.name .. " v" .. data.version ..
                PIOS.theme.foreground .. ": " .. PIOS.theme.accent .. data.description, "INFO")
        end

        callModulesEntrypoint("onStart")
    end
end

--- Пытается загрузится с дискового устройства
--- @param device table<function>? API Устройства
--- @param type string Тип устройства (rom/disk/dataDisk)
local function tryBoot(device, type)
    local fs

    if type == "rom" then -- * Если устройство - ROM-диск...
        assert(device)

        if device.isAvailable() then          -- * Если ROM-диск правильно настроен...
            fs = device.openFilesystemImage() -- Открываем R