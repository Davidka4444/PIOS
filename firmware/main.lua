--- @diagnostic disable: undefined-global, lowercase-global, undefined-field

--[[
#     ░▒▓███████▓▒░░▒▓█▓▒░░▒▓██████▓▒░ ░▒▓███████▓▒░
#     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░
#     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░
#     ░▒▓███████▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░
#     ░▒▓█▓▒░      ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░
#     ░▒▓█▓▒░      ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░
#     ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓██████▓▒░░▒▓███████▓▒░
#                BIOS в Scrap Mechanic
#    Основано на встроенном примере "bios" в SComputers
--]]

--[[
TODO: Добавить во всех функциях checkArg
TODO: Добавить сетевые функции
    Добавить запуск через сеть
--]]

_enableCallbacks = true -- Включаем новую систему вызовов (onTick вместо callback_loop)
_disableBsod = true     -- Выключаем стандартный BSOD из SComputers

local enlua = require("enlua")
local processlibrary = require("process")
local fonts = require("fonts")
local ramFs = require("ramfs")
local json = require("json")
local startClock = os.clock()
local timerHost = require("timer").createHost()
local initCode
local codeEncrypted
better = global.better

local errorsLocales = {
    {
        "attempt to call global '(.*)' %(a nil value%)",
        'Попытка вызвать несуществующую функцию "%1"',
    },
    { "unexpected symbol near '(.*)'", 'Неожиданный символ около "%1"' },
    { "File (.*) already exists", 'Попытка создать уже существующий файл "%1"' },
    { "'(.*)' expected near '(.*)'", '"%1" ожидалось около "%2"' },
    { "stack overflow", "Переполнение стека" },
    { "bad argument (.*) %((.*) expected, got (.*)%)", "Неправильный аргумент %1: Ожидался тип %2, получен %3" },
    { 'the "(.*)" component is missing', 'Не найден компонент "%1"' },
    { 'the "(.*)" library was not found', 'Не найдена библиотека "%1"' },
    { 'assertion failed!', 'Необходимая переменная оказалась пустой' },
    { '"<eof>"', '<конец файла>' },
    { 'PIOS.testError', "Тестовая ошибка" },
    { 'Unknown Error', "Неизвестная ошибка" },
    { 'Out of Memory!/No Memory.', "Дисковая память закончилась" }
}

PIOS = {                               -- * Настройки PIOS
    supported = false,                 -- * PIOS поддерживается? (в init.lua нужно выполнить PIOS.supported = true)
    targetFile = "/init",              -- * Целевой файл для загрузки
    enableLed = true,                  -- * Разрешить PIOS изменять цвет первого светодиода? (если подключён)
    localeErrors = true,               -- * Применять локализацию к ошибкам?
    autoDisable = true,                -- * Автоматически отключать все компоненты (моторы, светодиоды, и прочие) при выключении?
    printToTerm = true,                -- * Печатать в терминал вместо чата?:
    fs = nil,                          -- * Корневая файловая система
    _VERSION = "0.3.2 BETA",           -- * Версия PIOS
    timerHost = timerHost,             -- * Хост таймеров из библиотеки timer
    RAM = nil,                         -- * ФС в ОЗУ
    dataFs = nil,                      -- * ФС внутри памяти компьютера
    initProcess = nil,                 -- * Исполняемый процесс
    env = nil,                         -- * Среда исполняемого процесса
    startClock = startClock,           -- * Процессорное время когда PIOS был запущен
    lastLogClock = os.clock(),         -- * Процессорное время во время добавления строки в лог
    RAMSize = 2,                       -- * Размер файловой системы в RAM (в килобайтах)
    dataFsSize = 2,                    -- * Размер файловой системы на встроенном диске ПК (в килобайтах)
    theme = {                          -- * Тема PIOS (перезаписывается файлом /PIOS/theme)
        background = "#000000",        -- * Задний план
        foreground = "#ffffff",        -- * Передний план
        errorForeground = "#ff8888",   -- * Передний план для ошибок
        infoForeground = "#8888ff",    -- * Передний план для информационных сообщений
        debugForeground = "#ff88ff",   -- * Передний план для сообщений отладки
        warningForeground = "#ffff88", -- * Передний план для предупреждений
        labelBackground = "#ffffff",   -- * Задний план заголовка
        labelForeground = "#000000",   -- * Передний план заголовка
        powerLed = "#8888ff",          -- * Цвет индикатора при работе ПК
        errorLed = "#ff8888",          -- * Цвет индикатора при ошибке
        sleepLed = "#88ffff",          -- * Цвет индикатора в спящем режиме (пока не реализовано)
        accent = "#ffff88",            -- * Акцентный цвет
        font = fonts.lgc_5x4,          -- * Шрифт PIOS
    },
    modules = {},                      -- * Хранилище для всех модулей
    debug = {                          -- * Расширенные настройки для отладки PIOS/скриптов
        doNotSaveFs = false,           -- * Не сохранять встроенную ФС при выключении?
        flushFs = false,               -- * Форсированно создать новую встроенную ФС при включении?
        debugMsg = true,               -- * Отображать в логе отладочные сообщения?
        flushData = false              -- * Сбрасывать информацию ВМ при выключении?
    },
    _system = {                        -- * Системное. Не трогать
        require = require,
        reboot = reboot,
        getComponent = getComponent,
        getComponents = getComponents
    },
}

PIOS.chat = print
PIOS.targetFileBin = PIOS.targetFile .. ".bin"
PIOS.targetFileDat = PIOS.targetFile .. ".dat"
PIOS.targetFile = PIOS.targetFile .. ".lua"

--- Логирование
--- @param msg string Сообщение
--- @param level string Уровень (INFO/WARN/ERROR/DEBUG)
function PIOS.logger(msg, level)
    local color

    checkArg(1, msg, "string")
    checkArg(2, level, "string")

    if level == "DEBUG" and not PIOS.debug.debugMsg then return end

    if level == "INFO" then
        color = PIOS.theme.infoForeground
    elseif
        level == "WARN" then
        color = PIOS.theme.warningForeground
    elseif
        level == "ERROR" then
        color = PIOS.theme.errorForeground
    elseif
        level == "DEBUG" then
        color = PIOS.theme.debugForeground
    end

    msg = PIOS.theme.foreground ..
        "[" ..
        color ..
        level ..
        PIOS.theme.foreground ..
        "; UPT - " ..
        PIOS.theme.accent ..
        string.format("%.2f", os.clock() - PIOS.startClock) ..
        PIOS.theme.foreground ..
        "; AFT " ..
        PIOS.theme.accent ..
        string.format("%.2f", os.clock() - PIOS.lastLogClock) .. PIOS.theme.foreground .. "] " .. msg

    log(msg)

    PIOS.doForAllComponents("terminal", function(terminal)
        terminal.write(msg .. "\n")
    end)

    PIOS.lastLogClock = os.clock()
end

--- Получает расширение файла
--- @param filename string Имя файла
--- @return string extension Расширение
function PIOS.getFileExtension(filename)
    return string.match(filename, "%.([^%.]+)$")
end

--- Создаёт файловые системы
local function makeFs()
    local dataFs
    local PCData = getData()

    if PIOS.debug.flushFs then
        PIOS.logger("В настройках отладки форсирована очистка встроенной ФС", "WARN")
    end

    if (not PIOS.debug.flushFs) and pcall(json.decode, PCData) then -- * Если во встроенном хранилище ПК есть ФС + выключен PIOS.debug.flushFs...
        dataFs = ramFs.load(PCData)                                 -- Загружаем ФС из памяти
        PIOS.logger("Встроенная ФС загружена", "INFO")
    else                                                            -- * Иначе...
        dataFs = ramFs.create(1024 * PIOS.dataFsSize)               -- Создаём новую ФС
        PIOS.logger("Создана новая встроенная ФС", "WARN")
    end

    local RAM = ramFs.create(1024 * PIOS.RAMSize)
    PIOS.logger("ФС в ОЗУ создана", "INFO")
    PIOS.dataFs = dataFs.fs
    PIOS.RAM = RAM.fs
    PIOS.predataFs = dataFs
    PIOS.preRAM = RAM
end

--- Выполняет функцию для всех компонентов
--- @param components string Имя компонентов
--- @param func function Функция для каждого компонента (первый аргумент - компонент, второй - индекс)
function PIOS.doForAllComponents(components, func)
    checkArg(1, components, "string")
    checkArg(1, func, "function")

    for index, component in ipairs(getComponents(components)) do
        func(component, index)
    end
end

--- Выполняет функцию для всех светодиодов
--- @param leds table<function> API светодиодов
--- @param func function Функция для каждого светодиода
function PIOS.doForAllLeds(leds, func)
    for i = 0, leds.getStripLength() - 1 do
        func(i)
    end
end

--- Вызывает ошибку, если модуль PIOS не установлен
--- @param targetModule string Имя модуля
function PIOS.requireModule(targetModule)
    local hasModule = false

    for _, module in ipairs(PIOS.modules) do
        if module.name == targetModule then
            hasModule = true

            break
        end
    end

    if not hasModule then
        error("Не найден модуль " .. targetModule)
    end
end

--- Выполняет функцию для всех поршней
--- @param pistons userdata Поршни
--- @param func function Функция для каждого поршня
function PIOS.doForAllPistons(pistons, func)
    for i = 0, pistons.getPistonsCount() - 1 do
        func(i)
    end
end

--- Выключает ПК, или отображает сообщение "Система остановлена. Пожалуйста отключите компьютер от питания"
function PIOS.shutdown()
    PIOS.initProcess:destroy() -- Убиваем ВМ
    PIOS.initProcess = nil

    -- * Если подключено управление питанием с ПК (отдельная небольшая схема)...
    setreg("PIOS.shutdown", true) -- Записываем в регистр PIOS.shutdown значение true
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

    if PIOS.fs then
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
                            data.name .. PIOS.theme.foreground .. " не найдено поле отвечающее за имя",
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
            fs = device.openFilesystemImage() -- Открываем ROM как диск
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
            PIOS.fs.deleteFile("/error.txt") -- Удаляем краш-лог скрипта
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

function onStop() -- * При остановке ПК...
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
