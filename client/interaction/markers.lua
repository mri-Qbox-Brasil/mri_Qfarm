local Utils = lib.require("shared/utils")
local elements = {}

local function add(item)
    Utils.debug("Adding marker", item.name)
    item.data.isInside = false
    elements[item.name] = item.data
end

local function remove(name)
    Utils.debug("Removing marker", name)
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

CreateThread(
    function()
        local timeToWait = 1000
        while true do
            for k, v in pairs(elements) do
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
                    timeToWait = 0
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
                if
                    v.inside ~= nil and
                        GetDistanceBetweenCoords(
                            playerLoc.x,
                            playerLoc.y,
                            playerLoc.z,
                            v.coords.x,
                            v.coords.y,
                            v.coords.z,
                            true
                        ) <= v.size.x
                 then
                    v.inside()
                    v.isInside = true
                else
                    if v.isInside then
                        if v.onExit ~= nil then
                            v.onExit()
                        end
                        v.isInside = false
                    end
                end
            end
            Wait(timeToWait)
        end
    end
)

return {
    add = add,
    remove = remove,
    removeGroup = removeGroup,
    clear = clear
}
