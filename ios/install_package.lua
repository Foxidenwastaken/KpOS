-- KpOS Package Installer UI
-- Put this at: ios/install_package.lua
--
-- Your package API should have:
--   /list       -> plain text package names, one per line
--   /<package>  -> Lua bundle with files table
--
-- Example API folder package:
--   packages/minechat/programs/Minechat/Minechat.lua
--   packages/minechat/packages/package.lua
--
-- That installs into:
--   ios/programs/Minechat/Minechat.lua
--   ios/packages/package.lua

-- CHANGE THIS TO YOUR REAL API URL
local API_URL = "http://192.168.12.108:5000"

-- Uncomment this if you want to block Ctrl+T termination:
-- os.pullEvent = os.pullEventRaw

local packages = {}
local selected = 1
local status = "Loading packages..."
local loading = false

local function trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalizeApiUrl(url)
    if url:sub(-1) == "/" then
        return url:sub(1, -2)
    end

    return url
end

API_URL = normalizeApiUrl(API_URL)

local function setColor(fg, bg)
    if term.isColor and term.isColor() then
        if fg then term.setTextColor(fg) end
        if bg then term.setBackgroundColor(bg) end
    end
end

local function resetColor()
    setColor(colors.white, colors.black)
end

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

local function drawHeader(title)
    local w, _ = term.getSize()

    setColor(colors.white, colors.black)
    term.setCursorPos(1, 1)
    term.clearLine()
    term.write("KpOS Package Installer")

    term.setCursorPos(math.max(1, w - #title + 1), 1)
    term.write(title)

    term.setCursorPos(1, 2)
    term.clearLine()
    term.write("API: " .. API_URL)
end

local function drawStatus()
    local _, h = term.getSize()

    term.setCursorPos(1, h - 1)
    term.clearLine()
    term.write(status or "")

    term.setCursorPos(1, h)
    term.clearLine()
    term.write("W/S or arrows = move Enter = install R = refresh Q = back")
end

local function drawMenu()
    local _, h = term.getSize()

    term.clear()
    drawHeader("Packages")

    if #packages == 0 then
        printCentered(math.floor(h / 2), "No packages found.")
        printCentered(math.floor(h / 2) + 1, "Press R to refresh or Q to go back.")
        drawStatus()
        return
    end

    local startY = math.floor((h - #packages) / 2)

    printCentered(startY - 2, "Available Packages")

    for i, packageName in ipairs(packages) do
        local text = packageName

        if i == selected then
            text = "[ " .. text .. " ]"
        end

        printCentered(startY + i, text)
    end

    drawStatus()
end

local function showMessage(title, lines)
    term.clear()
    drawHeader(title)

    local _, h = term.getSize()
    local startY = math.floor(h / 2) - math.floor(#lines / 2)

    for i, line in ipairs(lines) do
        printCentered(startY + i - 1, line)
    end

    printCentered(h, "Press any key to continue...")
    os.pullEvent("key")
end

local function fetchText(url)
    if not http then
        return nil, "HTTP is disabled."
    end

    local response = http.get(url)

    if not response then
        return nil, "Could not download: " .. url
    end

    local data = response.readAll()
    response.close()

    return data
end

local function loadPackageList()
    loading = true
    status = "Downloading package list..."
    drawMenu()

    local data, err = fetchText(API_URL .. "/list")

    packages = {}
    selected = 1

    if not data then
        status = err
        loading = false
        return false
    end

    for line in data:gmatch("[^\r\n]+") do
        local name = trim(line)

        if name ~= "" and not name:match("^#") then
            table.insert(packages, name)
        end
    end

    table.sort(packages)

    if #packages == 0 then
        status = "No packages available."
    else
        status = "Found " .. #packages .. " package(s)."
    end

    loading = false
    return true
end

local function getInstallRoot()
    -- Package paths are relative to /ios.
    -- If this installer is already inside /ios, write to current folder.
    -- Otherwise, write into /ios.
    if fs.exists("programs") and fs.exists("packages") and not fs.exists("ios") then
        return "."
    end

    return "ios"
end

local function combine(root, path)
    if root == "." then
        return path
    end

    return fs.combine(root, path)
end

local function confirmInstall(packageName)
    term.clear()
    drawHeader("Confirm")

    printCentered(6, "Install package?")
    printCentered(8, packageName)
    printCentered(11, "Press Y to install.")
    printCentered(12, "Press any other key to cancel.")

    local _, key = os.pullEvent("key")
    return key == keys.y
end

local function installPackage(packageName)
    if not confirmInstall(packageName) then
        status = "Install cancelled."
        return
    end

    term.clear()
    drawHeader("Installing")
    printCentered(5, "Downloading " .. packageName .. "...")

    local data, err = fetchText(API_URL .. "/" .. packageName)

    if not data then
        showMessage("Install Failed", {
            "Could not download package.",
            err or "Unknown error",
        })
        status = "Install failed."
        return
    end

    printCentered(6, "Reading package bundle...")

    local fn, loadErr = load(data)
    if not fn then
        showMessage("Install Failed", {
            "Bad package bundle.",
            tostring(loadErr),
        })
        status = "Install failed."
        return
    end

    local ok, bundle = pcall(fn)
    if not ok then
        showMessage("Install Failed", {
            "Package bundle crashed.",
            tostring(bundle),
        })
        status = "Install failed."
        return
    end

    if type(bundle) ~= "table" or type(bundle.files) ~= "table" then
        showMessage("Install Failed", {
            "Invalid package bundle.",
            "Bundle must return a table with files.",
        })
        status = "Install failed."
        return
    end

    local installRoot = getInstallRoot()
    local installed = 0
    local failed = 0
    local y = 8
    local _, h = term.getSize()

    for path, contents in pairs(bundle.files) do
        local target = combine(installRoot, path)
        local dir = fs.getDir(target)

        if dir ~= "" and not fs.exists(dir) then
            fs.makeDir(dir)
        end

        local file = fs.open(target, "w")

        if not file then
            failed = failed + 1
        else
            file.write(contents)
            file.close()
            installed = installed + 1
        end

        if y < h - 2 then
            term.setCursorPos(1, y)
            term.clearLine()
            term.write("Installed: " .. target)
            y = y + 1
        end
    end

    showMessage("Install Complete", {
        "Package: " .. packageName,
        "Installed files: " .. installed,
        "Failed files: " .. failed,
    })

    if failed == 0 then
        status = "Installed " .. packageName .. "."
    else
        status = "Installed " .. packageName .. " with " .. failed .. " failed file(s)."
    end
end

local function main()
    loadPackageList()

    while true do
        drawMenu()

        local _, key = os.pullEvent("key")

        if loading then
            -- ignore input while loading
        elseif key == keys.s or key == keys.down then
            if #packages > 0 then
                selected = selected + 1

                if selected > #packages then
                    selected = 1
                end
            end

        elseif key == keys.w or key == keys.up then
            if #packages > 0 then
                selected = selected - 1

                if selected < 1 then
                    selected = #packages
                end
            end

        elseif key == keys.r then
            loadPackageList()

        elseif key == keys.q or key == keys.backspace then
            term.clear()
            term.setCursorPos(1, 1)
            shell.run("exit.lua")

        elseif key == keys.enter then
            if #packages > 0 then
                installPackage(packages[selected])
            end
        end
    end
end

local ok, err = pcall(main)

if not ok then
    term.clear()
    term.setCursorPos(1, 1)
    print("Package installer crashed:")
    print(tostring(err))
    print()
    print("Press any key to return...")
    os.pullEvent("key")
end
