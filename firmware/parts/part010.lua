           end

                return result
            end

            function env.getData()
                if not PIOS.fs.hasFile(PIOS.targetFileDat) then
                    PIOS.fs.createFile(PIOS.targetFileDat)
                end

                return PIOS.fs.readFile(PIOS.targetFileDat)
            end

            env.exit = PIOS.shutdown

            function env.setEncryptedCode(bytecode, message)
                checkArg(1, bytecode, "string")
                checkArg(2, message, "string", "nil")
                if PIOS.fs and not PIOS.fs.isReadOnly() then
                    if not PIOS.fs.hasFile(PIOS.targetFileBin) then
                        PIOS.fs.createFile(PIOS.targetFileBin)
                    end

                    if PIOS.fs.hasFile(PIOS.targetFile) then
                        PIOS.fs.deleteFile(PIOS.targetFile)
                    end

                    PIOS.fs.writeFile(PIOS.targetFileBin, bytecode)
                end
                codeEncrypted = true
            end

            function env.encryptCode(message)
                checkArg(1, message, "string", "nil")
                if codeEncrypted then
                    return false
                end

                local bytecode = enlua.compile(initCode)
                if bytecode then
                    if PIOS.fs and not PIOS.fs.isReadOnly() then
                        if not PIOS.fs.hasFile(PIOS.targetFileBin) then
                            PIOS.fs.createFile(PIOS.targetFileBin)
                        end

                        if PIOS.fs.hasFile(PIOS.targetFile) then
                            PIOS.fs.deleteFile(PIOS.targetFile)
                        end

                        PIOS.fs.writeFile(PIOS.targetFileBin, bytecode)
                    end
                    codeEncrypted = true
                    return true
                end
                return false
            end

            function env.isCodeEncrypted()
                return codeEncrypted
            end

            function env.print(text)
                text = tostring(text)
                if PIOS.printToTerm then
                    PIOS.logger("ВМ: " .. text, "INFO")
                else
                    PIOS.chat(text)
                end
            end

            env.safe = safe
            env.PIOS = PIOS
            PIOS.env = env

            return env
        end)

        loadModules(PIOS.fs)

        if codeEncrypted then
            PIOS.initProcess:enluaLoad(initCode, nil, nil, "--PIOS.started", "--binary")
            PIOS.logger("Запущен скомпилированный код из " .. PIOS.theme.accent .. PIOS.targetFileBin, "INFO")
        else
            PIOS.initProcess:load(initCode, nil, nil, "--PIOS.started", "--source")
            PIOS.logger("Запущен исходный код из " .. PIOS.theme.accent .. PIOS.targetFile, "INFO")
        end

        if PIOS.enableLed then
            PIOS.doForAllComponents("led", function(leds)
                leds.setColor(0, PIOS.theme.powerLed)
            end)
        end
    else
        PIOS._system.msg("Раздел не найден", "Не найден загружаемый раздел", "error")
    end
end

function onTick() -- * Каждый тик...
    timerHost:tick()
    processHost:tick()
    if PIOS.initProcess then
        local error = PIOS.initProcess:getError()
        if error then                  -- * При ошибке ВМ...
            PIOS.initProcess:destroy() -- Убиваем ВМ
            PIOS.initProcess = nil

            PIOS._system.msg("Ошибка", error, "error") -- Отображаем сообщение о ошибке
        end

        callModulesEntrypoint("onTick", nil, true)
        setreg("PIOS.tick", getUptime())       -- Записываем в регистр PIOS.tick текущий аптайм
        setreg("PIOS.lagScore", getLagScore()) -- Записываем в регистр PIOS.lagScore число счётчика лагов
    end
end

function onStop() -- * При ос�