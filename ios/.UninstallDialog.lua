-- KpOS Uninstaller
-- This wipes the local ComputerCraft computer's writable filesystem.
-- It will NOT delete /rom because CC:Tweaked keeps that read-only anyway.
-- It also skips mounted disk drives by default.

local CONFIRM_ONE = "UNINSTALL"
local CONFIRM_TWO = "DELETE EVERYTHING"

local SKIP_TOP_LEVEL = {
    ["rom"] = true,
    ["disk"] = true,
    ["disk2"] = true,
    ["disk3"] = true,
}

local function clear()
    term.clear()
    term.setCursorPos(1, 1)
end

local function pause()
    print()
    print("Press any key to continue...")
    os.pullEvent("key")
end

local function confirm(prompt, expected)
    print(prompt)
    write("> ")
    local answer = read()
    return answer == expected
end

clear()
print("KpOS UNINSTALLER")
print("----------------")
print("WARNING: This will delete files from this computer.")
print("It is meant to fully remove KpOS from the local PC.")
print()
print("It will skip:")
print("- /rom")
print("- /disk, /disk2, /disk3")
print()
print("Confirmation 1 of 2")
print("Type exactly: " .. CONFIRM_ONE)

if not confirm("", CONFIRM_ONE) then
    print("Cancelled.")
    return
end

clear()
print("FINAL CONFIRMATION")
print("------------------")
print("This is your last chance to cancel.")
print("The local computer files will be deleted.")
print()
print("Confirmation 2 of 2")
print("Type exactly: " .. CONFIRM_TWO)

if not confirm("", CONFIRM_TWO) then
    print("Cancelled.")
    return
end

clear()
print("Uninstalling...")

local deleted = 0
local skipped = 0
local failed = 0

local function tryDelete(path)
    local ok, err = pcall(function()
        fs.delete(path)
    end)

    if ok then
        deleted = deleted + 1
        print("Deleted: /" .. path)
    else
        failed = failed + 1
        print("Failed: /" .. path .. " - " .. tostring(err))
    end
end

for _, item in ipairs(fs.list("/")) do
    if SKIP_TOP_LEVEL[item] then
        skipped = skipped + 1
        print("Skipped: /" .. item)
    else
        tryDelete(item)
    end
end

print()
print("Uninstall complete.")
print("Deleted: " .. deleted)
print("Skipped: " .. skipped)
print("Failed: " .. failed)
print()
print("Rebooting in 3 seconds...")
sleep(3)
os.reboot()
