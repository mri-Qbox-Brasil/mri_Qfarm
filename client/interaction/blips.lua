local blips = {}

local function add(data)
    local b = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    SetBlipSprite(b, data.sprite)
    SetBlipColour(b, data.color)
    SetBlipScale(b, data.scale)
    SetBlipAsShortRange(b, data.shortRange)
    SetBlipRoute(b, data.route)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(data.text)
    EndTextCommandSetBlipName(b)
    blips[b] = data
    return b
end

local function remove(b)
    if b and DoesBlipExist(b) then
        RemoveBlip(b)
        blips[b] = nil
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
