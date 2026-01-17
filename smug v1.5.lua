script_name("SmugHelper by Howard")
script_author("Howard")
script_version("1.5")

require "lib.moonloader"
local imgui = require "imgui"
local encoding = require "encoding"
encoding.default = "CP1251"
u8 = encoding.UTF8

-- Основные переменные
local mainMenu = imgui.ImBool(false)
local imguiMenu = 1

-- Переменные для биндов
local bindMode = false
local selectedCommand = ""
local currentBind = ""
local commandBinds = {
    ["/lds"] = "",
    ["/del"] = "", 
    ["/dp"] = "",
    ["/gss"] = "",
    ["/gdd"]= "",
    ["/sgh"] = ""  -- Новый бинд для поиска дома/отеля
}

-- Статистика
local smugStats = {
    totalDeliveries = 0,
    totalEarned = 0,
    lastDelivery = 0,
    sessionEarned = 0,
    todayEarned = 0,
    deliveriesToday = 0,
    lastResetDate = os.date("%d")
}

-- Конфигурация для времени контрабанды
local smugConfig = {
    startTime = "14:00",
    endTime = "22:00",
    notificationsEnabled = true
}

-- Переменные для времени контрабанды
local smugStartTime = "14:00"
local smugEndTime = "22:00"

-- Уведомления и таймеры
local notificationsEnabled = true
local nextSmugNotification = nil
local notificationTimer = 0
local showNotification = false
local notificationText = ""
local notificationDisplayTime = 0

-- ArmorCD переменные - таймер перезарядки
local armorcd = {
    enabled = true,
    last_dmg_time = os.clock(),
    check_auto_take = false,
    move = false,
    renderposX = 0,
    renderposY = 0,
    settings = {
        render = {
            active = true,
            autoarm = true,
            renderX = 1100,
            renderY = 300,
            renderSX = 60,
            renderSY = 10,
            show_secs = true,
        }
    }
}

-- Переменные для поиска дома/отеля
local houseSearchEnabled = false
local lastHouseSearchTime = 0

-- Создание директорий
if not doesDirectoryExist(getWorkingDirectory().."/config") then
    createDirectory(getWorkingDirectory().."/config")
end
if not doesDirectoryExist(getWorkingDirectory().."/config/SmugHelper") then
    createDirectory(getWorkingDirectory().."/config/SmugHelper")
end

-- Загрузка биндов (сохраненные)
if doesFileExist(getWorkingDirectory().."/config/SmugHelper/binds.json") then
    local file = io.open(getWorkingDirectory().."/config/SmugHelper/binds.json", "r")
    if file then
        local content = file:read("*a")
        if content and content ~= "" then
            local loaded = decodeJson(content)
            if loaded then
                commandBinds = loaded
            end
        end
        io.close(file)
    end
end

-- Загрузка конфигурации ArmorCD
if doesFileExist(getWorkingDirectory().."/config/SmugHelper/armorcd.json") then
    local file = io.open(getWorkingDirectory().."/config/SmugHelper/armorcd.json", "r")
    if file then
        local loaded = decodeJson(file:read("*a"))
        if loaded then
            armorcd.settings = loaded
            armorcd.enabled = armorcd.settings.render.active
        end
        io.close(file)
    end
end

-- Загрузка конфигурации дома
if doesFileExist(getWorkingDirectory().."/config/SmugHelper/house_search.json") then
    local file = io.open(getWorkingDirectory().."/config/SmugHelper/house_search.json", "r")
    if file then
        local loaded = decodeJson(file:read("*a"))
        if loaded then
            houseSearchEnabled = loaded.enabled or false
        end
        io.close(file)
    end
end

-- Функция для сохранения конфигурации дома
function saveHouseConfig()
    local config = { enabled = houseSearchEnabled }
    local file = io.open(getWorkingDirectory().."/config/SmugHelper/house_search.json", "w")
    if file then
        file:write(encodeJson(config))
        file:close()
        return true
    end
    return false
end

-- Таблица для названий клавиш
local keyNames = {
    [1] = "LMB", [2] = "RMB", [4] = "MMB",
    [8] = "BACKSPACE", [9] = "TAB", [13] = "ENTER",
    [16] = "SHIFT", [17] = "CTRL", [18] = "ALT",
    [19] = "PAUSE", [20] = "CAPS", [27] = "ESC",
    [32] = "SPACE", [33] = "PGUP", [34] = "PGDN",
    [35] = "END", [36] = "HOME", [37] = "LEFT",
    [38] = "UP", [39] = "RIGHT", [40] = "DOWN",
    [45] = "INSERT", [46] = "DELETE",
    [48] = "0", [49] = "1", [50] = "2", [51] = "3", [52] = "4",
    [53] = "5", [54] = "6", [55] = "7", [56] = "8", [57] = "9",
    [65] = "A", [66] = "B", [67] = "C", [68] = "D", [69] = "E",
    [70] = "F", [71] = "G", [72] = "H", [73] = "I", [74] = "J",
    [75] = "K", [76] = "L", [77] = "M", [78] = "N", [79] = "O",
    [80] = "P", [81] = "Q", [82] = "R", [83] = "S", [84] = "T",
    [85] = "U", [86] = "V", [87] = "W", [88] = "X", [89] = "Y",
    [90] = "Z",
    [96] = "NUM0", [97] = "NUM1", [98] = "NUM2", [99] = "NUM3",
    [100] = "NUM4", [101] = "NUM5", [102] = "NUM6", [103] = "NUM7",
    [104] = "NUM8", [105] = "NUM9",
    [106] = "NUM*", [107] = "NUM+", [109] = "NUM-", [110] = "NUM.",
    [111] = "NUM/",
    [112] = "F1", [113] = "F2", [114] = "F3", [115] = "F4",
    [116] = "F5", [117] = "F6", [118] = "F7", [119] = "F8",
    [120] = "F9", [121] = "F10", [122] = "F11", [123] = "F12"
}

-- Функция для получения названия клавиши
function getKeyName(keyCode)
    if keyCode == nil then
        return "Unknown key"
    end
    return keyNames[keyCode] or "Key " .. keyCode
end

-- Функция для проверки активности чата
function isChatActive()
    return sampIsChatInputActive() or sampIsDialogActive()
end

-- Загрузка конфигурации контрабанды
function loadSmugConfig()
    if doesFileExist(getWorkingDirectory().."/config/SmugHelper/smug_config.json") then
        local file = io.open(getWorkingDirectory().."/config/SmugHelper/smug_config.json", "r")
        if file then
            local loaded = decodeJson(file:read("*a"))
            if loaded then
                smugConfig = loaded
                smugStartTime = smugConfig.startTime
                smugEndTime = smugConfig.endTime
                notificationsEnabled = smugConfig.notificationsEnabled or true
            end
            io.close(file)
        end
    end
end

-- Сохранение конфигурации контрабанды
function saveSmugConfig()
    local file = io.open(getWorkingDirectory().."/config/SmugHelper/smug_config.json", "w")
    if file then
        file:write(encodeJson(smugConfig))
        file:close()
        return true
    end
    return false
end

-- Функция для проверки валидности времени в формате ЧЧ:ММ
function isValidTime(timeStr)
    if not timeStr or type(timeStr) ~= "string" then
        return false
    end
    
    local hour, minute
    
    hour, minute = timeStr:match("^(%d?%d):(%d%d)$")
    if not hour then
        hour, minute = timeStr:match("^(%d%d)(%d%d)$")
    end
    if not hour then
        hour, minute = timeStr:match("^(%d)(%d%d)$")
    end
    
    if not hour or not minute then
        return false
    end
    
    hour = tonumber(hour)
    minute = tonumber(minute)
    
    return hour and minute and hour >= 0 and hour <= 24 and minute >= 0 and minute <= 59
end

-- Функция для нормализации времени в формат ЧЧ:ММ
function normalizeTime(timeStr)
    if not isValidTime(timeStr) then
        return timeStr
    end
    
    local hour, minute
    
    hour, minute = timeStr:match("^(%d?%d):(%d%d)$")
    if not hour then
        hour, minute = timeStr:match("^(%d%d)(%d%d)$")
    end
    if not hour then
        hour, minute = timeStr:match("^(%d)(%d%d)$")
    end
    
    if #hour == 1 then
        hour = "0" .. hour
    end
    
    return hour .. ":" .. minute
end

-- Функция для преобразования времени в минуты
function timeToMinutes(timeStr)
    if not isValidTime(timeStr) then
        return 0
    end
    
    local normalized = normalizeTime(timeStr)
    local hour, minute = normalized:match("^(%d%d):(%d%d)$")
    return tonumber(hour) * 60 + tonumber(minute)
end

-- Функция для преобразования минут в время
function minutesToTime(minutes)
    local hour = math.floor(minutes / 60)
    local minute = minutes % 60
    return string.format("%02d:%02d", hour, minute)
end

-- Сохранение статистики
function saveStats()
    local file = io.open(getWorkingDirectory().."/config/SmugHelper/stats.json", "w")
    if file then
        file:write(encodeJson(smugStats))
        file:close()
        return true
    end
    return false
end

-- Загрузка статистики
function loadStats()
    if doesFileExist(getWorkingDirectory().."/config/SmugHelper/stats.json") then
        local file = io.open(getWorkingDirectory().."/config/SmugHelper/stats.json", "r")
        if file then
            local loaded = decodeJson(file:read("*a"))
            if loaded then
                smugStats = loaded
                
                local currentDate = os.date("%d")
                if currentDate ~= smugStats.lastResetDate then
                    smugStats.todayEarned = 0
                    smugStats.deliveriesToday = 0
                    smugStats.lastResetDate = currentDate
                    saveStats()
                end
            end
            io.close(file)
        end
    end
end

-- Обработка биндов
function processBinds()
    for command, bind in pairs(commandBinds) do
        if bind ~= "" and isKeyJustPressed(bind) then
            if command == "/lds" then
                local closestId = getClosestPlayer()
                if closestId ~= -1 then
                    sampSendChat('/loadsmug '..closestId)
                    sampAddChatMessage("{FF69B4}[SmugHelper] {FFFFFF}Bind "..command.." activated! ID: "..closestId, -1)
                else
                    sampAddChatMessage("{FF69B4}[SmugHelper] {FFFFFF}Bind "..command..": no players nearby", -1)
                end
            elseif command == "/del" then
                sampSendChat('/deliversmug')
                sampAddChatMessage("{FF69B4}[SmugHelper] {FFFFFF}Bind "..command.." activated!", -1)
            elseif command == "/dp" then
                sampSendChat('/dropsmug')
                sampAddChatMessage("{FF69B4}[SmugHelper] {FFFFFF}Bind "..command.." activated!", -1)
            elseif command == "/gdd" then
                sampSendChat('/gps groundsmug')
                sampAddChatMessage("{FF69B4}[SmugHelper] {FFFFFF}Bind "..command.." activated!", -1)
            elseif command == "/gss" then
               sampSendChat('/gps seasmug')
                sampAddChatMessage("{FF69B4}[SmugHelper] {FFFFFF}Bind "..command.." activated!", -1)
            elseif command == "/sgh" then
                searchHouseOrHotel()
                sampAddChatMessage("{FF69B4}[SmugHelper] {FFFFFF}Bind "..command.." activated!", -1)
            end
        end
    end
end

-- Сохранение биндов
function saveBinds()
    local file = io.open(getWorkingDirectory().."/config/SmugHelper/binds.json", "w")
    if file then
        file:write(encodeJson(commandBinds))
        file:close()
        return true
    end
    return false
end

-- Сохранение конфигурации ArmorCD
function saveArmorCD()
    local file = io.open(getWorkingDirectory().."/config/SmugHelper/armorcd.json", "w")
    if file then
        file:write(encodeJson(armorcd.settings))
        file:close()
        return true
    end
    return false
end

-- Удаление бинда
function removeBind(command)
    if commandBinds[command] then
        commandBinds[command] = ""
        saveBinds()
        sampAddChatMessage("{FF69B4}[SmugHelper] {FFFFFF}Bind for "..command.." removed!", -1)
        return true
    end
    return false
end

-- Функция для получения расписания контрабанды
function getSmugSchedule()
    local weekday = os.date("%w")
    local isWeekend = (weekday == "0" or weekday == "6")
    local currentTime = os.date("%H:%M")
    
    local schedule = {}
    
    if not isValidTime(smugStartTime) or not isValidTime(smugEndTime) then
        return schedule, isWeekend, currentTime
    end
    
    local startMinutes = timeToMinutes(smugStartTime)
    local endMinutes = timeToMinutes(smugEndTime)
    
    local currentMinutes = startMinutes
    
    local smugType = "Ground"
    local smugCount = 0
    
    while true do
        local timeString = minutesToTime(currentMinutes)
        
        table.insert(schedule, {
            time = timeString,
            type = smugType
        })
        
        smugCount = smugCount + 1
        if smugType == "Ground" and smugCount >= 2 then
            smugType = "Sea"
            smugCount = 0
        elseif smugType == "Sea" then
            smugType = "Ground"
            smugCount = 0
        end
        
        currentMinutes = currentMinutes + 30
        
        if currentMinutes > endMinutes then
            break
        end
        
        if #schedule > 50 then
            break
        end
    end
    
    return schedule, isWeekend, currentTime
end

-- Поиск следующей контрабанды
function findNextSmug(schedule, currentTime)
    if not isValidTime(currentTime) then
        return nil, 0
    end
    
    local currentMinutes = timeToMinutes(currentTime)
    
    for i, smug in ipairs(schedule) do
        local smugMinutes = timeToMinutes(smug.time)
        
        if smugMinutes > currentMinutes then
            return smug, i
        end
    end
    
    return nil, 0
end

-- Функция для показа уведомления о контрабанде
function showSmugNotification(smug)
    if not smug then return end
    
    notificationText = string.format("~>~ Next smug: %s - %s ~<~", smug.time, smug.type)
    showNotification = true
    notificationDisplayTime = os.clock()
    
    lua_thread.create(function()
        wait(10000)
        showNotification = false
    end)
end

-- Функция для проверки уведомлений
function checkNotifications()
    if not notificationsEnabled then return end
    
    local schedule, isWeekend, currentTime = getSmugSchedule()
    local nextSmug, nextIndex = findNextSmug(schedule, currentTime)
    
    if nextSmug then
        local currentMinutes = timeToMinutes(currentTime)
        local nextMinutes = timeToMinutes(nextSmug.time)
        local timeUntil = nextMinutes - currentMinutes
        
        if timeUntil <= 5 and timeUntil > 0 then
            if not nextSmugNotification or nextSmugNotification.time ~= nextSmug.time then
                nextSmugNotification = nextSmug
                showSmugNotification(nextSmug)
                sampAddChatMessage("{FF69B4}[Notification] {FFFFFF}Next smug in " .. timeUntil .. " min: " .. nextSmug.time .. " - " .. nextSmug.type, -1)
            end
        end
    end
end

-- Форматирование денег
function formatMoney(amount)
    if not amount or amount == 0 then return "0" end
    local formatted = tostring(amount)
    local k = string.len(formatted) - 3
    while k > 0 do
        formatted = string.sub(formatted, 1, k) .. "," .. string.sub(formatted, k + 1)
        k = k - 3
    end
    return formatted
end

-- Поиск ближайшего игрока
function getClosestPlayer()
    local maxDist = 10.0
    local closestPlayer = -1
    local myPosX, myPosY, myPosZ = getCharCoordinates(PLAYER_PED)
    
    for i = 0, 1004 do
        if sampIsPlayerConnected(i) and not sampIsPlayerNpc(i) then
            local result, handle = sampGetCharHandleBySampPlayerId(i)
            if result and doesCharExist(handle) then
                local playerPosX, playerPosY, playerPosZ = getCharCoordinates(handle)
                local dist = getDistanceBetweenCoords3d(myPosX, myPosY, myPosZ, playerPosX, playerPosY, playerPosZ)
                if dist < maxDist then
                    maxDist, closestPlayer = dist, i
                end
            end
        end
    end
    return closestPlayer
end

-- Функция для поиска дома или отеля
function searchHouseOrHotel()
    local currentTime = os.clock()
    if currentTime - lastHouseSearchTime < 2.0 then
        return
    end
    lastHouseSearchTime = currentTime
    
    -- Открываем диалог поиска домов
    sampSendChat("/searchhouse")
    
    -- Ждем немного перед проверкой диалога
    lua_thread.create(function()
        wait(500)
        
        local dialogId = sampGetCurrentDialogId()
        local dialogType = sampGetCurrentDialogType()
        local dialogTitle = sampGetCurrentDialogTitle()
        
        if dialogId == 2110 and dialogTitle:find("Поиск выставленных на продажу домов") then
            -- Закрываем диалог поиска домов
            sampSendDialogResponse(2110, 0, -1, "")
            
            -- Проверяем расстояние до ближайшего дома
            local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
            local houseFound = false
            
            -- Координаты некоторых отелей (примерные)
            local hotels = {
                {x = 218.0, y = -114.0, z = 1.5, name = "Отель в LS"},
                {x = 2218.0, y = -114.0, z = 1.5, name = "Отель в SF"},
                {x = 1418.0, y = -1114.0, z = 1.5, name = "Отель в LV"}
            }
            
            -- Ищем ближайший отель
            local closestHotel = nil
            local minHotelDist = 9999.0
            
            for _, hotel in ipairs(hotels) do
                local dist = getDistanceBetweenCoords3d(myX, myY, myZ, hotel.x, hotel.y, hotel.z)
                if dist < minHotelDist then
                    minHotelDist = dist
                    closestHotel = hotel
                end
            end
            
            -- Если ближайший отель достаточно близко, используем его
            if closestHotel and minHotelDist < 1000.0 then
                sampSendChat("/gps 218")
                sampAddChatMessage("{FF69B4}[HouseSearch] {FFFFFF}Ближайший отель найден! Прокладываю маршрут...", -1)
            else
                sampAddChatMessage("{FF69B4}[HouseSearch] {FFFFFF}Дома далеко, используйте /searchhouse для ручного поиска", -1)
            end
        else
            sampAddChatMessage("{FF69B4}[HouseSearch] {FFFFFF}Используйте /searchhouse для поиска домов", -1)
        end
    end)
end

-- ArmorCD рендер - таймер перезарядки
function armorcd_render()
    if not armorcd.enabled then return end
    
    local settings = armorcd.settings.render
    if not settings.active then return end
    
    local clc = os.clock()
    if clc - armorcd.last_dmg_time < 15 then
        renderDrawBox(settings.renderX - 2, settings.renderY - 2, settings.renderSX + 4, settings.renderSY + 4, 0xA0000000)
        renderDrawBox(settings.renderX, settings.renderY, settings.renderSX, settings.renderSY, 0xAA013220)
        renderDrawBox(settings.renderX, settings.renderY,  0 + ((clc - armorcd.last_dmg_time) * (settings.renderSX / 15)), settings.renderSY, 0xAA00CC00)
        if settings.show_secs then	
            renderDrawBox(settings.renderX + (settings.renderSX + 5), settings.renderY - 2, 25, settings.renderSY + 4, 0xA0000000)
            renderFontDrawText(font,string.format('{00CCD0}%0.1f', 15 - (clc - armorcd.last_dmg_time)), settings.renderX + (settings.renderSX + 6), settings.renderY - 2, -1)
        end 
    elseif armorcd.check_auto_take and settings.autoarm then
        sampSendChat('/hide armor')
        sampSendChat('/take armor')
        armorcd.check_auto_take = false
    end
end

-- Функция для перемещения ArmorCD
function armorcd_mover()
    if armorcd.move then
        showCursor(true, true)
        armorcd.renderposX, armorcd.renderposY = getCursorPos()
        armorcd_render_move()
        if isKeyJustPressed(0x02) then
            showCursor(false, false)
            armorcd.move = false
        end
        if isKeyJustPressed(0x01) then
            local posX, posY = getCursorPos()
            showCursor(false, false)
            armorcd.move = false
            armorcd.settings.render.renderX = posX
            armorcd.settings.render.renderY = posY
            saveArmorCD()
            sampAddChatMessage("{FF69B4}[ArmorCD] {FFFFFF}Position saved. X: "..tostring(posX).." Y: "..tostring(posY), -1)
        end
    end
end

-- Функция для рендера при перемещении
function armorcd_render_move()
    local settings = armorcd.settings.render
    renderDrawBox(armorcd.renderposX - 2, armorcd.renderposY - 2, settings.renderSX + 4, settings.renderSY + 4, 0xA0000000)
    renderDrawBox(armorcd.renderposX, armorcd.renderposY, settings.renderSX, settings.renderSY, 0xAA013220)
    renderDrawBox(armorcd.renderposX, armorcd.renderposY, settings.renderSX - ((os.clock() - 8.333) * 4), settings.renderSY, 0xAA00CC00)
    if settings.show_secs then
        renderDrawBox(armorcd.renderposX + (settings.renderSX + 5), armorcd.renderposY - 2, 25, settings.renderSY + 4, 0xA0000000)
        renderFontDrawText(font,string.format('{00CCD0}%0.1f', os.clock() - 8.333), armorcd.renderposX + (settings.renderSX + 6), armorcd.renderposY - 2, -1)
    end 
end

-- Основная функция
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    
    loadSmugConfig()
    smugStartTime = smugConfig.startTime
    smugEndTime = smugConfig.endTime
    notificationsEnabled = smugConfig.notificationsEnabled
    
    loadStats()
    
    while not isSampAvailable() do wait(100) end
    
    local notificationFont = renderCreateFont("Arial", 16, 5)
    font = renderCreateFont("Arial Black", (armorcd.settings.render.renderSY * 0.5), 4)
    
    wait(3000)
    
    sampAddChatMessage('{FF69B4}[SmugHelper] {FFFFFF}Loaded! Type {FF69B4}/sgmenu', -1)
    sampAddChatMessage('{FF69B4}[SmugHelper] {FFFFFF}Smug schedule: {FF69B4}' .. smugStartTime .. " - " .. smugEndTime, -1)
    sampAddChatMessage('{FF69B4}[SmugHelper] {FFFFFF}Notifications: {FF69B4}' .. (notificationsEnabled and "ON" or "OFF"), -1)
    sampAddChatMessage('{FF69B4}[SmugHelper] {FFFFFF}ArmorCD: {FF69B4}' .. (armorcd.enabled and "ON" or "OFF"), -1)
    sampAddChatMessage('{FF69B4}[SmugHelper] {FFFFFF}House Search: {FF69B4}' .. (houseSearchEnabled and "ON" or "OFF"), -1)
    
    sampRegisterChatCommand("sgmenu", function()
        mainMenu.v = not mainMenu.v
    end)
    
    sampRegisterChatCommand("lds", function(param)
        if param and param:len() > 0 then
            sampSendChat('/loadsmug '..param)
        else
            local closestId = getClosestPlayer()
            if closestId ~= -1 then
                sampSendChat('/loadsmug '..closestId)
                sampAddChatMessage("{FF69B4}[SmugHelper] {FFFFFF}Loading to ID: "..closestId, -1)
            else
                sampAddChatMessage("{FF69B4}[SmugHelper] {FFFFFF}No players nearby", -1)
            end
        end
    end)
    
    sampRegisterChatCommand("del", function()
        sampSendChat('/deliversmug')
    end)
    
    sampRegisterChatCommand("dp", function()
        sampSendChat('/dropsmug')
    end)
    
    sampRegisterChatCommand("gdd", function()
        sampSendChat('/gps groundsmug')
    end)
    
    sampRegisterChatCommand("gss", function()
        sampSendChat('/gps seasmug')
    end)
    
    sampRegisterChatCommand("sgh", function()
        searchHouseOrHotel()
    end)
    
    sampRegisterChatCommand("ns", function()
        local schedule, isWeekend, currentTime = getSmugSchedule()
        local nextSmug, nextIndex = findNextSmug(schedule, currentTime)
        
        if nextSmug then
            local currentMinutes = timeToMinutes(currentTime)
            local nextMinutes = timeToMinutes(nextSmug.time)
            local timeUntil = nextMinutes - currentMinutes
            
            sampAddChatMessage("{FF69B4}[Next smug] {FFFFFF}" .. nextSmug.time .. " - " .. nextSmug.type, -1)
            sampAddChatMessage("{FF69B4}[Time until] {FFFFFF}" .. timeUntil .. " minutes", -1)
        else
            sampAddChatMessage("{FF69B4}[Next smug] {FFFFFF}No more smugs today", -1)
        end
    end)
    
    sampRegisterChatCommand("nsn", function()
        notificationsEnabled = not notificationsEnabled
        smugConfig.notificationsEnabled = notificationsEnabled
        saveSmugConfig()
        sampAddChatMessage("{FF69B4}[Notifications] {FFFFFF}" .. (notificationsEnabled and "ENABLED" or "DISABLED"), -1)
    end)
    
    -- FIXED LINE - исправленная команда установки времени
    sampRegisterChatCommand("fsmug", function(param)
        local time = param:match("^(%d?%d:?%d?%d?)$")
        if time then
            if not time:find(":") and #time == 4 then
                time = time:sub(1,2) .. ":" .. time:sub(3,4)
            elseif not time:find(":") and #time == 3 then
                time = "0" .. time:sub(1,1) .. ":" .. time:sub(2,3)
            elseif not time:find(":") and #time == 2 then
                time = time .. ":00"
            elseif not time:find(":") and #time == 1 then
                time = "0" .. time .. ":00"
            end
            
            local h, m = time:match("^(%d%d):(%d%d)$")
            if h and m then
                h, m = tonumber(h), tonumber(m)
                if h and m and h >= 0 and h <= 24 and m >= 0 and m <= 59 then
                    smugStartTime = string.format("%02d:%02d", h, m)
                    smugConfig.startTime = smugStartTime
                    if saveSmugConfig() then
                        sampAddChatMessage("{FF69B4}[SmugHelper] {FFFFFF}First smug time set: " .. smugStartTime, -1)
                    else
                        sampAddChatMessage("{FF69B4}[SmugHelper] {FF0000}Save error!", -1)
                    end
                else
                    sampAddChatMessage("{FF69B4}[SmugHelper] {FF0000}Invalid time! Example: /fsmug 10", -1)
                end
            else
                sampAddChatMessage("{FF69B4}[SmugHelper] {FF0000}Invalid format! Example: /fsmug 10", -1)
            end
        else
            sampAddChatMessage("{FF69B4}[SmugHelper] {FFFFFF}Usage: /fsmug [time]")
            sampAddChatMessage("{FF69B4}[SmugHelper] {FFFFFF}Examples: /fsmug 10, /fsmug 10:00, /fsmug 1000", -1)
        end
    end)
    
    sampRegisterChatCommand("lsmug", function(param)
        local time = param:match("^(%d?%d:?%d?%d?)$")
        if time then
            if not time:find(":") and #time == 4 then
                time = time:sub(1,2) .. ":" .. time:sub(3,4)
            elseif not time:find(":") and #time == 3 then
                time = "0" .. time:sub(1,1) .. ":" .. time:sub(2,3)
            elseif not time:find(":") and #time == 2 then
                time = time .. ":00"
            elseif not time:find(":") and #time == 1 then
                time = "0" .. time .. ":00"
            end
            
            local h, m = time:match("^(%d%d):(%d%d)$")
            if h and m then
                h, m = tonumber(h), tonumber(m)
                if h and m and h >= 0 and h <= 24 and m >= 0 and m <= 59 then
                    smugEndTime = string.format("%02d:%02d", h, m)
                    smugConfig.endTime = smugEndTime
                    if saveSmugConfig() then
                        sampAddChatMessage("{FF69B4}[SmugHelper] {FFFFFF}Last smug time set: " .. smugEndTime, -1)
                    else
                        sampAddChatMessage("{FF69B4}[SmugHelper] {FF0000}Save error!", -1)
                    end
                else
                    sampAddChatMessage("{FF69B4}[SmugHelper] {FF0000}Invalid time! Example: /lsmug 22", -1)
                end
            else
                sampAddChatMessage("{FF69B4}[SmugHelper] {FF0000}Invalid format! Example: /lsmug 22", -1)
            end
        else
            sampAddChatMessage("{FF69B4}[SmugHelper] {FFFFFF}Usage: /lsmug [time]")
            sampAddChatMessage("{FF69B4}[SmugHelper] {FFFFFF}Examples: /lsmug 22, /lsmug 22:00, /lsmug 2200", -1)
        end
    end)
    
    -- ArmorCD команды
    sampRegisterChatCommand("armcd", function(param)
        if param == "active" then
            armorcd.settings.render.active = not armorcd.settings.render.active
            armorcd.enabled = armorcd.settings.render.active
            saveArmorCD()
            sampAddChatMessage(armorcd.settings.render.active and "{FF69B4}[ArmorCD] {FFFFFF}Script - {00FF00}[ON]" or "{FF69B4}[ArmorCD] {FFFFFF}Script - {FF0000}[OFF]", -1)
        elseif param == "move" then
            armorcd.move = true
            sampAddChatMessage("{FF69B4}[ArmorCD] {FFFFFF}Move mode activated. Click LMB to set position", -1)
        elseif param:find("size %d+/%d+") then
            local xs, ys = param:match('size (%d+)/(%d+)')
            armorcd.settings.render.renderSX = tonumber(xs)
            armorcd.settings.render.renderSY = tonumber(ys)
            saveArmorCD()
            sampAddChatMessage("{FF69B4}[ArmorCD] {FFFFFF}Size saved. X - "..xs..'/ Y - '..ys, -1)
        elseif param == "ss" then
            armorcd.settings.render.show_secs = not armorcd.settings.render.show_secs
            saveArmorCD()
            sampAddChatMessage(armorcd.settings.render.show_secs and "{FF69B4}[ArmorCD] {FFFFFF}Seconds - {00FF00}[ON]" or "{FF69B4}[ArmorCD] {FFFFFF}Seconds - {FF0000}[OFF]", -1)
        elseif param == "fu" then
            font = renderCreateFont("Arial Black", (armorcd.settings.render.renderSY * 0.5), 4)
            sampAddChatMessage("{FF69B4}[ArmorCD] {FFFFFF}Font updated.", -1)
        elseif param == "autotake" then
            armorcd.settings.render.autoarm = not armorcd.settings.render.autoarm
            saveArmorCD()
            sampAddChatMessage(armorcd.settings.render.autoarm and "{FF69B4}[ArmorCD] {FFFFFF}AutoArmor - {00FF00}[ON]" or "{FF69B4}[ArmorCD] {FFFFFF}AutoArmor - {FF0000}[OFF]", -1)
        else
            sampAddChatMessage("{FF69B4}[ArmorCD] {FFFFFF}Use: /armcd active, /armcd move, /armcd ss, /armcd fu, /armcd autotake, /armcd size [X]/[Y]", -1)
        end
    end)
    
    while true do
        wait(0)
        imgui.Process = mainMenu.v
        
        if not mainMenu.v and not bindMode and not isChatActive() then
            processBinds()
        end
        
        notificationTimer = notificationTimer + 1
        if notificationTimer >= 36000 then
            notificationTimer = 0
            checkNotifications()
        end
        
        if showNotification then
            renderFontDrawText(notificationFont, notificationText, 850, 850, 0xFFFFFFFF)
        end
        
        armorcd_render()
        armorcd_mover()
        
        if wasKeyPressed(88) then
            local result, ped = getCharPlayerIsTargeting(PLAYER_HANDLE)
            if result then
                local result, id = sampGetPlayerIdByCharHandle(ped)
                if result then
                    sampSendChat('/loadsmug '..id)
                end
            end
        end
    end
end

-- Обработчик урона для ArmorCD
function onPlayerDamage(attacker, victim, weaponId, healthLoss, armorLoss)
    if victim == PLAYER_HANDLE then
        armorcd.last_dmg_time = os.clock()
        armorcd.check_auto_take = true
    end
end

-- Обработчик сообщений чата для статистики
function sampOnChatMessage(color, text)
    local peopleCount, amount = text:match("??????? ????????? ????? (%d+) ??????%. ???? ???? ?? ???????? ????????? (%d+)%$")
    
    if peopleCount and amount then
        peopleCount = tonumber(peopleCount)
        amount = tonumber(amount)
        
        smugStats.totalDeliveries = smugStats.totalDeliveries + 1
        smugStats.totalEarned = smugStats.totalEarned + amount
        smugStats.lastDelivery = amount
        smugStats.sessionEarned = smugStats.sessionEarned + amount
        smugStats.todayEarned = smugStats.todayEarned + amount
        smugStats.deliveriesToday = smugStats.deliveriesToday + 1
        
        local currentDate = os.date("%d")
        if currentDate ~= smugStats.lastResetDate then
            smugStats.todayEarned = amount
            smugStats.deliveriesToday = 1
            smugStats.lastResetDate = currentDate
        end
        
        saveStats()
        
        sampAddChatMessage("{FF69B4}[Stats] {FFFFFF}Added: {FF69B4}$" .. formatMoney(amount) .. " {FFFFFF}(x" .. peopleCount .. ")", -1)
    end
end

-- ImGui интерфейс (основное окно меню)
function imgui.OnDrawFrame()
    if not mainMenu.v then return end
    
    local iScreenWidth, iScreenHeight = getScreenResolution()
    imgui.SetNextWindowPos(imgui.ImVec2(iScreenWidth / 2, iScreenHeight / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(600, 650), imgui.Cond.FirstUseEver)
    
    if imgui.Begin(u8("Smug Helper"), mainMenu, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize) then
        imgui.BeginChild("##mainMenu_UP", imgui.ImVec2(0, 40), true)
            if imgui.Button(u8("SCHEDULE"), imgui.ImVec2(140, 25)) then
                imguiMenu = 1
            end
            imgui.SameLine()
            if imgui.Button(u8("STATS"), imgui.ImVec2(140, 25)) then
                imguiMenu = 2
            end
            imgui.SameLine()
            if imgui.Button(u8("COMMANDS"), imgui.ImVec2(140, 25)) then
                imguiMenu = 3
            end
            imgui.SameLine()
            if imgui.Button(u8("SCRIPTS"), imgui.ImVec2(140, 25)) then
                imguiMenu = 4
            end
        imgui.EndChild()
        
        if imguiMenu == 1 then
            imgui.BeginChild("##scheduleSection", imgui.ImVec2(0, 525), true)
                local schedule, isWeekend, currentTime = getSmugSchedule()
                local nextSmug, nextIndex = findNextSmug(schedule, currentTime)
                
                imgui.TextColoredRGB("{FF69B4}SMUG SCHEDULE")
                imgui.Separator()
                imgui.Spacing()
                
                imgui.TextColoredRGB("{FFFFFF}Current day: {FF69B4}" .. (isWeekend and "Weekend" or "Weekday"))
                imgui.TextColoredRGB("{FFFFFF}Current time: {FF69B4}" .. currentTime)
                imgui.TextColoredRGB("{FFFFFF}Smug time: {FF69B4}" .. smugStartTime .. " - " .. smugEndTime)
                imgui.TextColoredRGB("{FFFFFF}Notifications: {FF69B4}" .. (notificationsEnabled and "ON" or "OFF"))
                
                if nextSmug then
                    local currentMinutes = timeToMinutes(currentTime)
                    local nextMinutes = timeToMinutes(nextSmug.time)
                    local timeUntil = nextMinutes - currentMinutes
                    
                    imgui.TextColoredRGB("{FFFFFF}Next smug: {FF69B4}" .. nextSmug.time .. " - " .. nextSmug.type)
                    imgui.TextColoredRGB("{FFFFFF}Time until: {FF69B4}" .. timeUntil .. " minutes")
                end
                
                imgui.Spacing()
                
                if imgui.Button(u8(notificationsEnabled and "Disable notifications" or "Enable notifications"), imgui.ImVec2(200, 25)) then
                    notificationsEnabled = not notificationsEnabled
                    smugConfig.notificationsEnabled = notificationsEnabled
                    saveSmugConfig()
                    sampAddChatMessage("{FF69B4}[Notifications] {FFFFFF}" .. (notificationsEnabled and "ENABLED" or "DISABLED"), -1)
                end
                
                imgui.Spacing()
                
                imgui.TextColoredRGB("{FFFFFF}Schedule:")
                imgui.BeginChild("##scheduleList", imgui.ImVec2(0, 300), true)
                    if #schedule > 0 then
                        for i, smug in ipairs(schedule) do
                            local color = smug.type == "Sea" and "87CEEB" or "FF69B4"
                            local marker = ""
                            if nextSmug and i == nextIndex then
                                marker = " << NEXT"
                            end
                            imgui.TextColoredRGB(string.format("{FFFFFF}%s - {%s}%s{FFFFFF}%s", 
                                smug.time, color, smug.type, marker))
                        end
                    else
                        imgui.TextColoredRGB("{FF0000}Invalid time format! Use HH:MM")
                    end
                imgui.EndChild()
                
            imgui.EndChild()
        end
        
        if imguiMenu == 2 then
            imgui.BeginChild("##statsSection", imgui.ImVec2(0, 525), true)
                imgui.TextColoredRGB("{FF69B4}EARNINGS STATS")
                imgui.Separator()
                imgui.Spacing()
                
                imgui.TextColoredRGB("{FFFFFF}Total stats:")
                imgui.TextColoredRGB("{FF69B4}+ {FFFFFF}Total deliveries: {FF69B4}" .. smugStats.totalDeliveries)
                imgui.TextColoredRGB("{FF69B4}+ {FFFFFF}Total earned: {FF69B4}$" .. formatMoney(smugStats.totalEarned))
                imgui.TextColoredRGB("{FF69B4}+ {FFFFFF}Last delivery: {FF69B4}$" .. formatMoney(smugStats.lastDelivery))
                
                local avgEarn = smugStats.totalDeliveries > 0 and math.floor(smugStats.totalEarned / smugStats.totalDeliveries) or 0
                imgui.TextColoredRGB("{FF69B4}L {FFFFFF}Average: {FF69B4}$" .. formatMoney(avgEarn))
                
                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()
                
                imgui.TextColoredRGB("{FFFFFF}Today stats:")
                imgui.TextColoredRGB("{FF69B4}+ {FFFFFF}Deliveries today: {FF69B4}" .. smugStats.deliveriesToday)
                imgui.TextColoredRGB("{FF69B4}L {FFFFFF}Earned today: {FF69B4}$" .. formatMoney(smugStats.todayEarned))
                
                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()
                
                imgui.TextColoredRGB("{FFFFFF}Session:")
                imgui.TextColoredRGB("{FF69B4}L {FFFFFF}Session earned: {FF69B4}$" .. formatMoney(smugStats.sessionEarned))
                
                imgui.Spacing()
                
                if imgui.Button(u8("Reset stats"), imgui.ImVec2(150, 25)) then
                    smugStats.totalDeliveries = 0
                    smugStats.totalEarned = 0
                    smugStats.sessionEarned = 0
                    smugStats.todayEarned = 0
                    smugStats.deliveriesToday = 0
                    smugStats.lastDelivery = 0
                    smugStats.lastResetDate = os.date("%d")
                    saveStats()
                    sampAddChatMessage("{FF69B4}[Stats] {FFFFFF}Stats reset!", -1)
                end
                
            imgui.EndChild()
        end
        
        if imguiMenu == 3 then
            imgui.BeginChild("##commandsSection", imgui.ImVec2(0, 525), true)
                imgui.TextColoredRGB("{FF69B4}SMUGHELPER COMMANDS")
                imgui.Separator()
                imgui.Spacing()
                
                imgui.TextColoredRGB("{FFFFFF}Main commands:")
                imgui.BeginChild("##commandsList", imgui.ImVec2(0, 200), true)
                    for i, command in ipairs({"/lds", "/del", "/dp", "/gdd", "/gss", "/sgh"}) do
                        imgui.TextColoredRGB("{FF69B4}" .. command .. " {FFFFFF}- " .. 
                            (command == "/lds" and "load smug (auto-ID)" or
                             command == "/del" and "deliver smug" or
                             command == "/dp" and "drop smug" or
                            command == "/gss" and "nearest sea smug GPS" or
                            command == "/gdd" and "nearest ground smug GPS" or
                            command == "/sgh" and "search house/hotel"))
                            
                        imgui.SameLine()
                        
                        local bindKey = commandBinds[command]
                        local bindText = "No bind"
                        if bindKey and bindKey ~= "" then
                            bindText = getKeyName(bindKey)
                        end
                        
                        if bindKey and bindKey ~= "" then
                            if imgui.Button(u8("Remove") .. "##remove_" .. command, imgui.ImVec2(60, 20)) then
                                removeBind(command)
                            end
                            imgui.SameLine()
                            imgui.TextColoredRGB("{FFFFFF}Bind: {FF69B4}" .. bindText)
                        else
                            if imgui.Button(u8("Bind") .. "##bind_" .. command, imgui.ImVec2(100, 20)) then
                                selectedCommand = command
                                bindMode = true
                                currentBind = ""
                            end
                        end
                    end
                imgui.EndChild()
                
                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()
                
                imgui.TextColoredRGB("{FFFFFF}Time commands:")
                imgui.BeginChild("##timeCommands", imgui.ImVec2(0, 80), true)
                    imgui.TextColoredRGB("{FF69B4}/fsmug [time] {FFFFFF}- set first smug time")
                    imgui.TextColoredRGB("{FF69B4}/lsmug [time] {FFFFFF}- set last smug time")
                    imgui.TextColoredRGB("{FFFFFF}Examples: {FF69B4}/fsmug 10{FFFFFF}, {FF69B4}/lsmug 24{FFFFFF}, {FF69B4}/fsmug 10:00")
                imgui.EndChild()
                
                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()
                
                imgui.TextColoredRGB("{FFFFFF}Notification commands:")
                imgui.BeginChild("##notificationCommands", imgui.ImVec2(0, 60), true)
                    imgui.TextColoredRGB("{FF69B4}/ns {FFFFFF}- show next smug")
                    imgui.TextColoredRGB("{FF69B4}/nsn {FFFFFF}- toggle notifications")
                imgui.EndChild()
                
                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()
                
                imgui.TextColoredRGB("{FFFFFF}Hotkey:")
                imgui.TextColoredRGB("{FF69B4}RMB + X {FFFFFF}- quick load")
                
                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()
                
                imgui.TextColoredRGB("{FFFFFF}Command descriptions:")
                imgui.BeginChild("##descriptions", imgui.ImVec2(0, 100), true)
                    imgui.TextWrapped(u8("/lds - automatically finds nearest player and loads"))
                    imgui.TextWrapped(u8("/del - quick deliver command"))
                    imgui.TextWrapped(u8("/dp - quick drop command"))
                    imgui.TextWrapped(u8("/gss - nearest sea smug delivery"))
                    imgui.TextWrapped(u8("/gdd - nearest ground smug delivery"))
                    imgui.TextWrapped(u8("/sgh - search for nearest house or hotel"))
                    imgui.TextWrapped(u8("RMB + X - aim at player and press X for quick load"))
                imgui.EndChild()
                
            imgui.EndChild()
        end
        
        if imguiMenu == 4 then
            imgui.BeginChild("##scriptsSection", imgui.ImVec2(0, 525), true)
                imgui.TextColoredRGB("{FF69B4}SCRIPTS MANAGEMENT")
                imgui.Separator()
                imgui.Spacing()
                
                imgui.TextColoredRGB("{FFFFFF}ArmorCD Script:")
                if imgui.Button(u8(armorcd.enabled and "Disable ArmorCD" or "Enable ArmorCD"), imgui.ImVec2(200, 30)) then
                    armorcd.enabled = not armorcd.enabled
                    armorcd.settings.render.active = armorcd.enabled
                    saveArmorCD()
                    sampAddChatMessage("{FF69B4}[ArmorCD] {FFFFFF}" .. (armorcd.enabled and "ENABLED" or "DISABLED"), -1)
                end
                
                imgui.Spacing()
                
                if imgui.Button(u8("Move indicator"), imgui.ImVec2(200, 25)) then
                    armorcd.move = true
                    sampAddChatMessage("{FF69B4}[ArmorCD] {FFFFFF}Move mode activated", -1)
                end
                
                if imgui.Button(u8(armorcd.settings.render.autoarm and "Disable auto-armor" or "Enable auto-armor"), imgui.ImVec2(200, 25)) then
                    armorcd.settings.render.autoarm = not armorcd.settings.render.autoarm
                    saveArmorCD()
                    sampAddChatMessage("{FF69B4}[ArmorCD] {FFFFFF}Auto-armor: " .. (armorcd.settings.render.autoarm and "ON" or "OFF"), -1)
                end
                
                if imgui.Button(u8(armorcd.settings.render.show_secs and "Hide seconds" or "Show seconds"), imgui.ImVec2(200, 25)) then
                    armorcd.settings.render.show_secs = not armorcd.settings.render.show_secs
                    saveArmorCD()
                    sampAddChatMessage("{FF69B4}[ArmorCD] {FFFFFF}Seconds: " .. (armorcd.settings.render.show_secs and "ON" or "OFF"), -1)
                end
                
                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()
                
                imgui.TextColoredRGB("{FFFFFF}House Search:")
                if imgui.Button(u8(houseSearchEnabled and "Disable House Search" or "Enable House Search"), imgui.ImVec2(200, 30)) then
                    houseSearchEnabled = not houseSearchEnabled
                    saveHouseConfig()
                    sampAddChatMessage("{FF69B4}[HouseSearch] {FFFFFF}" .. (houseSearchEnabled and "ENABLED" or "DISABLED"), -1)
                end
                
                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()
                
                imgui.TextColoredRGB("{FFFFFF}Script info:")
                imgui.TextColoredRGB("{FFFFFF}ArmorCD - edited by Benya_Howard.")
                imgui.TextColoredRGB("{FFFFFF}Notification smug - idea from Barry Bardley.")
				imgui.TextColoredRGB("{FFFFFF}LoadSmug autoid and other bind - Author Thao Howard.")
                imgui.TextColoredRGB("{FFFFFF}The rest of the script code is written by Thao Howard.")
				imgui.TextColoredRGB("In the 1.5 version, ArmorCD fully integrated.")
				imgui.TextColoredRGB("If you have any ideas - tg author @noalexey0.")
                
            imgui.EndChild()
        end
        
        imgui.BeginChild("##mainMenu_FOOTER", imgui.ImVec2(0, 40), true)
            imgui.SetCursorPosX((imgui.GetWindowWidth() - 200 + imgui.GetStyle().ItemSpacing.x) / 2)
            imgui.TextColoredRGB("{FF69B4}SmugHelper by Howard {FFFFFF}v1.5")
        imgui.EndChild()
        
    imgui.End()
    end
    
    if bindMode then
        imgui.SetNextWindowPos(imgui.ImVec2(iScreenWidth / 2, iScreenHeight / 2), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(300, 120), imgui.Cond.Always)
        
        if imgui.Begin(u8("Bind assignment"), bindMode, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse) then
            imgui.Text(u8("Press key for command: ") .. selectedCommand)
            imgui.Text(u8("Or press ESC to cancel"))
            imgui.Separator()
            
            for key = 1, 255 do
                if wasKeyPressed(key) then
                    if key == 27 then
                        bindMode = false
                    else
                        currentBind = key
                        commandBinds[selectedCommand] = key
                        saveBinds()
                        bindMode = false
                        sampAddChatMessage("{FF69B4}[SmugHelper] {FFFFFF}Bind assigned: " .. getKeyName(key), -1)
                    end
                    break
                end
            end
            
            if imgui.Button(u8("Cancel"), imgui.ImVec2(100, 30)) then
                bindMode = false
            end
            
            imgui.End()
        end
    end
end

-- Функция для цветного текста ImGui
function imgui.TextColoredRGB(text)
    local style = imgui.GetStyle()
    local colors = style.Colors
    local ImVec4 = imgui.ImVec4

    local getcolor = function(color)
        local color = type(color) == "string" and tonumber(color, 16) or color
        if type(color) ~= "number" then return colors[1] end
        local r, g, b = bit.band(bit.rshift(color, 16), 0xFF), bit.band(bit.rshift(color, 8), 0xFF), bit.band(color, 0xFF)
        return ImVec4(r/255, g/255, b/255, 1.0)
    end

    local render_text = function(text_)
        for w in text_:gmatch("[^\r\n]+") do
            local text, colors_, m = {}, {}, 1
            w = w:gsub("{(......)}", "{%1}")
            while w:find("{......}") do
                local n, k = w:find("{......}")
                local color = getcolor(w:sub(n + 1, k - 1))
                if color then
                    text[#text], text[#text + 1] = w:sub(m, n - 1), w:sub(k + 1, #w)
                    colors_[#colors_ + 1] = color
                    m = n
                end
                w = w:sub(1, n - 1) .. w:sub(k + 1, #w)
            end
            if #text > 0 then
                for i = 1, #text do
                    imgui.TextColored(colors_[i] or colors[1], u8(text[i]))
                    imgui.SameLine(nil, 0)
                end
                imgui.NewLine()
            else 
                imgui.Text(u8(w)) 
            end
        end
    end

    render_text(text)
end

-- Тема ImGui
function theme()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4

    style.WindowRounding = 2.0
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ChildWindowRounding = 2.0
    style.FrameRounding = 2.0
    style.ItemSpacing = imgui.ImVec2(5.0, 4.0)
    style.ScrollbarSize = 13.0
    style.ScrollbarRounding = 0
    style.GrabMinSize = 8.0
    style.GrabRounding = 1.0

    colors[clr.FrameBg]                = ImVec4(0.16, 0.16, 0.16, 0.54)
    colors[clr.FrameBgHovered]         = ImVec4(0.31, 0.31, 0.31, 0.40)
    colors[clr.FrameBgActive]          = ImVec4(0.41, 0.41, 0.41, 0.67)
    colors[clr.TitleBg]                = ImVec4(0.85, 0.33, 0.85, 0.75)
    colors[clr.TitleBgActive]          = ImVec4(0.85, 0.33, 0.85, 0.75)
    colors[clr.CheckMark]              = ImVec4(0.85, 0.33, 0.85, 1.00)
    colors[clr.SliderGrab]             = ImVec4(0.85, 0.33, 0.85, 1.00)
    colors[clr.SliderGrabActive]       = ImVec4(0.85, 0.33, 0.85, 1.00)
    colors[clr.Button]                 = ImVec4(0.85, 0.33, 0.85, 0.40)
    colors[clr.ButtonHovered]          = ImVec4(0.85, 0.33, 0.85, 1.00)
    colors[clr.ButtonActive]           = ImVec4(0.85, 0.20, 0.85, 1.00)
    colors[clr.Header]                 = ImVec4(0.85, 0.33, 0.85, 0.31)
    colors[clr.HeaderHovered]          = ImVec4(0.85, 0.33, 0.85, 0.80)
    colors[clr.HeaderActive]           = ImVec4(0.85, 0.33, 0.85, 1.00)
    colors[clr.Separator]              = ImVec4(0.85, 0.33, 0.85, 0.50)
    colors[clr.ResizeGrip]             = ImVec4(0.85, 0.33, 0.85, 0.20)
    colors[clr.ResizeGripHovered]      = ImVec4(0.85, 0.33, 0.85, 0.78)
    colors[clr.ResizeGripActive]       = ImVec4(0.85, 0.33, 0.85, 1.00)
    colors[clr.TextSelectedBg]         = ImVec4(0.85, 0.33, 0.85, 0.35)
    colors[clr.Text]                   = ImVec4(1.00, 1.00, 1.00, 1.00)
    colors[clr.TextDisabled]           = ImVec4(0.50, 0.50, 0.50, 1.00)
    colors[clr.WindowBg]               = ImVec4(0.06, 0.06, 0.06, 0.94)
    colors[clr.ChildWindowBg]          = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[clr.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 0.94)
    colors[clr.Border]                 = ImVec4(0.85, 0.33, 0.85, 0.50)
    colors[clr.BorderShadow]           = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[clr.MenuBarBg]              = ImVec4(0.14, 0.14, 0.14, 1.00)
    colors[clr.ScrollbarBg]            = ImVec4(0.02, 0.02, 0.02, 0.53)
    colors[clr.ScrollbarGrab]          = ImVec4(0.85, 0.33, 0.85, 1.00)
    colors[clr.ScrollbarGrabHovered]   = ImVec4(0.85, 0.33, 0.85, 1.00)
    colors[clr.ScrollbarGrabActive]    = ImVec4(0.85, 0.33, 0.85, 1.00)
    colors[clr.ComboBg]                = ImVec4(0.20, 0.20, 0.20, 0.99)
    colors[clr.PlotLines]              = ImVec4(0.85, 0.33, 0.85, 1.00)
    colors[clr.PlotLinesHovered]       = ImVec4(0.85, 0.33, 0.85, 1.00)
    colors[clr.PlotHistogram]          = ImVec4(0.85, 0.33, 0.85, 1.00)
    colors[clr.PlotHistogramHovered]   = ImVec4(0.85, 0.33, 0.85, 1.00)
end

theme()