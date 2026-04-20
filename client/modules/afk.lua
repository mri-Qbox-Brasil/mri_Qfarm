-- Farm AFK, sem rotas, parado no mesmo lugar

local Config = require("shared/config")
local Utils = lib.require("shared/utils")
local Defaults = require("client/defaults")
local Blips = lib.require("client/interaction/blips")
local Markers = lib.require("client/interaction/markers")
local Text = lib.require("client/interaction/texts")
local Targets = lib.require("client/interaction/targets")
local Zones = lib.require("client/interaction/zones")
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
    local isPublic = Utils.isPublic(item)
    if
        isPublic or Utils.roleCheck(PlayerJob, item.group.name, item.group.grade) or
            Utils.roleCheck(PlayerGang, item.group.name, item.group.grade)
     then
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
        Text.remove("farming")
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

    farmThread()

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

    -- AFK Logic: Just wait and collect
    while farmData.isFarming do
        if farmData.isTasking then
             Wait(1000)
        else
            if not farmData.farmItem.unlimited and farmData.amountCollected >= (farmData.farmItem.max or 100) then -- Arbitrary max if not set for AFK? Or check unlimited
                 -- Actually AFK usually doesn't have points, so 'amountCollected' limit might depend on weight or custom config
                 -- For now, let's assume it runs until stopped or full
                if not exports.ox_inventory:CanCarryItem(cache.source, farmData.farmingItemName, 1) then
                    Utils.sendNotification({description = locale("error.inventory_full"), type = "error"})
                     stopFarming()
                     return
                end
            end

            -- Perform collection
            farmData.isTasking = true

            -- Use openPoint derived logic but without interaction requirement?
            -- openPoint has animation and progress bar. AFK might just be a timer.

            local duration = farmData.farmItem["collectTime"] or Defaults.CollectTime

            local description = locale("progress.pick_farm", Utils.items[farmData.farmingItemName].label)

            if Utils.actionProcess(description, duration) then
                 lib.callback.await("mri_Qfarm:server:getRewardItem", false, farmData.farmingItemName, farmData.playerFarm.farmId)
                 farmData.amountCollected = farmData.amountCollected + 1
            end

            farmData.isTasking = false
            Wait(1000) -- Small delay between collections
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
    Utils.debug("AFK", "loadFarms")
    for k, v in pairs(Farms) do
        local start = v.config.start
        if start and start.location then
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
end

return {
    add = add,
    clear = clear,
    loadFarms = loadFarms
}
