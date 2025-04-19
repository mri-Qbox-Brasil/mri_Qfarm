local targets = {}
local target = exports.ox_target

local function add(item)
    if Config.Debug then
        print(string.format("Adding element: %s", item.name))
    end
    target:addSphereZone(item.data)
    targets[item.name] = item.data
end

local function remove(name)
    if Config.Debug then
        print(string.format("Removing element: %s", name))
    end
    target:removeZone(targets[name])
    targets[name] = nil
end

local function clear(tableObj)
    if #targets > 0 then
        for k, v in pairs(targets) do
            remove(k)
        end
    end
end

return {
    add = add,
    remove = remove,
    clear = clear
}
