local Utils = lib.require("shared/utils")
local elements = {}

local function add(item)
    Utils.debug("Adding zone", item.name)
    elements[item.name] = lib.zones.box(item.data)
end

local function remove(name)
    Utils.debug("Removing zone", name)
    elements[name]:remove()
    elements[name] = nil
end

local function removeGroup(group)
    for k, v in pairs(elements) do
        if string.find(k, group, 1, true) then
            remove(k)
        end
    end
end

local function clear()
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
