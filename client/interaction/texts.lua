local texts = {}

local function add(item)
    if Config.Debug then
        print(string.format("Adding element: %s", item.name))
    end
    texts[item.name] = item.data
end

local function remove(name)
    if Config.Debug then
        print(string.format("Removing element: %s", name))
    end
    texts[name] = nil
end

local function clear()
    if #texts > 0 then
        for k, v in pairs(texts) do
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
        for k, v in pairs(texts) do
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
