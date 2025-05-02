local Utils = lib.require("shared/utils")
local elements = {}

local function add(item)
    Utils.debug("Adding blip", item.name)
    local b = AddBlipForCoord(item.data.coords.x, item.data.coords.y, item.data.coords.z)
    SetBlipSprite(b, item.data.sprite)
    SetBlipColour(b, item.data.color)
    SetBlipScale(b, item.data.scale)
    SetBlipAsShortRange(b, item.data.shortRange)
    SetBlipRoute(b, item.data.route)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(item.data.text)
    EndTextCommandSetBlipName(b)
    elements[item.name] = {id = b, data = item.data}
    return b
end

local function remove(name)
    Utils.debug("Removing blip", name)
    if DoesBlipExist(elements[name].id) then
        RemoveBlip(elements[name].id)
        elements[name] = nil
    end
end

local function removeGroup(group)
    for k, v in pairs(elements) do
        if string.find(k, group, 1, true) then
            remove(k)
        end
    end
end

local function clear()
    for b, _ in pairs(elements) do
        remove(b)
    end
end

return {
    add = add,
    remove = remove,
    removeGroup = removeGroup,
    clear = clear
}
