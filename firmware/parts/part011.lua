�ановке ПК...
    callModulesEntrypoint("onStop", "PCStop")

    if not PIOS.debug.doNotSaveFs then
        setData(PIOS.predataFs:dump()) -- Сохраняем встроенную ФС
        PIOS.logger("Встроенная ФС сохранена", "INFO")
    else
        PIOS.logger("В настройках отладки форсированно выключено сохранение встроенной ФС", "WARN")
    end

    if PIOS.debug.flushData and PIOS.fs.hasFile(PIOS.targetFileDat) then
        PIOS.logger("В настройках отладки форсированно включен сброс данных ВМ при выключении", "WARN")
        PIOS.fs.deleteFile(PIOS.targetFileDat)
    end

    if PIOS.enableLed then
        PIOS.doForAllComponents("led", function(leds)
            leds.setColor(0, "#000000") -- Выключаем светодиод
        end)
    end

    if PIOS.autoDisable then
        PIOS.clearAll()
    end

    processHost:stop()

    PIOS.logger("ВМ остановлена", "INFO")
end

function onError(err) -- * Если возникла необработанная ошибка PIOS...
    callModulesEntrypoint("onError", err)
    if not PIOS.fs then return end

    if not PIOS.fs.hasFile("/PIOSError.txt") then
        PIOS.fs.createFile("/PIOSError.txt") -- Создаём краш-лог
    end
    PIOS.fs.writeFile("/PIOSError.txt", err) -- Записываем в него ошибку
    onStop()

    setreg("PIOS.loaderException", true) -- Записываем в регистр PIOS.loaderException значение true
end
