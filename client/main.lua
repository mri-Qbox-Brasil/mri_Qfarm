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
local farmTargets = {}
local farmPoints = {}
local farmPointZones = {}
local farmPointTargets = {}
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
        TaskPlayAnim(cache.ped, anim.dict, anim.anim, anim.inSpeed, anim.outSpeed, anim.duration, anim.flag, anim.rate,
            anim.x,
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

local function checkAndOpenPoint(point, itemName, item)
    if not IsPedInAnyVehicle(PlayerPedId(), false) and (Config.UseTarget or IsControlJustReleased(0, 38)) then
        if ((playerFarm and playerFarm.config["car"] == nil) or
                IsVehicleModel(GetVehiclePedIsIn(PlayerPedId(), true),
                    GetHashKey(playerFarm.config["car"].model))) then
            lib.hideTextUI()
            if Config.UseTarget then
                exports.ox_target:removeZone(farmPointTargets[point])
            else
                farmPointZones[point].zone:destroy()
            end
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
                TriggerServerEvent("mri_Qfarm:server:getRewardItem", itemName, playerFarm.farmId)
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
end

local function loadFarmZones(itemName, item)
    for point, zone in pairs(item.points) do
        zone = vector3(zone.x, zone.y, zone.z)
        local label = ("farmZone-%s-%s"):format(itemName, point)
        if Config.UseTarget then
            farmPointTargets[point] = exports.ox_target:addSphereZone({
                coords = zone,
                options = {
                    name = label,
                    icon = "fa-solid fa-screwdriver-wrench",
                    label = "Coletar",
                    onSelect = function()
                        checkAndOpenPoint(point, itemName, item)
                    end
                }
            })
        else
            farmPointZones[point] = {
                isInside = false,
                zone = BoxZone:Create(zone, 0.6, 0.6, {
                    name = label,
                    minZ = zone.z - 1.0,
                    maxZ = zone.z + 1.0,
                    debugPoly = Config.Debug
                })
            }
        end

        if not Config.UseTarget then
            farmPointZones[point].zone:onPlayerInOut(function(isPointInside)
                farmPointZones[point].isInside = isPointInside
                if farmPointZones[point].isInside then
                    if point == currentPoint then
                        CreateThread(function()
                            while farmPointZones[point].isInside and point == currentPoint do
                                lib.showTextUI(locale("task.start_task"), {
                                    position = 'right-center'
                                })
                                checkAndOpenPoint(point, itemName, item)
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
        if not (item == nil) then
            ctx.options[#ctx.options + 1] = {
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
        ctx.options[#ctx.options + 1] = {
            title = locale("menus.cancel_farm"),
            icon = "fa-solid fa-ban",
            description = item.label,
            onSelect = stopFarm,
            args = {
                farm = farm,
                itemName = farmingItem
            }
        }
    end
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

local function checkAndOpen(farm)
    if ((PlayerJob and farm.group.name == PlayerJob.name) or (PlayerGang and farm.group.name == PlayerGang.name)) then
        showFarmMenu(farm, farm.group.name)
    end
end

local function emptyTargetZones(table, type)
    if #table > 0 then
        for k, _ in pairs(table) do
            if type == 'zone' then
                table[k].zone:destroy()
            else
                exports.ox_target:removeZone(table[k])
            end
        end
    end
end

local function loadFarms()
    emptyTargetZones(farmZones, 'zone')
    emptyTargetZones(farmTargets, 'target')
    for k, v in pairs(Farms) do
        if ((PlayerJob and PlayerJob.name == v.group.name) or (PlayerGang and PlayerGang.name == v.group.name)) then
            if v.config.start['location'] then
                local start = v.config.start
                start.location = vector3(start.location.x, start.location.y, start.location.z)
                if Config.UseTarget then
                    farmTargets[k] = exports.ox_target:addSphereZone({
                        coords = start.location,
                        options = {
                            name = ("farm-%s"):format('start' .. k),
                            icon = "fa-solid fa-screwdriver-wrench",
                            label = string.format("Abrir %s", v.name),
                            onSelect = function()
                                checkAndOpen(v)
                            end
                        }
                    })
                else
                    farmZones[#farmZones + 1] = {
                        IsInside = false,
                        zone = BoxZone:Create(start.location, start.length, start.width, {
                            name = ("farm-%s"):format('start' .. k),
                            minZ = start.location.z - 1.0,
                            maxZ = start.location.z + 1.0,
                            debugPoly = Config.Debug
                        }),
                        farm = v
                    }
                end
            end
        end
    end

    if not Config.UseTarget then
        for _, zone in pairs(farmZones) do
            zone.zone:onPlayerInOut(function(isPointInside)
                zone.isInside = isPointInside
                if isPointInside then
                    checkAndOpen(zone.farm)
                end
            end)
        end
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
