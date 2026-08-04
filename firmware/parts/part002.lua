imerHost = timerHost,             -- * Хост таймеров из библиотеки timer
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

    msg = PIOS.theme.foregrou