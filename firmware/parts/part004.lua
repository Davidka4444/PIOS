� в регистр PIOS.shutdown значение true
    setreg("PIOS.power", false)   -- Записываем в регистр PIOS.powerLed значение false

    -- * Иначе...
    PIOS._system.msg(
        "Выключение", "Система остановлена. Пожалуйста отключите компьютер от питания", "shutdown") -- Отображаем сообщение
end

--- Перезагружает ПК
function PIOS.reboot()
    PIOS._system.reboot()
end

--- Выполняет функцию, но не вылетает, если функция выдала ошибку (по сути, это pcall, который возвращает первым аргументом не false/true, а сразу результат)
--- @param func function|string Функция
--- @param ... any Аргументы
--- @return false|any result Результат (false - ошибка)
function safe(func, ...)
    local fn
    local args = table.pack(...)
    if type(func) == "function" then
        fn = func
    elseif type(func) == "string" then
        fn = load(func)
    end

    if fn then
        local valid, result = pcall(fn, args)

        if valid then
            return result
        else
            return false
        end
    else
        return false
    end
end

local processHost = processlibrary.createHost()
--- Очищает экраны
function PIOS._system.clear()
    PIOS.doForAllComponents("display", function(display)
        display.reset()
        display.clear()
        display.setFont(PIOS.theme.font) -- Устанавливаем шрифт темы PIOS
        display.setFontScale(display.getWidth() / 256, display.getHeight() / 256)
        display.setUtf8Support(true)
        display.setSkipAtNotSight(true)
        display.setClicksAllowed(true)
        display.flush()
    end)

    --[[
    // PIOS.doForAllComponents("terminal", function(terminal)
    //    terminal.clear()
    // end)
    --]]
end

--- Автоматически сбрасывает все компоненты
function PIOS.clearAll()
    clearregs()

    PIOS.doForAllComponents("antenna", function(antenna)
        antenna.setActive(false)
    end)

    PIOS.doForAllComponents("port", function(port)
        port.clear()
    end)

    PIOS.doForAllComponents("keyboard", function(keyboard)
        keyboard.clear()
        keyboard.resetButtons()
        keyboard.closeGui()
    end)

    PIOS.doForAllComponents("led", function(leds)
        PIOS.doForAllLeds(leds, function(led)
            leds.setColor(led, "#000000")
            leds.setGlow(led, 0.5)
        end)
    end)

    PIOS.doForAllComponents("inertialEngine", function(inertialEngine)
        inertialEngine.setActive(false)
    end)

    PIOS.doForAllComponents("motor", function(motor)
        motor.setActive(false)
    end)

    PIOS.doForAllComponents("holoprojector", function(holoprojector)
        holoprojector.reset()
        holoprojector.clear()
        holoprojector.flush()
    end)

    PIOS.doForAllComponents("synthesizer", function(synthesizer)
        synthesizer.stop()
    end)

    PIOS.doForAllComponents("pistonController", function(pistonController)
        PIOS.doForAllPistons(pistonController, function(piston)
            pistonController.setLength(piston, 0)
        end)
    end)

    PIOS._system.clear()
end

--- Отображает сообщение
--- @param label string Заголовок
--- @param text string Сообщение
--- @param type string Тип (shutdown/error/PIOSError)
function PIOS._system.msg(label, text, type)
    text = string.gsub(text, "#", "N.")

    if PIOS.localeErrors then
        for _, locale in ipairs(errorsLocales) do
            text = string.gsub(text, locale[1], locale[2])
        end
    end

    if PIOS.enableLed then
        PIOS.doForAllComponents("led", function(leds)
            leds.setColor(0, PIOS.theme.errorLed)
        end)
    end

    PIOS.doForAllComponents("synthesizer", function(synthesizer)
        synthesizer.hornBeep(1)
    end)

    if PIOS.