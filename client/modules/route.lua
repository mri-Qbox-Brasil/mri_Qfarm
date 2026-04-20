-- Farm com rotas, iniciando o turno
local Utils = lib.require("shared/utils")
local Blips = lib.require("client/interaction/blips")
local Texts = lib.require("client/interaction/texts")
local Zones = lib.require("client/interaction/zones")
local Config = lib.require("shared/config")
local Shared = lib.require("client/modules/shared")
local Markers = lib.require("client/interaction/markers")
local Targets = lib.require("client/interaction/targets")
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
    if #Farms > 0 then
        for k, v in pairs(Farms) do
            remove(k)
        end
    end
end

local function stopFarming(isCancel)
    Utils.debug("stopFarming", isCancel)

    Shared.clearFarmData(farmData)

    if Config.ShowOSD then
        Texts.remove("farming")
    end

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

    if isCancel then
        Utils.stopAnimations()
    end

    Utils.sendNotification(
        {
            description = isCancel and locale("text.cancel_shift") or locale("text.end_shift"),
            type = isCancel and "error" or "info"
        }
    )
end

local function farmThread()
    CreateThread(
        function()
            while (farmData.isFarming) do
                if IsControlJustReleased(0, 168) then
                    stopFarming(true)
                end
                Wait(0)
            end
        end
    )
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
        stopFarming()
        return
    end

    if farmData.farmItem.points == nil or #farmData.farmItem.points == 0 then
        stopFarming()
        return
    end

    farmThread()

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
                stopFarming()
                return
            end
            Shared.nextTask(farmData)
            Wait(5)
        end
    end
end

local function showFarmMenu(farm)
    if not Utils.checkPerms(farm) then
        return
    end

    local ctx = {
        id = "farm_menu",
        title = farm.name,
        icon = "fa-solid fa-briefcase",
        options = {}
    }
    for itemName, v in pairs(farm.config.items) do
        local item = Utils.items[itemName]
        if not (item == nil) then
            ctx.options[#ctx.options + 1] = {
                title = v["customName"] and v["customName"] ~= "" and v["customName"] or item.label,
                description = item.description,
                icon = string.format("%s/%s.png", Config.ImageURL, item.name),
                image = string.format("%s/%s.png", Config.ImageURL, item.name),
                metadata = Utils.getItemMetadata(item, true),
                disabled = farmData.isFarming,
                onSelect = startFarming,
                args = {
                    farm = farm,
                    itemName = itemName
                }
            }
        end
    end

    if (farmData.isFarming) then
        local item = Utils.items[farmData.farmingItemName]
        ctx.options[#ctx.options + 1] = {
            title = locale("menus.cancel_farm"),
            icon = "fa-solid fa-ban",
            description = item.label,
            onSelect = function()
                stopFarming(true)
            end
        }
    end
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
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
                            showFarmMenu(v)
                        end
                    },
                    inside = function()
                        lib.showTextUI("[E] " .. locale("text.open_farm", v.name))
                        if IsControlJustReleased(0, 38) then
                            showFarmMenu(v)
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
