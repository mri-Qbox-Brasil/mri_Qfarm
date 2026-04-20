-- Farm com rotas, iniciando o turno
local Utils = lib.require("shared/utils")
local Texts = lib.require("client/interaction/texts")
local Config = lib.require("shared/config")
local Shared = lib.require("client/modules/shared")
local Defaults = lib.require("client/defaults")
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
        Utils.debug("Adding route", item.name)
        Farms[item.name] = item
    else
        Utils.debug("Route skipped", item.name)
        return
    end
end

local function remove(name)
    Utils.debug("Removing route", name)
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

    if farmData.farmItem.points == nil or #farmData.farmItem.points == 0 then
        Shared.stopFarming(farmData)
        return
    end

    Shared.farmThread(farmData)

    if Config.ShowOSD then
        Texts.add(
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
            Wait(5000)
        else
            if not farmData.farmItem.unlimited and farmData.amountCollected >= #farmData.farmItem.points then
                Shared.stopFarming(farmData)
                return
            end
            Shared.nextTask(farmData)
            Wait(5)
        end
    end
end

local function loadFarms()
    Utils.debug("Route", "loadFarms")
    for k, v in pairs(Farms) do
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
                        r = 255,
                        g = 255,
                        b = 0,
                        a = 255
                    },
                    size = vector3(Config.FarmBoxWidth, Config.FarmBoxLength, Config.FarmBoxHeight),
                    options = {
                        icon = "fa-solid fa-screwdriver-wrench",
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

return {
    add = add,
    clear = clear,
    loadFarms = loadFarms
}
