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
    t