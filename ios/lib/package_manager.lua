-- KpOS package manager
-- Drop packages into ios/packages/<package-id>/ with a package.lua file.
-- package.lua must return a table, for example:
-- return { id = "demo", name = "Demo", version = "1.0.0", entry = "main.lua" }

local PackageManager = {}

PackageManager.packageRoot = "ios/packages"

-- In ComputerCraft/CC:Tweaked, `shell` is not always stored in _G.
-- It is often injected into the currently running program's environment.
-- Because this module is loaded with dofile/loadfile, it may not see that
-- program-local `shell` unless the caller passes it in.
local activeShell = nil

local manifestNames = {
    "package.lua",
    "manifest.lua"
}

local function copyGlobals()
    local env = {}

    for key, value in pairs(_G) do
        env[key] = value
    end

    return env
end

local function getShell(shellApi)
    if shellApi then
        return shellApi
    end

    if activeShell then
        return activeShell
    end

    if _G and rawget(_G, "shell") then
        return rawget(_G, "shell")
    end

    return nil
end

function PackageManager.setShell(shellApi)
    activeShell = shellApi
end

local function normalisePackage(packageDir, folderName, manifest, manifestPath)
    local package = {}

    package.id = tostring(manifest.id or folderName)
    package.name = tostring(manifest.name or package.id)
    package.version = tostring(manifest.version or "unknown")
    package.description = tostring(manifest.description or "")
    package.author = tostring(manifest.author or "")
    package.entry = tostring(manifest.entry or "main.lua")
    package.order = tonumber(manifest.order or 1000) or 1000
    package.hidden = manifest.hidden == true
    package.disabled = manifest.disabled == true
    package.path = packageDir
    package.manifestPath = manifestPath

    return package
end

local function readManifest(manifestPath)
    local chunk, loadError = loadfile(manifestPath)

    if not chunk then
        return nil, loadError
    end

    local ok, manifest = pcall(chunk)

    if not ok then
        return nil, manifest
    end

    if type(manifest) ~= "table" then
        return nil, "manifest did not return a table"
    end

    return manifest, nil
end

local function findManifest(packageDir)
    for _, manifestName in ipairs(manifestNames) do
        local manifestPath = fs.combine(packageDir, manifestName)

        if fs.exists(manifestPath) and not fs.isDir(manifestPath) then
            return manifestPath
        end
    end

    return nil
end

function PackageManager.ensurePackageRoot()
    if not fs.exists(PackageManager.packageRoot) then
        fs.makeDir(PackageManager.packageRoot)
    end
end

function PackageManager.listPackages(includeHidden)
    PackageManager.ensurePackageRoot()

    local packages = {}
    local errors = {}

    for _, folderName in ipairs(fs.list(PackageManager.packageRoot)) do
        local packageDir = fs.combine(PackageManager.packageRoot, folderName)

        if fs.isDir(packageDir) then
            local manifestPath = findManifest(packageDir)

            if manifestPath then
                local manifest, err = readManifest(manifestPath)

                if manifest then
                    local package = normalisePackage(packageDir, folderName, manifest, manifestPath)

                    if not package.disabled and (includeHidden or not package.hidden) then
                        table.insert(packages, package)
                    end
                else
                    table.insert(errors, folderName .. ": " .. tostring(err))
                end
            end
        end
    end

    table.sort(packages, function(a, b)
        if a.order == b.order then
            return a.name:lower() < b.name:lower()
        end

        return a.order < b.order
    end)

    return packages, errors
end

function PackageManager.findPackage(idOrName)
    local query = tostring(idOrName or ""):lower()
    local packages = PackageManager.listPackages(true)

    for _, package in ipairs(packages) do
        if package.id:lower() == query or package.name:lower() == query then
            return package
        end
    end

    return nil
end

function PackageManager.resolveEntry(package)
    local entry = package.entry or "main.lua"
    local packagedEntry = fs.combine(package.path, entry)

    if fs.exists(packagedEntry) and not fs.isDir(packagedEntry) then
        return packagedEntry, true
    end

    -- This keeps old KpOS apps working while still letting new packages keep
    -- their own files inside ios/packages/<id>/.
    if fs.exists(entry) and not fs.isDir(entry) then
        return entry, false
    end

    return packagedEntry, true
end

local function runWithOsRun(entry, shellApi)
    if not os.run then
        return false, "No shell API or os.run available to launch: " .. entry
    end

    local env = copyGlobals()

    -- Give programs launched without shell.run the shell API when we have it.
    if shellApi then
        env.shell = shellApi
    end

    local ok, err = os.run(env, entry)
    if not ok then
        return false, err
    end

    return true, nil
end

function PackageManager.runPackage(package, shellApi)
    if not package then
        error("No package selected")
    end

    local entry, isPackagedEntry = PackageManager.resolveEntry(package)

    if not fs.exists(entry) then
        error("Package '" .. package.name .. "' is missing entry file: " .. entry)
    end

    local sh = getShell(shellApi)

    if sh and sh.run then
        if sh.setDir and sh.dir and isPackagedEntry then
            local previousDir = sh.dir()
            local ok, err = pcall(function()
                sh.setDir(package.path)
                sh.run(package.entry or "main.lua")
            end)

            sh.setDir(previousDir)

            if not ok then
                error(err)
            end
        else
            sh.run(entry)
        end

        return
    end

    local ok, err = runWithOsRun(entry, sh)
    if not ok then
        error(err)
    end
end

return PackageManager
