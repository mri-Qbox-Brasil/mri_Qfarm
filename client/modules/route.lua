-- Farm com rotas, iniciando o turno
local Utils = lib.require("shared/utils")
local Blips = lib.require("client/interaction/blips")
local Texts = lib.require("client/interaction/texts")
local Zones = lib.require("client/interaction/zones")
local Config = require("shared/config")
local Shared = lib.require("client/modules/shared")
local Markers = lib.require("client/interaction/markers")
local Targets = lib.require("client/interaction/targets")
local Defaults = require("client/defaults")
local InteractionHandler = lib.require("client/interaction/handler")

local Farms = {}

local isFarming = false
local isTasking = false
local playerFarm = nil
local farmingItemName = nil
local amountCollected = 0
local currentPoint = 0

local function checkInteraction(farmItem, playerFarm)
    if not isFarming then
        Utils.debug("checkInteraction", "isFarming is false")
        return false
    end

    return Shared.checkInteraction(farmItem, playerFarm)
end

local function add(item)
    local isPublic = Utils.isPublic(item)
    if
        isPublic or Utils.roleCheck(PlayerJob, item.group.name, item.group.grade) or
            Utils.roleCheck(PlayerGang, item.group.name, item.group.grade)
     then
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

local function openPoint(farmItem)
    Utils.debug("openPoint", farmItem)
    lib.hideTextUI()
    local duration = farmItem["collectTime"] or Defaults.CollectTime
    local animation = nil

    if (farmItem["animation"]) then
        animation = farmItem.animation
    else
        if Config.UseEmoteMenu then
            animation = Defaults.AnimCmd
        else
            animation = Defaults.Anim
            animation["duration"] = duration
        end
    end

    Utils.pickAnim(animation)

    local itemRegister = Utils.items[farmingItemName]
    local collectItem = farmItem["collectItem"] or {}

    if collectItem["name"] and collectItem["durability"] then
        lib.callback.await("mri_Qfarm:server:UseItem", false, farmItem)
    end

    if (farmItem["gainStress"] and farmItem["gainStress"]["max"]) or 0 > 0 then
        lib.callback.await("mri_Qfarm:server:GainStress", false, farmItem)
    end

    if Utils.actionProcess(locale("progress.pick_farm", itemRegister.label), duration) then
        Utils.debug("openPoint", "actionProcess is true")
        lib.callback.await("mri_Qfarm:server:getRewardItem", false, farmingItemName, playerFarm.farmId)
        amountCollected = amountCollected + 1
    end

    isTasking = false
    Utils.stopAnimations()
end

function clearPoint(name)
    Utils.debug("clearPoint", name)
    if name == nil then
        return
    end

    Blips.remove(name)
    if Config.ShowMarker then
        Markers.remove(name)
    end

    InteractionHandler.remove(name)
end

local function nextTask(farmItem)
    if isTasking then
        return
    end

    isTasking = true

    if farmItem.randomRoute then
        currentPoint = math.random(1, #(farmItem.points))
    else
        if farmItem.unlimited and currentPoint >= #(farmItem.points) then
            currentPoint = 1
        else
            currentPoint = currentPoint + 1
        end
    end

    local farmPoint = farmItem.points[currentPoint]

    local blip = Defaults.New(Defaults.Blip)

    blip.coords = vec3(farmPoint.x, farmPoint.y, farmPoint.z)
    local zoneName = string.format("farm-point-%s", currentPoint)
    Blips.add({name = zoneName, data = blip})
    if Config.ShowMarker then
        local marker = Defaults.New(Defaults.Marker)
        marker.coords = vec3(farmPoint.x, farmPoint.y, farmPoint.z)
        Markers.add({name = zoneName, data = marker})
    end
    InteractionHandler.add(
        {
            name = zoneName,
            data = {
                name = zoneName,
                debug = Config.Debug,
                coords = farmPoint,
                color = {
                    r = 255,
                    g = 255,
                    b = 0,
                    a = 255
                },
                size = vector3(Config.FarmBoxWidth, Config.FarmBoxLength, Config.FarmBoxHeight),
                options = {
                    icon = "fa-solid fa-screwdriver-wrench",
                    label = locale("target.label", farmItem.label),
                    canInteract = function()
                        return checkInteraction(farmItem, playerFarm)
                    end,
                    onSelect = function()
                        openPoint(farmItem)
                        clearPoint(zoneName)
                    end
                },
                inside = function()
                    lib.showTextUI("[E] " .. locale("target.label", farmItem.label))
                    if IsControlJustReleased(0, 38) and checkInteraction(farmItem, playerFarm) then
                        openPoint(farmItem)
                        clearPoint(zoneName)
                    end
                end,
                onExit = function()
                    lib.hideTextUI()
                end
            }
        }
    )
end

local function stopFarming(isCancel)
    Utils.debug("stopFarming", isCancel)
    isTasking = false
    isFarming = false
    amountCollected = 0
    playerFarm = nil
    farmingItemName = nil

    if Config.ShowOSD then
        Texts.remove("farming")
    end

    if Config.UseTarget then
        Targets.removeGroup("farm-point")
    else
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
            while (isFarming) do
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
    isFarming = true
    playerFarm = args.farm
    farmingItemName = args.itemName
    amountCollected = 0
    local farmItem = playerFarm.config.items[farmingItemName]

    Utils.sendNotification(
        {
            description = locale("text.start_shift", farmItem["customName"] or Utils.items[farmingItemName].label),
            type = "info"
        }
    )

    if farmItem == nil then
        stopFarming()
        return
    end

    if farmItem.points == nil or #farmItem.points == 0 then
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
    while isFarming do
        if tasking then
            Wait(5000)
        else
            if not farmItem.unlimited and amountCollected >= #farmItem.points then
                stopFarming()
                return
            end
            nextTask(farmItem)
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
                disabled = isFarming,
                onSelect = startFarming,
                args = {
                    farm = farm,
                    itemName = itemName
                }
            }
        end
    end

    if (isFarming) then
        local item = Utils.items[farmingItemName]
        ctx.options[#ctx.options + 1] = {
            title = locale("menus.cancel_farm"),
            icon = "fa-solid fa-ban",
            description = item.label,
            onSelect = cancelFarming
        }
    end
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

local function loadFarms()
    Utils.debug("loadFarms")
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
