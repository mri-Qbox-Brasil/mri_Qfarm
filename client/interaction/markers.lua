local markers = {}

local function add(item)
    if Config.Debug then
        print(string.format("Adding element: %s", item.name))
    end
    markers[item.name] = item.data
end

local function remove(name)
    if Config.Debug then
        print(string.format("Removing element: %s", name))
    end
    markers[name] = nil
end

local function clear()
    if #markers > 0 then
        for k, v in pairs(markers) do
            remove(k)
        end
    end
end

CreateThread(
    function()
        while true do
            for k, v in pairs(markers) do
                local playerLoc = GetEntityCoords(cache.ped)
                if
                    GetDistanceBetweenCoords(
                        playerLoc.x,
                        playerLoc.y,
                        playerLoc.z,
                        v.coords.x,
                        v.coords.y,
                        v.coords.z,
                        true
                    ) <= 30
                 then
                    DrawMarker(
                        v.type,
                        v.coords.x,
                        v.coords.y,
                        v.coords.z + 0.3,
                        0.0,
                        0.0,
                        0.0,
                        0.0,
                        0.0,
                        0.0,
                        0.3,
                        0.3,
                        0.3,
                        v.color.r,
                        v.color.g,
                        v.color.b,
                        v.color.a,
                        false,
                        true,
                        2,
                        false,
                        false,
                        false,
                        false
                    )
                end
            end
            Wait(0)
        end
    end
)

return {
    add = add,
    remove = remove,
    clear = clear
}
