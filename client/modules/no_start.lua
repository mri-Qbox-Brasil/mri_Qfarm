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
    -- Also stop farming if this farm was active?
    -- For 'no_start', multiple farms could theoretically be active if we had multiple threads,
    -- but here we use a single farmData structure, implying one active at a time?
    -- However, the original structure seemed to support checking multiple.
    -- Wait, 'startAutoFarm' sets farmData.
    -- If we want multiple auto-farms active, we need a different structure (table of active farms).
    -- But based on 'farmData' being a single object, it seems it handles one.
    -- Let's stick to the pattern: 'loadFarms' iterates and starts.
    -- If 'startAutoFarm' is called in a loop, it overwrites 'farmData'.
    -- This suggests 'no_start' might have been intended to be "always on" for multiple?
    -- Or maybe it just picks one?
    -- Looking at the original: startAutoFarm was called in a loop in loadFarms.
    -- So it would overwrite and only the last one would be active.
    -- That seems like a bug in the original design if multiple no-start farms exist.
    -- For now I will fix the immediate issue of no logic loop.
    -- I will assume for now we only support one active "route" at a time or I need to refactor to support multiple.
    -- Refactoring to support multiple concurrent farms is out of scope for "fixing errors".
    -- I will implement a thread that handles *current* farmData.
    if farmData.playerFarm and farmData.playerFarm.name == name then
         farmData.isFarming = false -- Stop thread
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
     -- cleanup points
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
                    -- Cycle finished or stop?
                    -- For auto-farm, maybe it resets?
                    if farmData.farmItem.unlimited then
                         farmData.currentPoint = 0
                    else
                         -- If not unlimited, maybe we stop? But it's auto-start...
                         -- Let's assume it loops for now or stops until restart.
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
    if farmData.isFarming then return end -- Already farming something.

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
    for k, v in pairs(Farms) do
        for itemName, _ in pairs(v.config.items) do
            local item = Utils.items[itemName]
            if not (item == nil) then
                -- Check if user has permissions for this farm item if needed
                -- But 'add' already checked permissions for the farm 'item' (which is the farm config object)
                -- So we just start it.
                startAutoFarm(
                    {
                        farm = v,
                        itemName = itemName
                    }
                )
                -- Note: This will only start the FIRST valid one found because startAutoFarm guards against multiple.
                -- This behavior is safer than the original overwrite.
                return -- Stop after starting one to avoid conflict
            end
        end
    end
end

return {
    add = add,
    clear = clear,
    loadFarms = loadFarms
}
