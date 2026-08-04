--- @diagnostic disable: undefined-global, lowercase-global, undefined-field

local json = require("json")

local rawMetadata = PIOS.RAM.readFile("/metadata.json")
local metadata = json.decode(rawMetadata)

PIOS.logger("--------------------------------------------------", "INFO")
PIOS.logger("Скрипт обновления PIOS до " .. PIOS.theme.accent .. metadata.version, "INFO")
PIOS.logger("1) Скачивание модулей", "INFO")
local modules = {}
for _, module in ipairs(metadata.modules) do
    PIOS.logger("Загрузка: " .. PIOS.theme.accent .. module, "DEBUG")
    local moduleCode = PIOS.httpGet("github.com",
        "/Davidka4444/PIOS/raw/refs/heads/main/" .. metadata.tree.modules .. "/" .. module,
        443)
    modules[module] = moduleCode
end

PIOS.logger("2) Скачивание прошивки", "INFO")
local parts = {}
for part = 1, metadata.tree.firmwarePartsTotal do
    local partFormatted = string.format(metadata.tree.partTemplate, string.format(metadata.tree.partsFormat, part))

    local partString = PIOS.httpGet("github.com",
        "/Davidka4444/PIOS/raw/refs/heads/main/" .. metadata.tree.firmwareParts .. "/" .. partFormatted, 443)
    PIOS.logger(
        "Загружена часть " ..
        PIOS.theme.accent .. part .. "/" .. metadata.tree.firmwarePartsTotal .. PIOS.theme.foreground .. " ()", "DEBUG")
    table.insert(parts, partString)
end

local firmware = ""

for _, part in ipairs(parts) do
    firmware = firmware .. part
end

PIOS.logger("3) Установка обновлений для модулей", "INFO")
local processed = {}
for _, oldModule in ipairs(PIOS.modules) do
    if oldModule.allowPSUP and modules[oldModule.file] then
        PIOS.fs.writeFile("/PIOS/modules/" .. oldModule.file, modules[oldModule.file])
        PIOS.logger("Обновление: " .. PIOS.theme.accent .. oldModule.name, "DEBUG")
    else
        PIOS.logger(
            "Пропуск: " ..
            PIOS.theme.accent .. oldModule.name .. PIOS.theme.foreground .. ": Модуль изменён/добавлен пользователем",
            "DEBUG")
    end

    processed[oldModule.file] = oldModule
end

PIOS.logger("4) Добавление новых модулей", "INFO")
for name, module in pairs(modules) do
    if not processed[name] then
        PIOS.logger("Добавление: " .. PIOS.theme.accent .. name, "DEBUG")
        PIOS.fs.createFile("/PIOS/modules/" .. name)
        PIOS.fs.writeFile("/PIOS/modules/" .. name, module)
    end
end

PIOS.logger("5) Удаление старых модулей", "INFO")
for _, oldModule in ipairs(PIOS.modules) do
    if oldModule.allowPSUP and not modules[oldModule.file] then
        PIOS.fs.deleteFile("/PIOS/modules/" .. oldModule.file)
        PIOS.logger("Удаление: " .. PIOS.theme.accent .. oldModule.name, "DEBUG")
    else
        PIOS.logger(
            "Пропуск: " ..
            PIOS.theme.accent ..
            oldModule.name .. PIOS.theme.foreground .. ": Модуль существует в релизе",
            "DEBUG")
    end
end

PIOS.logger("6) Прошивка", "INFO")
if metadata.encrypted then
    setEncryptedCode(firmware)
else
    setCode(firmware)
end

PIOS.logger("--------------------------------------------------", "INFO")
