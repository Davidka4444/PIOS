return {
    name = "HttpApi", -- * Имя модуля
    version = "1.0", -- * Версия модуля
    description =
    "Реализация HTTP если установлен Better API", -- * Описание модуля
    bootAfter = "system", -- * После чего запускать модуль (system - после запуска системы, otherModules - после запуска остальных модулей. Полезно, если в модуле используются внешние модули-библиотеки)
    allowPSUP = true, -- * Разрешить PSUP (PIOS Self-Update Protocol) обновлять данный модуль? (для системных модулей - true, для пользовательских - false)

    --- Сериализует таблицу заголовков в строку для sendRequest
    --- @param headers table? {"Content-Type" = "application/json", ...}
    --- @return string
    serializeHeaders = function(headers)
        local out = {}
        for k, v in pairs(headers or {}) do
            table.insert(out, k .. ": " .. tostring(v))
        end
        return table.concat(out, "\r\n")
    end,

    -- # Точки входа
    onStart = function(self) -- * При запуске модуля (включении ПК)...
        --- Отправляет GET-запрос
        --- @param URL string Домен
        --- @param path string Путь (например "/api/data")
        --- @param port? number Порт (по умолчанию 80)
        --- @param headers table? Заголовки
        self.httpGet = function(URL, path, port, headers)
            if not (better and better.network) then
                error("Пожалуйста, установите Better API с модулем BetterNetwork")
            end

            port = port or 80
            path = path or "/"

            local conn = better.network.newConnection(URL, port)
            local req = better.network.newRequest(conn, "GET", path)
            better.network.sendRequest(req, self.serializeHeaders(headers))
            local result = better.network.getResult(req)

            better.network.closeRequest(req)
            better.network.closeConnection(conn)

            return result
        end

        --- Отправляет POST-запрос
        --- @param URL string Домен
        --- @param path string Путь
        --- @param body string|table Тело запроса
        --- @param port? number Порт (по умолчанию 80)
        --- @param headers table? Заголовки
        self.httpPost = function(URL, path, body, port, headers)
            if not (better and better.network) then
                error("Пожалуйста, установите Better API с модулем BetterNetwork")
            end

            port = port or 80
            path = path or "/"
            headers = headers or {}

            local conn = better.network.newConnection(URL, port)

            local req = better.network.newRequest(conn, "POST", path)

            -- Оборачиваем тело в JSON, если передали таблицу
            local bodyStr = type(body) == "table" and require("json").encode(body) or body
            if not headers["Content-Type"] and bodyStr then
                headers["Content-Type"] = "application/json"
            end

            better.network.sendRequest(req, self.serializeHeaders(headers), bodyStr)
            local result = better.network.getResult(req)

            better.network.closeRequest(req)
            better.network.closeConnection(conn)

            return result
        end

        PIOS.env.http = {}
        PIOS.env.http.get = self.httpGet
        PIOS.env.http.post = self.httpPost
        self.addCall("httpGet", self.httpGet)
        self.addCall("httpPost", self.httpPost)
    end
}
