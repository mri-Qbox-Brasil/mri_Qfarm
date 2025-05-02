local Utils = lib.require("shared/utils")
local target = exports.ox_target
local elements = {}

local function add(item)
    Utils.debug("Adding target", item.name)
    item.data["id"] = target:addSphereZone(item.data)
    elements[item.name] = item.data
end

local function remove(name)
    Utils.debug("Removing target", name)
    target:removeZone(elements[name].id)
    elements[name] = nil
end

local function removeGroup(group)
    for k, v in pairs(elements) do
        if string.find(k, group, 1, true) then
            remove(k)
        end
    end
end

local function clear(tableObj)
    if #elements > 0 then
        for k, v in pairs(elements) do
            remove(k)
        end
    end
end

return {
    add = add,
    remove = remove,
    removeGroup = removeGroup,
    clear = clear
}
