local ImageURL = "https://cfx-nui-ox_inventory/web/images"

local Utils = lib.require("shared/utils")
local Defaults = require("client/defaults")
local Blips = lib.require("client/interaction/blips")
local Markers = lib.require("client/interaction/markers")
local Text = lib.require("client/interaction/texts")
local Targets = lib.require("client/interaction/targets")
local Zones = lib.require("client/interaction/zones")

local Farms = {}

local isFarming = false
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
        if Config.Debug then
            print(string.format("Adding element: %s", item.name))
        end
        Farms[item.name] = item
    else
        if Config.Debug then
            print(string.format("Skipping element: %s", item.name))
        end
    end
end

local function remove(name)
    if Config.Debug then
        print(string.format("Removing element: %s", name))
    end
    Farms[name] = nil
end

local function clear()
    if #Farms > 0 then
        for k, v in pairs(Farms) do
            remove(k)
        end
    end
end

local function nextTask()
    local farmItem = playerFarm.config.items[farmingItemName]

    if farmItem == nil then
        return
    end

    if farmItem.points == nil  or #farmItem.points == 0 then
        return
    end

    if not farmItem.unlimited and amountCollected >= #farmItem.points then
        return
    end

    if farmItem.randomRoute then
        currentPoint = math.random(1, #(farmItem.points))
    else
        if farmItem.unlimited and currentPoint >= #(farmItem.points) then
            currentPoint = 1
        else
            currentPoint = currentPoint + 1
        end
    end

    local nextPoint = farmItem.points[currentPoint]

    local blip = Defaults.New(Defaults.Blip)

    blip.coords = vec3(nextPoint.x, nextPoint.y, nextPoint.z)
    Blips.add({name = string.format("farm-point-%s", currentPoint), data = blip})
end

local function stopFarming()
    isFarming = false
    amountCollected = 0
    playerFarm = nil
    farmingItemName = nil

    Utils.sendNotification(
        {
            type = "error",
            description = locale("text.cancel_shift")
        }
    )
end

local function startFarming(args)
    isFarming = true
    playerFarm = args.farm
    farmingItemName = args.itemName
    amountCollected = 0

    nextTask()
    Utils.sendNotification(
        {
            description = locale("text.end_shift"),
            type = "info"
        }
    )

    isFarming = false
    playerFarm = nil
    farmingItemName = nil
    amountCollected = 0

    -- local farmItem = playerFarm.config.items[farmingItemName]
    -- loadFarmPoints(itemName, farmItem)
    -- farmingItem = farmItem
    -- local amount = -1
    -- if (not farmItem.unlimited) then
    --     amount = #(farmItem.points)
    -- end

    -- currentSequence = 0
    -- Utils.sendNotification(
    --     {
    --         description = locale("text.start_shift", farmItem["customName"] or Utils.items[itemName].label),
    --         type = "info"
    --     }
    -- )
    -- local pickedFarms = 0
    -- farmThread()
    -- while isFarming do
    --     if tasking then
    --         Wait(5000)
    --     else
    --         if amount >= 0 and pickedFarms >= amount then
    --             isFarming = false
    --             Utils.sendNotification(
    --                 {
    --                     description = locale("text.end_shift"),
    --                     type = "info"
    --                 }
    --             )
    --         else
    --             nextTask(farmItem)
    --             pickedFarms = pickedFarms + 1
    --         end
    --     end
    --     Wait(5)
    -- end
end



local function showFarmMenu(farm)
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
            onSelect = stopFarming,
            args = {
                farm = farm,
                itemName = farmingItemName
            }
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
            print("Using target")
            Targets.add(
                {
                    name = zoneName,
                    data = {
                        coords = start.location,
                        name = zoneName,
                        options = {
                            icon = "fa-solid fa-screwdriver-wrench",
                            label = string.format("Abrir %s", v.name),
                            onSelect = function()
                                if Utils.checkPerms(v) then
                                    showFarmMenu(v)
                                end
                            end
                        }
                    }
                }
            )
        else
            print("Using zones")
            Zones.add(
                {
                    name = zoneName,
                    data = {
                        coords = start.location,
                        size = vector3(start.length, start.width, 1.0),
                        debug = Config.Debug,
                        onEnter = function()
                            if Utils.checkPerms(v) then
                                showFarmMenu(v)
                            end
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
