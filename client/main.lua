Farms = GlobalState.Farms or {}
ColorScheme = GlobalState.UIColors or {}
Items = exports.ox_inventory:Items()
ImageURL = 'https://cfx-nui-ox_inventory/web/images'
local Utils = lib.require('client/utils')

local QBCore = exports["qb-core"]:GetCoreObject()

local PlayerData = nil
local PlayerJob = nil
local PlayerGang = nil

local tasking = false
local currentPoint = 0
local currentSequence = 0
local markerCoords = nil
local blip = 0

local startFarm = false

local farmingItem = nil
local playerFarm = nil

local farmZones = {}
local farmPoints = {}
local farmPointZones = {}
local defaultBlipColor = 5

local blipSettings = {
    coordenadas = {
        x = 0,
        y = 0,
        z = 0
    },
    sprite = 1,
    color = defaultBlipColor,
    scale = 1.0,
    shortRange = false,
    route = true,
    text = locale("misc.farm_point")
}
DefaultAnimCmd = 'bumbin'
DefaultAnim = {
    dict = "amb@prop_human_bum_bin@idle_a",
    anim = "idle_a",
    inSpeed = 6.0,
    outSpeed = -6.0,
    duration = 2000,
    flag = 1,
    rate = 0,
    x = 0,
    y = 0,
    z = 0
}

local function createBlip(data)
    local coordenadas = data.coordenadas
    local b = AddBlipForCoord(coordenadas.x, coordenadas.y, coordenadas.z)
    SetBlipSprite(b, data.sprite)
    SetBlipColour(b, data.color)
    SetBlipScale(b, data.scale)
    SetBlipAsShortRange(b, data.shortRange)
    SetBlipRoute(b, data.route)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(data.text)
    EndTextCommandSetBlipName(b)
    return b
end

local function deleteBlip(b)
    if DoesBlipExist(b) then
        RemoveBlip(b)
    end
end

local function pickAnim(anim)
    if Config.UseEmoteMenu then
        ExecuteCommand(string.format('e %s', anim))
    else
        lib.requestAnimDict(anim.dict, 5000)
        TaskPlayAnim(cache.ped, anim.dict, anim.anim, anim.inSpeed, anim.outSpeed, anim.duration, anim.flag, anim.rate, anim.x,
        anim.y, anim.z)
    end
end

local function finishPicking()
    tasking = false
    if Config.UseUseEmoteMenu then
        ExecuteCommand('e c')
    else
        ClearPedTasks(PlayerPedId())
    end
    deleteBlip(blip)
end

local function actionProcess(name, description, duration, done, cancel)
    QBCore.Functions.Progressbar("pick_" .. name, description, duration, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true
    }, nil, nil, nil, done, cancel)
end

local function nextTask(shuffle)
    if tasking then
        return
    end
    if (shuffle) then
        currentPoint = math.random(1, #farmPoints)
    else
        currentPoint = currentSequence + 1
    end
    tasking = true
    markerCoords = {
        x = farmPoints[currentPoint].x,
        y = farmPoints[currentPoint].y,
        z = farmPoints[currentPoint].z
    }
    blipSettings.coordenadas = markerCoords
    blipSettings.text = locale("misc.farm_point")
    blipSettings.sprite = 465
    blip = createBlip(blipSettings)
end

local function loadFarmZones(itemName, item)
    for point, zone in pairs(item.points) do
        zone = vector3(zone.x, zone.y, zone.z)
        local label = ("farmZone-%s-%s"):format(itemName, point)
        farmPointZones[point] = {
            isInside = false,
            zone = BoxZone:Create(zone, 0.6, 0.6, {
                name = label,
                minZ = zone.z - 1.0,
                maxZ = zone.z + 1.0,
                debugPoly = Config.Debug
            })
        }

        farmPointZones[point].zone:onPlayerInOut(function(isPointInside)
            farmPointZones[point].isInside = isPointInside
            if farmPointZones[point].isInside then
                if point == currentPoint then
                    CreateThread(function()
                        while farmPointZones[point].isInside and point == currentPoint do
                            lib.showTextUI(locale("task.start_task"), {
                                position = 'right-center'
                            })
                            if not IsPedInAnyVehicle(PlayerPedId(), false) and IsControlJustReleased(0, 38) then
                                if ((playerFarm and playerFarm.config["car"] == nil) or
                                    IsVehicleModel(GetVehiclePedIsIn(PlayerPedId(), true),
                                        GetHashKey(playerFarm.config["car"].model))) then
                                    lib.hideTextUI()
                                    farmPointZones[point].zone:destroy()
                                    currentSequence = currentPoint
                                    currentPoint = -1
                                    local duration = math.random(6000, 8000)
                                    local animation = nil
                                    if (item["animation"]) then
                                        animation = item.animation
                                    else
                                        if Config.UseUseEmoteMenu then
                                            animation = DefaultAnimCmd
                                        else
                                            animation = DefaultAnim
                                            animation["duration"] = duration
                                        end
                                    end
                                    pickAnim(animation)
                                    local item = Items[itemName]
                                    actionProcess(itemName, locale("progress.pick_farm", item.label), duration, function() -- Done
                                        TriggerServerEvent("mri_Qfarm:server:getRewardItem", itemName, playerFarm.group.name)
                                        finishPicking()
                                    end, function() -- Cancel
                                        lib.notify({
                                            description = locale("task.cancel_task"),
                                            type = "error"
                                        })
                                        finishPicking()
                                    end)
                                else
                                    lib.notify({
                                        description = locale("error.incorrect_vehicle"),
                                        type = "error"
                                    })
                                end
                            end
                            Wait(1)
                        end
                    end)
                end
            else
                lib.hideTextUI()
            end
        end)
    end
end

local function startFarming(args)
    playerFarm = args.farm
    local itemName = args.itemName
    local farmItem = playerFarm.config.items[itemName]
    loadFarmZones(itemName, farmItem)
    startFarm = true
    farmingItem = itemName
    farmPoints = farmItem.points
    local amount = #farmPoints
    currentSequence = 0
    lib.notify({
        description = locale("text.start_shift", Items[itemName].label),
        type = "info"
    })
    local pickedFarms = 0
    while startFarm do
        if tasking then
            Wait(5000)
        else
            if pickedFarms >= amount then
                startFarm = false
                markerCoords = nil
                lib.notify({
                    description = locale("text.end_shift"),
                    type = "info"
                })
            else
                nextTask(farmItem.random)
                pickedFarms = pickedFarms + 1
            end
        end
        Wait(5)
    end
end

local function stopFarm()
    startFarm = false
    tasking = false
    lib.notify({
        type = 'error',
        description = locale('text.cancel_shift')
    })
    for k, _ in pairs(farmPointZones) do
        farmPointZones[k].zone:destroy()
    end
    deleteBlip(blip)
    markerCoords = nil
end

local function showFarmMenu(farm, groupName)
    local groups = Utils.GetBaseGroups(true)
    local ctx = {
        id = 'farm_menu',
        title = farm.name,
        icon = "fa-solid fa-briefcase",
        description = groups[groupName].label,
        options = {}
    }
    for itemName, _ in pairs(farm.config.items) do
        local item = Items[itemName]
        if not(item == nil) then
            ctx.options[#ctx.options+1] = {
                title = item.label,
                description = item.description,
                icon = string.format('%s/%s.png', ImageURL, item.name),
                image = string.format('%s/%s.png', ImageURL, item.name),
                metadata = Utils.GetItemMetadata(item),
                disabled = startFarm,
                onSelect = startFarming,
                args = {
                    farm = farm,
                    itemName = itemName
                }
            }
        end
    end

    if (startFarm) then
        local item = Items[farmingItem]
        ctx.options[#ctx.options+1] = {
            title = locale("menus.cancel_farm"),
            icon = "fa-solid fa-ban",
            description = item.label,
            onSelect = StopFarm,
            args = {
                farm = farm,
                itemName = farmingItem
            }
        }
    end
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

local function loadFarms()
    if #farmZones > 0 then
        for k, _ in pairs(farmZones) do
            farmZones[k].zone:destroy()
        end
    end
    for _, v in pairs(Farms) do
        if ((PlayerJob and v.group.name == PlayerJob.name) or (PlayerGang and v.group.name == PlayerGang.name)) then
            local start = v.config.start
            start.location = vector3(start.location.x, start.location.y, start.location.z)
            farmZones[#farmZones + 1] = {
                IsInside = false,
                zone = BoxZone:Create(start.location, start.length, start.width, {
                    name = ("farm-%s"):format('start' .. _),
                    minZ = start.location.z - 1.0,
                    maxZ = start.location.z + 1.0,
                    debugPoly = Config.Debug
                }),
                farm = v
            }
        end
    end

    for _, zone in pairs(farmZones) do
        zone.zone:onPlayerInOut(function(isPointInside)
            zone.isInside = isPointInside
            if isPointInside then
                if ((PlayerJob and zone.farm.group.name == PlayerJob.name) or (PlayerGang and zone.farm.group.name == PlayerGang.name)) then
                    showFarmMenu(zone.farm, zone.farm.group.name)
                end
            end
        end)
    end
end

CreateThread(function()
    while (true) do
        if markerCoords then
            local playerLoc = GetEntityCoords(cache.ped)
            if GetDistanceBetweenCoords(playerLoc.x, playerLoc.y, playerLoc.z, markerCoords.x, markerCoords.y, markerCoords.z, true) <= 30 then
                DrawMarker(2, markerCoords.x, markerCoords.y, markerCoords.z + 0.3, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3,
                    0.3, 0.3, 255, 255, 0, 80, 0, 1, 2, 0)
            end
        end
        Wait(0)
    end
end)

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        PlayerData = QBCore.Functions.GetPlayerData()
        PlayerJob = PlayerData.job
        PlayerGang = PlayerData.gang
    end
end)

RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
    PlayerData = QBCore.Functions.GetPlayerData()
    PlayerJob = PlayerData.job
    PlayerGang = PlayerData.gang
    loadFarms()
end)

RegisterNetEvent("QBCore:Client:OnPlayerUnload", function()
    local group = nil
    if PlayerGang and PlayerGang.name then
        group = PlayerGang.name
    elseif (PlayerJob and PlayerJob.name) then
        group = PlayerJob.name
    end

    if (group and farmingItem) then
        stopFarm()
    end
end)

RegisterNetEvent("QBCore:Client:OnJobUpdate", function(JobInfo)
    PlayerJob = JobInfo
    loadFarms()
 end)

RegisterNetEvent("QBCore:Client:OnGangUpdate", function(GangInfo)
    PlayerGang = GangInfo
    loadFarms()
end)

RegisterNetEvent("mri_Qfarm:client:LoadFarms", function()
    Farms = GlobalState.Farms or {}
    loadFarms()
end)
