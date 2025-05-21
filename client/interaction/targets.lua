local Utils = lib.require("shared/utils")
local elements = {}

local function add(item)
    Utils.debug("Adding target", item.name)
    if elements[item.name] then
        Utils.debug("Target already exists, skipping", item.name)
        return
    end
    if GetResourceState("ox_target") == "started" then
        item.data["id"] = exports.ox_target:addSphereZone(item.data)
    else
        Utils.debug(locale("error.interaction_not_found", "ox_target"))
        return
    end
    elements[item.name] = item.data
end

local function remove(name)
    Utils.debug("Removing target", name)
    if GetResourceState("ox_target") == "started" then
        exports.ox_target:removeZone(elements[name].id)
    else
        Utils.debug(locale("error.interaction_not_found", "ox_target"))
        return
    end
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
