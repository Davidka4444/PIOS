OM как диск
            fs.type = "rom"
        end

        PIOS.logger("Попытка загрузки с ROM-диска...", "INFO")
    elseif type == "disk" then -- * Если устройство - обычный диск...
        assert(device)

        fs = device -- У дисков максимально простое API
        fs.type = "disk" ---@diagnostic disable-line: inject-field

        PIOS.logger("Попытка загрузки с диска...", "INFO")
    elseif type == "dataDisk" then -- * Если устройство - встроенный в ПК диск...
        fs = PIOS.dataFs           -- dataFs загружается при запуске PIOS
        fs.type = "dataDisk" ---@diagnostic disable-line: inject-field

        PIOS.logger("Попытка загрузки со встроенного диска...", "INFO")
    end

    if not fs then
        PIOS.logger("Ошибка ФС", "ERROR")

        return
    end

    local fsSize = fs.getUsedSize()
    if fsSize < 1024 then
        PIOS.logger(
            "Пропуск из-за слишком маленького размера занятого на диске места (" ..
            PIOS.theme.accent .. fsSize .. " байт" .. PIOS.theme.foreground .. ")",
            "WARN")

        return
    end

    if fs.hasFile(PIOS.targetFile) then -- * Если в ФС есть исходный файл...
        initCode = fs.readFile(PIOS.targetFile)
        local _, lines = initCode:gsub("\n", "")
        PIOS.logger(
            "Исходный код успешно загружен в ВМ (" ..
            PIOS.theme.accent .. lines .. " стр." .. PIOS.theme.foreground .. ")",
            "INFO")

        codeEncrypted = false

        PIOS.fs = fs
    elseif fs.hasFile(PIOS.targetFileBin) then -- * Если есть скомпилированный файл...
        initCode = fs.readFile(PIOS.targetFileBin)
        PIOS.logger(
            "Скомпилированный код успешно загружен в ВМ",
            "INFO")

        codeEncrypted = true

        PIOS.fs = fs
    else -- * Иначе...
        PIOS.logger(
            "Не найден файл " ..
            PIOS.theme.accent ..
            PIOS.targetFile .. PIOS.theme.foreground .. " или " .. PIOS.theme.accent .. PIOS.targetFileBin,
            "ERROR")
    end
end

function onStart() -- * При запуске ПК...
    PIOS.clearAll()
    PIOS.doForAllComponents("terminal", function(terminal)
        terminal.clear()
    end)
    setreg("PIOS.power", true) -- Записываем в регистр PIOS.power значение true
    PIOS.logger("PIOS " .. PIOS.theme.accent .. "v" .. PIOS._VERSION, "INFO")

    makeFs()
    PIOS.doForAllComponents("disk", function(disk, i) -- * 1) Пытаемся загрузится с внешнего диска
        if not initCode then
            PIOS.logger("Загрузочный диск: " .. PIOS.theme.accent .. "внешний, №" .. i, "INFO")
            tryBoot(disk, "disk")
        end
    end)

    if not initCode then
        PIOS.logger("Загрузочный диск: " .. PIOS.theme.accent .. "встроенный", "INFO")
        tryBoot(nil, "dataDisk") -- * 2) Пытаемся загрузится со встроенного в ПК диска
    end

    if not initCode then -- * 3) Пытаемся загрузится с ROM-диска
        PIOS.doForAllComponents("rom", function(rom, i)
            if not initCode then
                PIOS.logger("Загрузочный диск: " .. PIOS.theme.accent .. "ROM, №" .. i, "INFO")
                tryBoot(rom, "rom")
            end
        end)
    end

    if PIOS.fs then                            -- * Если мы нашли загружаемый раздел...
        loadTheme(PIOS.fs, "/PIOS/theme.json") -- Пытаемся загрузить тему с него

        if PIOS.fs.hasFile("/error.txt") then
            PIOS.fs.deleteFile("/error.txt") -- Удаляем кр