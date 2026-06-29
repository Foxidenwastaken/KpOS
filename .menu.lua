-- KpOS startup menu

-- Uncomment this if you want to block Ctrl+T termination:
os.pullEvent = os.pullEventRaw

-- speaker setup
local speaker = peripheral.find("speaker")

local OSV = "alpha 0.0.1"

local options = {
    { label = "Command",    path = "ios/.command.lua" },
    { label = "Programs",   path = "ios/.programs.lua" },
    { label = "Update",     path = "ios/.update.lua" },
    { label = "InstallPKG", path = "ios/install_package.lua" },
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
    { label = "Uninstall",  path = "ios/.UninstallDialog.lua" },
}

local selected = 1

local function printCentered(y, text)
    local w, h = term.getSize()

    if y < 1 or y > h then
        return
    end

    local x = math.floor((w - #text) / 2) + 1
    if x < 1 then
        x = 1
    end

    term.setCursorPos(x, y)
    term.clearLine()
    term.write(text)
end

local function drawMenu()
    local w, h = term.getSize()

    term.clear()

    term.setCursorPos(1, 1)
    term.write("KpOS " .. OSV)

    local currentLabel = options[selected].label
    term.setCursorPos(math.max(1, w - #currentLabel), 1)
    term.write(currentLabel)

    term.setCursorPos(1, 2)
    term.write("This is computer #" .. tostring(os.getComputerID()))

    local startY = math.floor((h - #options) / 2)

    printCentered(startY - 2, "Start Menu")

    for i, option in ipairs(options) do
        local text = option.label

        if i == selected then
            text = "[ " .. text .. " ]"
        end

        -- Each option gets its own line.
        printCentered(startY + i, text)
    end
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

        local _, key = os.pullEvent("key")

        if key == keys.s or key == keys.down then
            if speaker then
                speaker.playSound("minecraft:block.amethyst_block.step", 1.0, 1.0)
            end

            selected = selected + 1
            if selected > #options then

                selected = 1


            end

        elseif key == keys.w or key == keys.up then
            if speaker then
                speaker.playSound("minecraft:block.amethyst_block.step", 1.0, 1.0)
            end

            selected = selected - 1
            if selected < 1 then
                selected = #options


            end

        elseif key == keys.enter then

            if speaker then
                speaker.playSound("minecraft:ui.loom.select_pattern", 1.0, 1.0)
            end
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
