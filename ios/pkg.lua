local packageManager = dofile("ios/lib/package_manager.lua")
if packageManager.setShell then
    packageManager.setShell(shell)
end
local args = {...}
local command = args[1] or "help"

local function printHelp()
    print("KpOS package command")
    print("Usage:")
    print("  ios/pkg.lua list")
    print("  ios/pkg.lua info <id-or-name>")
    print("  ios/pkg.lua run <id-or-name>")
end

local function printPackage(package)
    print(package.name .. " (" .. package.id .. ")")
    print("  version: " .. package.version)
    if package.author ~= "" then
        print("  author: " .. package.author)
    end
    if package.description ~= "" then
        print("  description: " .. package.description)
    end
    print("  entry: " .. package.entry)
end

if command == "list" then
    local packages, errors = packageManager.listPackages(false)

    if #packages == 0 then
        print("No packages installed.")
    else
        for _, package in ipairs(packages) do
            print("- " .. package.name .. " (" .. package.id .. ") v" .. package.version)
        end
    end

    if #errors > 0 then
        print("")
        print("Errors:")
        for _, err in ipairs(errors) do
            print("- " .. err)
        end
    end
elseif command == "info" then
    local package = packageManager.findPackage(args[2])

    if not package then
        print("Package not found: " .. tostring(args[2]))
    else
        printPackage(package)
    end
elseif command == "run" then
    local package = packageManager.findPackage(args[2])

    if not package then
        print("Package not found: " .. tostring(args[2]))
    else
        packageManager.runPackage(package, shell)
    end
else
    printHelp()
end
