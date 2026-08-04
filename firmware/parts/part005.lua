fs then
        if not PIOS.fs.hasFile("/error.txt") then -- Создаём краш-лог
            PIOS.fs.createFile("/error.txt")
        end

        PIOS.fs.writeFile("/error.txt", text)
    end

    setreg("PIOS.error", true) -- Записываем в регистр PIOS.error значение true

    PIOS.clearAll()

    local gui = require("gui")
    local styles = require("styles")
    local instances = {}
    local rebootButton
    PIOS.doForAllComponents("display", function(display)
        local w, h = display.getSize()

        local guiInst = gui.new(display)
        table.insert(instances, guiInst)

        if w + h >= 256 then
            local scene   = guiInst:createScene(PIOS.theme.background)

            local labelH  = math.max(12, math.floor(h * 0.04)) -- 4% высоты, но не меньше 12px
            local btnH    = math.max(30, math.floor(h * 0.1))  -- 10% высоты, но не меньше 30px
            local padding = math.max(4, math.floor(w * 0.01))  -- 1% ширины для отступов (опционально)

            scene:createLabel(
                padding, 0,
                w - padding * 2, labelH,
                label,
                PIOS.theme.labelBackground,
                PIOS.theme.labelForeground
            )

            scene:createTextBox(
                padding, labelH,
                w - padding * 2, h - labelH - btnH,
                text,
                PIOS.theme.background,
                PIOS.theme.foreground,
                false, false,
                nil, true, nil
            )

            if type == "error" or type == "PIOSError" then
                rebootButton = scene:createButton(
                    padding, h - btnH,
                    w - padding * 2, btnH,
                    false, "Перезапуск", PIOS.theme.labelBackground, PIOS.theme.foreground, PIOS.theme.accent,
                    PIOS.theme.foreground
                )
            end

            scene:select()
        else
            local scene = guiInst:createScene(PIOS.theme.errorForeground)

            if type == "error" or type == "PIOSError" then
                rebootButton = scene:createButton(
                    0, h / 2,
                    w, h / 2,
                    false, "", PIOS.theme.labelBackground, PIOS.theme.foreground, PIOS.theme.accent,
                    PIOS.theme.foreground
                )
            end

            scene:select()
        end

        rebootButton:setCustomStyle(styles.switch)
        rebootButton:attachCallback(function(self, state, inZone)
            if state then
                reboot()
            end
        end)
    end)

    onTick = function()
        for _, inst in ipairs(instances) do
            inst:tick()

            if inst:needFlush() then
                inst:draw()
                PIOS.doForAllComponents("display", function(display)
                    display.flush()
                end)
            end
        end
    end

    if type == "error" then
        PIOS.logger("Ошибка: " .. PIOS.theme.errorForeground .. text, "ERROR")
    elseif type == "PIOSError" then
        PIOS.logger("Критическая ошибка PIOS: " .. PIOS.theme.errorForeground .. text, "ERROR")
    end
end

--- Пытается загрузить тему
--- @param fs table<function> API файловой системы
--- @param path string Путь
function loadTheme(fs, path)
    if fs.hasFile(path) then
        local themeValid, theme = pcall(json.decode, fs.readFile(path))

        if themeValid then                             -- * Если тема правильная...
            for key, value in pairs(theme) do          -- Совмещаем две темы
                if key == "font" then                  -- * Если ключ - font...
                    if fonts[value] then               -- * Если такой шрифт существует...
                        PIOS.theme.font = fonts[value] -- Заменяем ключ font на шрифт из темы
 