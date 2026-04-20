-- Farm com rotas, sem iniciar o turno
local Utils = lib.require("shared/utils")
local Blips = lib.require("client/interaction/blips")
local Texts = lib.require("client/interaction/texts")
local Zones = lib.require("client/interaction/zones")
local Config = lib.require("shared/config")
local Markers = lib.require("client/interaction/markers")
local Targets = lib.require("client/interaction/targets")
local Defaults = lib.require("client/defaults")
local Shared = lib.require("client/modules/shared")

local Farms = {}
local farmData = {
    isFarming = false,
    isTasking = false,
    currentPoint = 0,
    amountCollected = 0,
    playerFarm = nil,
    farmingItemName = nil
}

local function add(item)
    if Utils.checkPerms(item) then
        Utils.debug(string.format("Adding element: %s", item.name))
        Farms[item.name] = item
    else
        Utils.debug(string.format("Skipping element: %s", item.name))
    end
end

local function remove(name)
    Utils.debug(string.format("Removing element: %s", name))
    Farms[name] = nil
    if farmData.playerFarm and farmData.playerFarm.name == name then
         farmData.isFarming = false
    end
end

local function clear()
    for k in pairs(Farms) do
        remove(k)
    end
end

local function stopFarming()
    farmData.isFarming = false
    Shared.clearFarmData(farmData)
     if Config.Interaction == "target" then
        Targets.removeGroup("farm-point")
    elseif Config.Interaction == "zone" then
        Zones.removeGroup("farm-point")
    end
    if Config.ShowMarker then
        Markers.removeGroup("farm-point")
    end
    Blips.removeGroup("farm-point")
    lib.hideTextUI()
end

local function farmThread()
    CreateThread(function()
        while farmData.isFarming do
            if farmData.isTasking then
                Wait(5000)
            else
                if not farmData.farmItem.unlimited and farmData.amountCollected >= #farmData.farmItem.points then
                    if farmData.farmItem.unlimited then
                         farmData.currentPoint = 0
                    else
                         farmData.currentPoint = 0
                         farmData.amountCollected = 0
                    end
                end

                Shared.nextTask(farmData)
                Wait(500)
            end
        end
    end)
end

local function startAutoFarm(args)
    if farmData.isFarming then return end

    farmData.isFarming = true
    farmData.isTasking = false
    farmData.currentPoint = 0
    farmData.amountCollected = 0
    farmData.playerFarm = args.farm
    farmData.farmingItemName = args.itemName
    farmData.farmItem = farmData.playerFarm.config.items[farmData.farmingItemName]

    farmThread()
end

local function loadFarms()
    for k, v in pairs(Farms or {}) do
        if v.config and v.config.items then
            for itemName, _ in pairs(v.config.items) do
            local item = Utils.items[itemName]
            if not (item == nil) then
                startAutoFarm(
                    {
                        farm = v,
                        itemName = itemName
                    }
                )
                return
            end
            end
        end
    end
end

return {
    add = add,
    clear = clear,
    loadFarms = loadFarms
}
