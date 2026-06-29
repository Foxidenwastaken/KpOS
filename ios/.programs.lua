local packageManager = dofile("ios/lib/package_manager.lua")
if packageManager.setShell then
    packageManager.setShell(shell)
end

local packages, packageErrors = packageManager.listPackages(false)
local ProgramCount = #packages + 1 -- Back + installed packages

local w, h = term.getSize()
local nOption = 1

local function printCentered(y, s)
   local x = math.floor((w - string.len(s)) / 2) + 1
   if x < 1 then
      x = 1
   end

   term.setCursorPos(x, y)
   term.clearLine()
   term.write(s)
end

local function selectedLabel()
   if nOption == 1 then
      return "Back"
   end

   local package = packages[nOption - 1]
   if package then
      return package.name
   end

   return "Unknown"
end

local function drawHeader()
   term.clear()
   term.setCursorPos(1, 1)
   term.write("KpOS Packages")

   term.setCursorPos(1, 2)
   if shell.resolve("id") then
      shell.run("id")
   else
      term.write("ID: Unknown")
   end

   local label = selectedLabel()
   term.setCursorPos(math.max(1, w - string.len(label) + 1), 1)
   term.write(label)
end

local function drawFrontend()
   local startY = math.floor(h / 2) - math.floor(ProgramCount / 2)

   printCentered(startY - 2, "Programs")
   printCentered(startY - 1, "")

   printCentered(startY, ((nOption == 1) and "[ Back ]") or "Back")

   if #packages == 0 then
      printCentered(startY + 1, "No packages installed")
   else
      for index, package in ipairs(packages) do
         local label = package.name

         if package.version and package.version ~= "unknown" then
            label = label .. " v" .. package.version
         end

         if nOption == index + 1 then
            label = "[ " .. label .. " ]"
         end

         printCentered(startY + index, label)
      end
   end

   if #packageErrors > 0 then
      printCentered(h - 1, tostring(#packageErrors) .. " package load error(s)")
   end
end

local function runSelectedProgram()
   if nOption == 1 then
      shell.run("exit.lua")
      return
   end

   local package = packages[nOption - 1]
   packageManager.runPackage(package, shell)

   print("")
   print("Press any key to return to KpOS.")
   os.pullEvent("key")
   shell.run(".menu")
end

local function main()
   drawHeader()
   drawFrontend()

   while true do
      local e, p = os.pullEvent()
      if e == "key" then
         local key = p

         if key == keys.s or key == keys.down then
            if nOption < ProgramCount then
               nOption = nOption + 1
               drawHeader()
               drawFrontend()
            end
         elseif key == keys.w or key == keys.up then
            if nOption > 1 then
               nOption = nOption - 1
               drawHeader()
               drawFrontend()
            end
         elseif key == keys.enter then
            break
         end
      end
   end

   term.clear()
   term.setCursorPos(1, 1)
   runSelectedProgram()
end

local success, errorMessage = pcall(main)

if not success then
   term.clear()
   term.setCursorPos(1, 1)
   print("KpOS has encountered a package menu problem:")
   print(errorMessage)

   if packageErrors and #packageErrors > 0 then
      print("")
      print("Package load errors:")
      for _, err in ipairs(packageErrors) do
         print("- " .. err)
      end
   end

   print("")
   print("Press any key to return to KpOS.")
   os.pullEvent("key")
   shell.run(".menu")
end
