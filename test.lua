-- Small key-test scratch file for KpOS.
-- Press W to print hello, or Q to stop.

while true do
    local event, key = os.pullEvent("key")

    if key == keys.w then
        print("hello")
    elseif key == keys.q then
        break
    end
end
