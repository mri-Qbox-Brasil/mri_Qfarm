local zones = {}

local function add(item)
    if Config.Debug then
        print(string.format("Adding element: %s", item.name))
    end
    zones[item.name] = lib.zones.box(item.data)
end

local function remove(name)
    if Config.Debug then
        print(string.format("Removing element: %s", name))
    end
    zones[name]:remove()
    zones[name] = nil
end

local function clear()
    if #zones > 0 then
        for k, v in pairs(zones) do
            remove(k)
        end
    end
end

return {
    add = add,
    remove = remove,
    clear = clear
}
