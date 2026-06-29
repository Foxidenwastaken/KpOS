-- KpOS startup menu

-- Uncomment this if you want to block Ctrl+T termination:
-- os.pullEvent = os.pullEventRaw

local OSV = "alpha 0.0.1"

local options = {
    {
        label = "Command",
        path = "ios/.command.lua",
    },
    {
        label = "Programs",
        path = "ios/.programs.lua",
    },
    {
        label = "Update",
        path = "ios/.update.lua",
    },
    {
        label = "InstallPKG",
        path = "ios/install_package.lua",
    },
    {
        label = "Shutdown",
        action = function()
            term.clear()
            term.setCursorPos(1, 1)
            print("> shutdown")
            print("Goodbye")
            sleep(1)
            os.shutdown()
        end,
    },
    {
        label = "Reboot",
        action = function()
            os.reboot()
        end,
    },
    {
        label = "Uninstall",
        path = "ios/.UninstallDialog.lua",
    },
}

local selected = 1

local function getSize()
    return term.getSize()
end

local function printCentered(y, text)
    local w, _ = getSize()
    local x = math.floor((w - #text) / 2) + 1

    if x < 1 then
        x = 1
    end

    term.setCursorPos(x, y)
    term.clearLine()
    term.write(text)
end

local function drawMenu()
    local w, h = getSize()

    term.clear()
    term.setCursorPos(1, 1)
    term.write("KpOS " .. OSV)

    term.setCursorPos(1, 2)
    if shell and shell.resolve and shell.resolve("id") then
        shell.run("id")
    else
        term.write("ID: " .. tostring(os.getComputerID()))
    end

    local currentLabel = options[selected].label
    term.setCursorPos(math.max(1, w - #currentLabel + 1), 1)
    term.write(currentLabel)

    local startY = math.floor(h / 2) - math.floor(#options / 2)

    printCentered(startY - 2, "")
    printCentered(startY - 1, "Start Menu")
    printCentered(startY, "")

    for i, option in ipairs(options) do
        local label = option.label

        if i == selected then
            label = "[ " .. label .. " ]"
        else
            label = "  " .. label .. "  "
        end

        printCentered(startY + i, label)
    end

    printCentered(startY + #options + 1, "")
end

local function runSelectedProgram()
    local option = options[selected]

    if option.action then
        option.action()
        return
    end

    if not option.path then
        error("Menu option has no path/action: " .. tostring(option.label))
    end

    if not fs.exists(option.path) then
        error("Missing system file: " .. option.path)
    end

    shell.run(option.path)
end

local function main()
    while true do
        drawMenu()

        local event, key = os.pullEvent("key")

        if key == keys.s or key == keys.down then
            selected = selected + 1

            if selected > #options then
                selected = 1
            end
        elseif key == keys.w or key == keys.up then
            selected = selected - 1

            if selected < 1 then
                selected = #options
            end
        elseif key == keys.enter then
            break
        end
    end

    term.clear()
    term.setCursorPos(1, 1)
    runSelectedProgram()
end

local ok, err = pcall(main)

if not ok then
    term.clear()
    term.setCursorPos(1, 1)

    print("KpOS has encountered a problem:")
    print(tostring(err))

    for i = 10, 1, -1 do
        term.setCursorPos(1, 5)
        term.clearLine()
        term.write("Rebooting in " .. i)
        sleep(1)
    end

    os.reboot()
end
