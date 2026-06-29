-- Fix: Lua comments use '--', not '#'
-- os.pullEvent = os.pullEventRaw

-- system vars
ProgramCount = 7
OSV = "alpha 0.0.1"

-- 1. Define our functions first so Lua knows they exist
local w, h = term.getSize()

local function printCentered(y, s)
   local x = math.floor((w - string.len(s)) / 2)
   term.setCursorPos(x, y)
   term.clearLine()
   term.write(s)
end

local nOption = 1

local function drawMenu()
   term.clear()
   term.setCursorPos(1, 1)
   term.write("KpOS " .. OSV)
   term.setCursorPos(1, 2)

   if shell.resolve("id") then
      shell.run("id")
   else
      term.write("ID: Unknown")
   end

   term.setCursorPos(1, 3)

   term.setCursorPos(w-7, 1)
   if nOption == 1 then
      term.write("Command")
   elseif nOption == 2 then
      term.write("Programs")
   elseif nOption == 3 then
      term.write("update")
   elseif nOption == 4 then
      term.write("InstallPKG")
   elseif nOption == 5 then
      term.write("shutdown")
   elseif nOption == 6 then
      term.write("reboot")
   elseif nOption == 7 then
      term.write("uninstall")
   end
end

-- GUI
local function drawFrontend()
   printCentered(math.floor(h/2) - 3, "")
   printCentered(math.floor(h/2) - 2, "Start Menu")
   printCentered(math.floor(h/2) - 1, "")
   printCentered(math.floor(h/2) + 0, ((nOption == 1) and "[ Command  ]") or "Command ")
   printCentered(math.floor(h/2) + 1, ((nOption == 2) and "[ Programs ]") or "Programs")
   printCentered(math.floor(h/2) + 2, ((nOption == 3) and "[ Update   ]") or "Update  ")
   printCentered(math.floor(h/2) + 2, ((nOption == 4) and "[ InstallPKG ]") or "InstallPKG")
   printCentered(math.floor(h/2) + 3, ((nOption == 5) and "[ Shutdown ]") or "Shutdown")
   printCentered(math.floor(h/2) + 4, ((nOption == 6) and "[ Reboot   ]") or "Reboot  ")
   printCentered(math.floor(h/2) + 5, ((nOption == 7) and "[ Uninstall ]") or " Uninstall")
   printCentered(math.floor(h/2) + 6, "")
end

local function runSelectedProgram()
   local path = ""

   if nOption == 1 then
      path = "ios/.command.lua"
   elseif nOption == 2 then
      path = "ios/.programs.lua"
   elseif nOption == 3 then
      path = "ios/.update.lua"
   elseif nOption == 4 then
      path = "ios/install_package.lua"
   elseif nOption == 5 then
   term.write(">shutdown")
   term.setCursorPos(1, 2)
   term.write("Goodbye")
   sleep(3)
      os.shutdown()
   elseif nOption == 6 then
      os.reboot()
   else
      path = "ios/.UninstallDialog.lua"
   end

   if fs.exists(path) then
      shell.run(path)
   else
      error("Missing system file: " .. path)
   end
end -- FIX 2: Added missing end here to close runSelectedProgram

-- 2. Wrap your main runtime loop/execution inside the main function
local function main()
   drawMenu()
   drawFrontend()

   while true do
      local e, p = os.pullEvent()
      if e == "key" then
         local key = p

         if key == keys.s or key == keys.down then
            if nOption < ProgramCount then
               nOption = nOption + 1
               drawMenu()
               drawFrontend()
            end
         elseif key == keys.w or key == keys.up then
            if nOption > ProgramCount - 6 then
               nOption = nOption - 1
               drawMenu()
               drawFrontend()
            end
         elseif key == keys.enter then
            break
         end
      end
   end

   term.clear()
   term.setCursorPos(1, 1)

   -- FIX 3: Moved execution to happen safely after menu selection wraps up
   runSelectedProgram()
end -- FIX 1: Added missing end here to close main()

-- 3. Run the main function safely with pcall
local success, errorMessage = pcall(main)

-- 4. Check the result
if not success then
    term.clear()
    term.setCursorPos(1, 1)
    print("KpOS has encountered a problem:")
    print(errorMessage)

    for i = 10, 1, -1 do
        term.setCursorPos(1, 5) -- Bumped to line 5 so it doesn't overwrite long errors
        term.clearLine()
        term.write("Rebooting in " .. i)
        os.sleep(1)
    end

    os.reboot()
end
