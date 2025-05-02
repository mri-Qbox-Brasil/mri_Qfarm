local Utils = lib.require("shared/utils")
local elements = {}

local function add(item)
    Utils.debug("Adding text", item.name)
    elements[item.name] = item.data
end

local function remove(name)
    Utils.debug("Removing text", name)
    elements[name] = nil
end

local function clear()
    if #elements > 0 then
        for k, v in pairs(elements) do
            remove(k)
        end
    end
end

local function show(text, delay, type, playSound)
    local type = type or 0
    local delay = delay or 5000
    local playSound = playSound or false
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringKeyboardDisplay(text)
    EndTextCommandDisplayHelp(type, false, playSound, delay)
end

CreateThread(function()
    while true do
        for k, v in pairs(elements) do
            show(v.text, v.delay, v.type, v.playSound)
        end
        Wait(0)
    end
end)

return {
    add = add,
    remove = remove,
    clear = clear
}
