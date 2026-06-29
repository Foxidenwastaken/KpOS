-- minechat_api.lua
-- LucyChat-style client using your Python Flask API instead of rednet/wifi

local URL = "http://192.168.12.108:3000" -- CHANGE THIS

-- auth
local sessionFile = ".minechat_session"
local username = nil
local token = nil

local function saveSession()
    local file = fs.open(sessionFile, "w")
    file.write(textutils.serializeJSON({
        username = username,
        token = token
    }))
    file.close()
end

local function loadSession()
    if not fs.exists(sessionFile) then
        return false
    end

    local file = fs.open(sessionFile, "r")
    local data = textutils.unserializeJSON(file.readAll())
    file.close()

    if data and data.username and data.token then
        username = data.username
        token = data.token
        return true
    end

    return false
end

--auth end

-- everything else

local currentChannel = "global"
local running = true

local seenGlobal = {}
local seenDM = {}

local function encode(text)
    return textutils.urlEncode(tostring(text))
end

local function makeKey(msg)
    return tostring(msg.time) .. "|" ..
           tostring(msg.from) .. "|" ..
           tostring(msg.to) .. "|" ..
           tostring(msg.message)
end

local function apiGet(path)
    local response, err = http.get(URL .. path)

    if not response then
        return nil, err
    end

    local body = response.readAll()
    response.close()

    local data = textutils.unserializeJSON(body)

    if not data then
        return nil, "Invalid JSON"
    end

    return data, nil
end

local function printPrompt()
    write("#" .. currentChannel .. "> ")
end

local function printMessage(prefix, text)
    print()
    print(prefix .. text)
    printPrompt()
end

local function splitWords(text)
    local words = {}

    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end

    return words
end

local function sendGlobal(text)
    if not token then
        printMessage("[ERROR] ", "you are not logged in")
        return
    end

    local path =
        "/messages/sendglobal?token=" ..
        encode(token) ..
        "&message=" ..
        encode(text)

    local data, err = apiGet(path)

    if data and data.ok then
        printMessage("[OK] ", "sent to global chat")
    else
        printMessage("[ERROR] ", (data and data.error) or err or "failed to send")
    end
end


local function sendDM(to, text)
    if not token then
        printMessage("[ERROR] ", "you are not logged in")
        return
    end

    local path =
        "/messages/send?token=" ..
        encode(token) ..
        "&to=" ..
        encode(to) ..
        "&message=" ..
        encode(text)

    local data, err = apiGet(path)

    if data and data.ok then
        printMessage("[OK] ", "sent DM to " .. to)
    else
        printMessage("[ERROR] ", (data and data.error) or err or "failed to send DM")
    end
end

local function showGlobalHistory(amount)
    local data, err = apiGet("/messages/historyglobal")

    if not data or not data.ok then
        print("[ERROR] " .. tostring(err or "failed to load global history"))
        return
    end

    local messages = data.messages or {}
    amount = amount or 20

    print()
    print("History for #global:")

    local start = math.max(1, #messages - amount + 1)

    for i = start, #messages do
        local msg = messages[i]
        print("[" .. tostring(msg.time) .. "] <" .. tostring(msg.from) .. "> " .. tostring(msg.message))
    end
end

local function showDMHistory(user, amount)
    local data, err = apiGet("/messages/history?token=" .. encode(token))

    if not data or not data.ok then
        print("[ERROR] " .. tostring(err or "failed to load DM history"))
        return
    end

    local messages = data.messages or {}
    amount = amount or 20

    print()
    print("DM inbox for " .. user .. ":")

    local start = math.max(1, #messages - amount + 1)

    for i = start, #messages do
        local msg = messages[i]
        print("[" .. tostring(msg.time) .. "] " .. tostring(msg.from) .. " -> " .. tostring(msg.to) .. ": " .. tostring(msg.message))
    end
end

local function markExistingMessagesSeen()
    local globalData = apiGet("/messages/historyglobal")

    if globalData and globalData.ok then
        for _, msg in ipairs(globalData.messages or {}) do
            seenGlobal[makeKey(msg)] = true
        end
    end

    if token then
        local dmData = apiGet("/messages/history?token=" .. encode(token))

        if dmData and dmData.ok then
            for _, msg in ipairs(dmData.messages or {}) do
                seenDM[makeKey(msg)] = true
            end
        end
    end
end

local function receiveLoop()
    markExistingMessagesSeen()

    while running do
        local globalData = apiGet("/messages/historyglobal")

        if globalData and globalData.ok then
            for _, msg in ipairs(globalData.messages or {}) do
                local key = makeKey(msg)

                if not seenGlobal[key] then
                    seenGlobal[key] = true

                    print()
                    print("[" .. tostring(msg.time) .. "] #global <" .. tostring(msg.from) .. "> " .. tostring(msg.message))
                    printPrompt()
                end
            end
        end

        local dmData = nil

        if token then
            dmData = apiGet("/messages/history?token=" .. encode(token))
        end

        if dmData and dmData.ok then
            for _, msg in ipairs(dmData.messages or {}) do
                local key = makeKey(msg)

                if not seenDM[key] then
                    seenDM[key] = true

                    print()
                    print("[" .. tostring(msg.time) .. "] [DM] " .. tostring(msg.from) .. " -> " .. tostring(msg.to) .. ": " .. tostring(msg.message))
                    printPrompt()
                end
            end
        end

        sleep(2)
    end
end

local function printHelp()
    print("Commands:")
    print("/register <name> <password>")
    print("/login <name> <password>")
    print("/history [amount]")
    print("/dm <user> <message>")
    print("/dmhistory [user] [amount]")
    print("/channels")
    print("/users")
    print("/help")
    print("/quit")
    print("")
    print("Normal text sends to global chat.")
end

local function inputLoop()
    while running do
        printPrompt()
        local line = read()

        if line == nil then
            running = false
            break
        end

        if line == "" then
            -- do nothing

        elseif line:sub(1, 1) == "/" then
            local words = splitWords(line)
            local cmd = words[1]

            if cmd == "/login" then
                local newName = words[2]
                local password = words[3]

                if newName and password then
                    local data, err = apiGet(
                        "/auth/login?user=" ..
                        encode(newName) ..
                        "&password=" ..
                        encode(password)
                    )

                    if data and data.ok then
                        username = data.user
                        token = data.token
                        saveSession()
                        seenDM = {}
                        print("[OK] logged in as " .. username)
                    else
                        print("[ERROR] " .. tostring((data and data.error) or err or "login failed"))
                    end
                else
                    print("Usage: /login <name> <password>")
                end

            elseif cmd == "/register" then
                local newName = words[2]
                local password = words[3]

                if newName and password then
                    local data, err = apiGet(
                        "/auth/register?user=" ..
                        encode(newName) ..
                        "&password=" ..
                        encode(password)
                    )

                    if data and data.ok then
                        username = data.user
                        token = data.token
                        saveSession()
                        seenDM = {}
                        print("[OK] registered and logged in as " .. username)
                    else
                        print("[ERROR] " .. tostring((data and data.error) or err or "register failed"))
                    end
                else
                    print("Usage: /register <name> <password>")
                end

            elseif cmd == "/dmhistory" then
                local user = words[2] or username
                local amount = tonumber(words[3]) or 20
                showDMHistory(user, amount)

            elseif cmd == "/channels" then
                print()
                print("Channels:")
                print("- #global")

            elseif cmd == "/users" then
                print()
                print("Your current username:")
                print("- " .. username)
                print("")
                print("This API does not have a user list yet.")

            elseif cmd == "/join" then
                print("Only #global exists in the current API.")

            elseif cmd == "/create" then
                print("Channels are not supported by the current API yet.")

            elseif cmd == "/help" then
                printHelp()

            elseif cmd == "/quit" then
                running = false
                print("Bye!")

            else
                print("Unknown command. Use /help.")
            end

        else
            sendGlobal(line)
        end
    end
end

loadSession()

term.clear()
term.setCursorPos(1, 1)

print("Minechat API Client")

if username then
    print("User: " .. username)
else
    print("User: not logged in")
end

if URL == "http://192.168.12.108:3000" then
    print("API: official")
else
    print("API: " .. URL)
end

print()
print("use /help for a list of commands")
print()

parallel.waitForAny(receiveLoop, inputLoop)
