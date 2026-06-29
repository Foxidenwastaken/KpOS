-- KpOS simple package installer
-- Usage:
--   install_package <api_url> <package>
--
-- Example:
--   install_package http://localhost:5000 minechat
--
-- In-game, use your real API URL:
--   install_package https://your-api.example minechat

local args = { ... }

local api = args[1]
local package = args[2]

if not api or not package then
    print("Usage: install_package <api_url> <package>")
    print("Example: install_package https://your-api.example minechat")
    return
end

if not http then
    print("HTTP is disabled.")
    return
end

if api:sub(-1) == "/" then
    api = api:sub(1, -2)
end

local url = api .. "/" .. package
print("Downloading " .. package .. "...")
local response = http.get(url)

if not response then
    print("Failed to download package.")
    return
end

local data = response.readAll()
response.close()

local fn, err = load(data)
if not fn then
    print("Bad package bundle:")
    print(err)
    return
end

local ok, bundle = pcall(fn)
if not ok then
    print("Package bundle crashed:")
    print(bundle)
    return
end

if type(bundle) ~= "table" or type(bundle.files) ~= "table" then
    print("Invalid package bundle.")
    return
end

-- Package paths are relative to /ios.
-- If this installer is already inside /ios, it writes to the current folder.
-- Otherwise, it writes into /ios.
local installRoot = "ios"
if fs.exists("programs") and fs.exists("packages") then
    installRoot = "."
end

local function combine(root, path)
    if root == "." then
        return path
    end

    return fs.combine(root, path)
end

local installed = 0

for path, contents in pairs(bundle.files) do
    local target = combine(installRoot, path)
    local dir = fs.getDir(target)

    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end

    local file = fs.open(target, "w")
    if not file then
        print("Failed writing " .. target)
    else
        file.write(contents)
        file.close()
        installed = installed + 1
        print("Installed " .. target)
    end
end

print("Done. Installed " .. installed .. " files.")
