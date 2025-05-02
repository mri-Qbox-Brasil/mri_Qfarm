local ImageURL = "https://cfx-nui-ox_inventory/web/images"

local Utils = lib.require("shared/utils")
local Defaults = require("client/defaults")
local Blips = lib.require("client/interaction/blips")
local Markers = lib.require("client/interaction/markers")
local Texts = lib.require("client/interaction/texts")
local Targets = lib.require("client/interaction/targets")
local Zones = lib.require("client/interaction/zones")

local Farms = {}

local isFarming = false
local isTasking = false
local playerFarm = nil
local farmingItemName = nil
local amountCollected = 0
local currentPoint = 0

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

local function checkInteraction(farmItem)
    if not isFarming then
        Utils.debug("checkInteraction", "isFarming is false")
        return false
    end

    if IsPedInAnyVehicle(cache.ped, false) then
        -- Verifica se o player esta em um veiculo
        Utils.sendNotification(
            {
                id = "farm:error.not_in_vehicle",
                description = locale("error.not_in_vehicle"),
                type = "error"
            }
        )
        Utils.debug("checkInteraction", "isPedInAnyVehicle is true")
        return false
    end

    if
        playerFarm.config["vehicle"] and
            not IsVehicleModel(GetVehiclePedIsIn(PlayerPedId(), true), GetHashKey(playerFarm.config["vehicle"]))
     then
        -- Verifica se o player esta no veículo certo
        Utils.sendNotification(
            {
                id = "farm:error.incorrect_vehicle",
                description = locale("error.incorrect_vehicle"),
                type = "error"
            }
        )
        Utils.debug("checkInteraction", "isPedInAnyVehicle is true")
        return false
    end

    local collectItem = farmItem["collectItem"] or {}
    local collectItemName = collectItem["name"] or nil
    local collectItemDurability = collectItem["durability"] or 0

    if collectItemName then
        local toolItems = Utils.inventory:Search("slots", collectItemName)
        if not toolItems then
            -- Verifica se o player tem o item certo
            Utils.sendNotification(
                {
                    id = "farm:error.no_item",
                    description = locale("error.no_item", collectItemName),
                    type = "error"
                }
            )
            Utils.debug("checkInteraction", "toolItems is nil")
            return false
        end

        if collectItemDurability and collectItemDurability > 0 then
            local toolItem
            for k, v in pairs(toolItems) do
                if v["metadata"] and v.metadata["durability"] and v.metadata.durability then
                    toolItem = v
                    break
                end
            end

            if toolItem then
                if toolItem.metadata.durability < collectItemDurability then
                    -- Verifica se o item tem durabilidade
                    Utils.sendNotification(
                        {
                            id = "farm:error.low_durability",
                            description = locale("error.low_durability", Items[collectItemName].label),
                            type = "error"
                        }
                    )
                    Utils.debug("checkInteraction", "toolItem.metadata.durability is less than collectItemDurability")
                    return false
                end
            else
                -- Verifica se o item configurado está correto
                Utils.sendNotification(
                    {
                        id = "farm:error.invalid_item_type",
                        description = locale("error.invalid_item_type", collectItemName),
                        type = "error"
                    }
                )
                Utils.debug("checkInteraction", "toolItem is nil")
                return false
            end
        end
    end

    return true
end

local function openPoint(farmItem)
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
    ExecuteCommand("e c")
    ClearPedTasks(cache.ped)
end

function clearPoint(name)
    if name == nil then
        return
    end

    Blips.remove(name)
    if Config.ShowMarker then
        Markers.remove(name)
    end
    if Config.UseTarget then
        Targets.remove(name)
    else
        Zones.remove(name)
    end
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
    if Config.UseTarget then
        Targets.add(
            {
                name = zoneName,
                data = {
                    coords = vec3(farmPoint.x, farmPoint.y, farmPoint.z),
                    name = zoneName,
                    options = {
                        icon = "fa-solid fa-screwdriver-wrench",
                        label = locale("target.label", farmItem.label),
                        canInteract = function()
                            return checkInteraction(farmItem)
                        end,
                        onSelect = function()
                            openPoint(farmItem)
                            clearPoint(zoneName)
                        end
                    }
                }
            }
        )
    else
        Zones.add(
            {
                name = zoneName,
                data = {
                    coords = vec3(farmPoint.x, farmPoint.y, farmPoint.z),
                    size = vector3(1.0, 1.0, 1.0),
                    debug = Config.Debug,
                    onEnter = function()
                        lib.showTextUI(locale("task.start_task"))
                        if IsControlJustReleased(0, 38) and checkInteraction(farmItem) then
                            openPoint(farmItem)
                            clearPoint(zoneName)
                        end
                    end
                }
            }
        )
    end
end

local function stopFarming(isCancel)
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
        ExecuteCommand("e c")
        ClearPedTasks(cache.ped)
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
                icon = string.format("%s/%s.png", ImageURL, item.name),
                image = string.format("%s/%s.png", ImageURL, item.name),
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
    for k, v in pairs(Farms) do
        local start = v.config.start
        start.location = vector3(start.location.x, start.location.y, start.location.z)
        local zoneName = string.format("farm-start-%s", k)
        if Config.UseTarget then
            Targets.add(
                {
                    name = zoneName,
                    data = {
                        coords = start.location,
                        name = zoneName,
                        options = {
                            icon = "fa-solid fa-screwdriver-wrench",
                            label = locale("text.open_farm", v.name),
                            onSelect = function()
                                showFarmMenu(v)
                            end
                        }
                    }
                }
            )
        else
            Zones.add(
                {
                    name = zoneName,
                    data = {
                        coords = start.location,
                        size = vector3(start.length, start.width, 1.0),
                        debug = Config.Debug,
                        onEnter = function()
                            showFarmMenu(v)
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
