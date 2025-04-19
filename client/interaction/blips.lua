local blips = {}

local function add(item)
    local b = AddBlipForCoord(item.data.coords.x, item.data.coords.y, item.data.coords.z)
    SetBlipSprite(b, item.data.sprite)
    SetBlipColour(b, item.data.color)
    SetBlipScale(b, item.data.scale)
    SetBlipAsShortRange(b, item.data.shortRange)
    SetBlipRoute(b, item.data.route)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(item.data.text)
    EndTextCommandSetBlipName(b)
    blips[item.name] = {id = b, data = item.data}
    return b
end

local function remove(name)
    if DoesBlipExist(blips[name].id) then
        RemoveBlip(blips[name].id)
        blips[name] = nil
    end
end

local function clear()
    for b, _ in pairs(blips) do
        remove(b)
    end
end

return {
    add = add,
    remove = remove,
    clear = clear
}
