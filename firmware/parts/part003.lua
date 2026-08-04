nd ..
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
    setreg("PIOS.shutdown", true) -- Записывае�