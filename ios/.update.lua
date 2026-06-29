print("this is currently in beta! expect bugs")
print("1: update os")
print("2: update package[currently unavailable]")
write("> ")

local choice = read()

if choice == "1" then
    print("Starting OS update...")
    print("Running: pastebin run s4LQmMW7")

    if shell and shell.run then
        local ok = shell.run("pastebin", "run", "s4LQmMW7")

        if not ok then
            print("Update failed or pastebin script exited with an error.")
            print("Make sure HTTP is enabled and the pastebin code is correct.")
        end
    else
        print("Error: shell API is not available.")
        print("Run this file from the normal CraftOS/CC:Tweaked shell.")
    end

elseif choice == "2" then
    print("Package updates are currently unavailable.")

else
    print("Invalid option.")
end
