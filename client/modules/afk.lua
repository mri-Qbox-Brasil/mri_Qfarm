-- Farm AFK, sem rotas, parado no mesmo lugar

local Config = lib.require("shared/config")
local Utils = lib.require("shared/utils")
local Defaults = lib.require("client/defaults")
local Text = lib.require("client/interaction/texts")
local Shared = lib.require("client/modules/shared")
local InteractionHandler = lib.require("client/interaction/handler")

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
end

local function clear()
    for k in pairs(Farms) do
        remove(k)
    end
end

local function startFarming(args)
    Utils.debug("startFarming", args)
    Shared.clearFarmData(farmData)
    farmData.isFarming = true
    farmData.playerFarm = args.farm
    farmData.farmingItemName = args.itemName
    farmData.farmItem = farmData.playerFarm.config.items[farmData.farmingItemName]

    Utils.sendNotification(
        {
            description = locale("text.start_shift", farmData.farmItem["customName"] or Utils.items[farmData.farmingItemName].label),
            type = "info"
        }
    )

    if farmData.farmItem == nil then
        Shared.stopFarming(farmData)
        return
    end

    Shared.farmThread(farmData)

    if Config.ShowOSD then
        Text.add(
            {
                name = "farming",
                data = {
                    text = locale("actions.stop_f7"),
                    delay = 1000,
                    type = 1
                }
            }
        )
    end

    while farmData.isFarming do
        if farmData.isTasking then
             Wait(1000)
        else
            if not Shared.checkInteraction(farmData) then
                Shared.stopFarming(farmData, true)
                return
            end

            if not farmData.farmItem.unlimited and farmData.amountCollected >= (farmData.farmItem.max or 100) then
                if not exports.ox_inventory:CanCarryItem(cache.source, farmData.farmingItemName, 1) then
                    Utils.sendNotification({description = locale("error.inventory_full"), type = "error"})
                    Shared.stopFarming(farmData)
                    return
                end
            end

            farmData.isTasking = true

            local duration = farmData.farmItem["collectTime"] or Defaults.CollectTime

            local description = locale("progress.pick_farm", Utils.items[farmData.farmingItemName].label)

            if Utils.actionProcess(description, duration) then
                 lib.callback.await("mri_Qfarm:server:getRewardItem", false, farmData.farmingItemName, farmData.playerFarm.farmId)
                 farmData.amountCollected = farmData.amountCollected + 1
            end

            farmData.isTasking = false
            Wait(1000)
        end
    end
end

local function loadFarms()
    Utils.debug("AFK", "loadFarms")
    for k, v in pairs(Farms or {}) do
        if v.config and v.config.start and v.config.start.location then
             local start = v.config.start
             start.location = vector3(start.location.x, start.location.y, start.location.z)
             local zoneName = string.format("farm-start-%s", k)
             InteractionHandler.add(
                 {
                     name = zoneName,
                     data = {
                         name = zoneName,
                         debug = Config.Debug,
                         coords = start.location,
                         color = {
                             r = 0,
                             g = 255,
                             b = 0,
                             a = 255
                         },
                         size = vector3(Config.FarmBoxWidth, Config.FarmBoxLength, Config.FarmBoxHeight),
                         options = {
                             icon = "fa-solid fa-clock",
                             label = locale("text.open_farm", v.name),
                             onSelect = function()
                                 Shared.showFarmMenu(v, farmData, startFarming)
                             end
                         },
                         inside = function()
                             lib.showTextUI("[E] " .. locale("text.open_farm", v.name))
                             if IsControlJustReleased(0, 38) then
                                 Shared.showFarmMenu(v, farmData, startFarming)
                             end
                         end,
                         onExit = function()
                             lib.hideTextUI()
                         end
                     }
                 }
             )
        end
    end
end

return {
    add = add,
    clear = clear,
    loadFarms = loadFarms
}
