аш-лог скрипта
        end

        if PIOS.fs.hasFile("/PIOSError.txt") then
            PIOS.fs.deleteFile("/PIOSError.txt") -- Удаляем краш-лог PIOS
        end
    end

    if initCode then
        PIOS.initProcess = processHost:create(function()
            local env = processlibrary.createEnv()

            function env.setCode(code)
                checkArg(1, code, "string")
                if PIOS.fs and not PIOS.fs.isReadOnly() then
                    if PIOS.fs.hasFile(PIOS.targetFileBin) then
                        PIOS.fs.deleteFile(PIOS.targetFileBin)
                    end

                    if not PIOS.fs.hasFile(PIOS.targetFile) then
                        PIOS.fs.createFile(PIOS.targetFile)
                    end

                    PIOS.fs.writeFile(PIOS.targetFile, code)
                end
                initCode = code
                codeEncrypted = false
            end

            function env.getCode()
                if codeEncrypted and PIOS.supported then -- * Если PIOS поддерживается...
                    return "PIOS.encrypted"              -- Более красивое сообщение
                elseif codeEncrypted then                -- * Иначе...
                    return "THIS CODE WAS ENCRYPTED"     -- Стандартное сообщение
                end
                return initCode
            end

            function env.setData(code)
                if not PIOS.fs.hasFile(PIOS.targetFileDat) then
                    PIOS.fs.createFile(PIOS.targetFileDat)
                end
                PIOS.fs.writeFile(PIOS.targetFileDat, code)
            end

            function env.require(lib)                                       -- Расширенный require: загрузка не только встроенных библиотек, но ещё и пользовательских
                local libraryEncrypted = PIOS.fs.hasFile("/lib/" .. lib .. ".bin")
                if PIOS.fs.hasFile("/lib/" .. lib .. ".lua") then           -- * Если на диске есть такая библиотека...
                    return load(PIOS.fs.readFile("/lib/" .. lib .. ".lua")) -- Загружаем библиотеку с диска
                else                                                        -- * Иначе...
                    return PIOS._system.require(lib)                        -- Загружаем библиотеку из SComputers
                end
            end

            function env.getComponent(name) -- Пользовательская прослойка для getComponent
                local component = PIOS._system.getComponent(name)

                local toAppend = callModulesEntrypoint("requiredComponent", { name, component })
                for _, entry in ipairs(toAppend) do
                    local appendTable = entry.result
                    if type(appendTable) == "table" then
                        for appendName, func in pairs(appendTable) do
                            component[appendName] = func
                        end
                    end
                end

                return component
            end

            function env.getComponents(name) -- Пользовательская прослойка для getComponents
                local components = PIOS._system.getComponents(name)
                local result = {}

                for _, component in ipairs(components) do
                    local toAppend = callModulesEntrypoint("requiredComponent", { name, component })
                    for _, entry in ipairs(toAppend) do
                        local appendTable = entry.result
                        if type(appendTable) == "table" then
                            for appendName, func in pairs(appendTable) do
                                component[appendName] = func
                            end
                        end
                    end

                    table.insert(result, component)
     