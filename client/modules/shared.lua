-- Aqui fica tudo que é compartilhado entre os farms
local Utils = lib.require("shared/utils")
local Blips = lib.require("client/interaction/blips")
local Config = lib.require("shared/config")
local Markers = lib.require("client/interaction/markers")
local Defaults = lib.require("client/defaults")
local InteractionHandler = lib.require("client/interaction/handler")

local function isInAnyVehicle()
    if IsPedInAnyVehicle(cache.ped, false) then
        Utils.sendNotification(
            {
                id = "farm:error.not_in_vehicle",
                description = locale("error.not_in_vehicle"),
                type = "error"
            }
        )
        Utils.debug("checkInteraction", "isInAnyVehicle is true")
        return true
    end
    Utils.debug("checkInteraction", "isInAnyVehicle is false")
    return false
end

local function wasInFarmVehicle(playerFarm)
    if playerFarm.config["vehicle"] then
        if IsVehicleModel(GetVehiclePedIsIn(cache.ped, true), GetHashKey(playerFarm.config["vehicle"])) then
            Utils.debug("checkInteraction", "wasInFarmVehicle is true")
            return true
        else
            Utils.sendNotification(
                {
                    id = "farm:error.incorrect_vehicle",
                    description = locale("error.incorrect_vehicle"),
                    type = "error"
                }
            )
            Utils.debug("checkInteraction", "wasInFarmVehicle is false")
            return false
        end
    end
    return true
end

local function hasCollectItemWithDurability(farmItem)
    local collectItem = farmItem["collectItem"] or {}
    local collectItemName = collectItem["name"] or nil
    local collectItemDurability = collectItem["durability"] or 0

    if collectItemName then
        Utils.debug("checkInteraction", "farm has collectItem")
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
            Utils.debug("checkInteraction", "farm has collectItem with durability")
            local toolItem
            for k, v in pairs(toolItems) do
                if v["metadata"] and v.metadata["durability"] and v.metadata.durability then
                    toolItem = v
                    break
                end
            end

            if toolItem then
                Utils.debug("checkInteraction", "toolItem is not nil")
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

local function checkInteraction(farmData)
    if not farmData.playerFarm then
        Utils.debug("checkInteraction", "playerFarm is nil")
        return false
    end

    if isInAnyVehicle() then
        return false
    end

    if not wasInFarmVehicle(farmData.playerFarm) then
        return false
    end

    if not hasCollectItemWithDurability(farmData.farmItem) then
        Utils.debug("checkInteraction", "hasCollectItemWithDurability is false")
        return false
    end

    return true
end

local function openPoint(farmData)
    local farmingItemName = farmData.farmingItemName
    local playerFarm = farmData.playerFarm
    local farmItem = farmData.farmItem
    Utils.debug("openPoint", json.encode(farmItem, {indent = true}))
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

    Utils.debug("openPoint", farmingItemName)
    local itemRegister = Utils.items[farmingItemName]
    if not itemRegister then
        Utils.sendNotification(
            {
                id = "farm:error.item_not_found",
                description = locale("error.item_not_found", farmingItemName),
                type = "error"
            }
        )
        Utils.debug("openPoint", "itemRegister is nil")
        return
    end
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
        farmData.amountCollected = farmData.amountCollected + 1
    end

    farmData.isTasking = false
    Utils.stopAnimations()
end

local function clearPoint(name)
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

local function clearFarmData(farmData)
    farmData.isFarming = false
    farmData.isTasking = false
    farmData.currentPoint = 0
    farmData.amountCollected = 0
    farmData.playerFarm = nil
    farmData.farmingItemName = nil
end

local function nextTask(farmData)
    Utils.debug("nextTask", json.encode(farmData, {indent = true}))
    if farmData.isTasking then
        return
    end

    farmData.isTasking = true

    if farmData.farmItem.randomRoute then
        farmData.currentPoint = math.random(1, #(farmData.farmItem.points))
    else
        if farmData.farmItem.unlimited and farmData.currentPoint >= #(farmData.farmItem.points) then
            farmData.currentPoint = 1
        else
            farmData.currentPoint = farmData.currentPoint + 1
        end
    end

    local farmPoint = farmData.farmItem.points[farmData.currentPoint]

    local blip = Defaults.New(Defaults.Blip)

    blip.coords = vec3(farmPoint.x, farmPoint.y, farmPoint.z)
    local zoneName = string.format("farm-point-%s", farmData.currentPoint)
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
                    label = locale("target.label", farmData.farmItem.label),
                    canInteract = function()
                        return checkInteraction(farmData)
                    end,
                    onSelect = function()
                        openPoint(farmData)
                        clearPoint(zoneName)
                    end
                },
                inside = function()
                    lib.showTextUI(string.format("[E] %s", locale("target.label", farmData.farmItem.label)))
                    if IsControlJustReleased(0, 38) and checkInteraction(farmData) then
                        openPoint(farmData)
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

return {
    isTasking = isTasking,
    amountCollected = amountCollected,
    checkInteraction = checkInteraction,
    nextTask = nextTask,
    openPoint = openPoint,
    clearPoint = clearPoint,
    clearFarmData = clearFarmData
}
