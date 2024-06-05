local QBCore = exports["qb-core"]:GetCoreObject()

local FarmZones = GlobalState.FarmZones or {}
local ColorScheme = GlobalState.UIColors or {}
local Items = exports.ox_inventory:Items()
local ImageURL = 'https://cfx-nui-ox_inventory/web/images'

local PlayerData = {}
local PlayerJob = {}
local PlayerGang = {}

local tasking = false
local currentPoint = 0
local currentSequence = 0
local blip = 0

local startFarm = false

local farmingItem = nil

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
    text = Lang:t("misc.farm_point")
}

local defaultAnim = {
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

local marker = nil

local function GetItem(itemName)
    if (itemName == "cash") then
        return {
            ["weight"] = 0.01,
            ["name"] = "cash",
            ["description"] = "Dinheiro",
            ["shouldClose"] = true,
            ["unique"] = true,
            ["image"] = "farm-cash.png",
            ["label"] = "Dinheiro",
            ["useable"] = false,
            ["type"] = "item"
        }
    else
        return QBCore.Shared.Items[itemName]
    end
end

local function CreateBlip(coords)
    blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 465)
    SetBlipScale(blip, 1.0)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Lang:t("misc.farm_point"))
    EndTextCommandSetBlipName(blip)
end

local function DeleteBlip()
    if DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
end

local function LoadAnim(dict)
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(1)
    end
end

local function PickAnim(animation)
    local anim = defaultAnim
    if (animation) then
        anim = animation
    end
    local ped = PlayerPedId()
    LoadAnim(anim.dict)
    TaskPlayAnim(ped, anim.dict, anim.anim, anim.inSpeed, anim.outSpeed, anim.duration, anim.flag, anim.rate, anim.x,
        anim.y, anim.z)
end

local function FinishPicking()
    tasking = false
    ClearPedTasks(PlayerPedId())
    if (Config.useTTCLibs) then
        ttc.client.removeBlip("gps", scriptName, blip)
    else
        DeleteBlip()
    end
end

local function ActionProcess(name, description, duration, done, cancel)
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
    marker = {
        x = farmPoints[currentPoint].x,
        y = farmPoints[currentPoint].y,
        z = farmPoints[currentPoint].z
    }
    blipSettings.coordenadas = marker
    if (Config.useTTCLibs) then
        blip = ttc.client.addBlip("gps", scriptName, blipSettings)
    else
        CreateBlip(farmPoints[currentPoint])
    end
end

local function LoadFarmZones(role, item, name)
    for point, zone in pairs(item.points) do
        local label = ("farmZone-%s-%s"):format(name, point)
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
                            exports["qb-core"]:DrawText(Lang:t("task.start_task"), "right")
                            if not IsPedInAnyVehicle(PlayerPedId()) and IsControlJustReleased(0, 38) then
                                if (Farms[role]["car"] == nil or
                                    IsVehicleModel(GetVehiclePedIsIn(PlayerPedId(), true),
                                        GetHashKey(Farms[role]["car"].model))) then
                                    exports["qb-core"]:HideText()
                                    farmPointZones[point].zone:destroy()
                                    currentSequence = currentPoint
                                    currentPoint = -1
                                    local duration = math.random(6000, 8000)
                                    local animation = GetDefaultAnim()
                                    if (item["animation"]) then
                                        animation = item.animation
                                    end
                                    animation["duration"] = duration
                                    PickAnim(animation)
                                    local item = GetItem(name)
                                    ActionProcess(name, Lang:t("progress.pick_farm", {
                                        item = item.label
                                    }), duration, function() -- Done
                                        TriggerServerEvent("mri_Qfarm:server:getRewardItem", name, "farm")
                                        FinishPicking()
                                    end, function() -- Cancel
                                        QBCore.Functions.Notify(Lang:t("task.cancel_task"), "error")
                                        FinishPicking()
                                    end)
                                else
                                    QBCore.Functions.Notify(Lang:t("error.incorrect_vehicle"), "error")
                                end
                            end
                            Wait(1)
                        end
                    end)
                else
                end
            else
                exports["qb-core"]:HideText()
            end
        end)
    end
end

local function StartFarming(role, item, name)
    local farmItem = Farms[role].items[name]
    LoadFarmZones(role, farmItem, name)
    startFarm = true
    farmingItem = name
    farmPoints = farmItem.points
    local amount = #farmPoints
    currentSequence = 0
    QBCore.Functions.Notify(Lang:t("text.start_shift", {
        item = item.label
    }))
    TriggerServerEvent("ttc-smallresources:Server:SendWebhook", {
        issuer = role,
        hook = "farm",
        color = {
            r = 255,
            g = 255,
            b = 0
        },
        title = "FARM - INICIADO",
        description = string.format("**Membro:** %s %s\n**Item:** %s", PlayerData.charinfo.firstname,
            PlayerData.charinfo.lastname, QBCore.Shared.Items[name].label),
        content = nil,
        fields = nil
    })
    local pickedFarms = 0
    while startFarm do
        if tasking then
            Wait(5000)
        else
            if pickedFarms >= amount then
                startFarm = false
                marker = nil
                QBCore.Functions.Notify(Lang:t("text.end_shift"))
                TriggerServerEvent("ttc-smallresources:Server:SendWebhook", {
                    issuer = role,
                    hook = "farm",
                    color = {
                        r = 255,
                        g = 255,
                        b = 0
                    },
                    title = "FARM - FINALIZADO",
                    description = string.format("**Membro:** %s %s\n**Item:** %s", PlayerData.charinfo.firstname,
                        PlayerData.charinfo.lastname, QBCore.Shared.Items[name].label),
                    content = nil,
                    fields = nil
                })
            else
                nextTask(farmItem.random)
                pickedFarms = pickedFarms + 1
            end
        end
        Wait(5)
    end
end

local function GetFarmMenu(name, role)
    local menu = {{
        isMenuHeader = true,
        header = Lang:t("menus.farm_header_title", {
            name = name
        }),
        icon = "fa-solid fa-briefcase"
    }}

    for name, item in pairs(Farms[role].items) do
        local item = GetItem(name)
        if (item == nil) then
        else
            menu[#menu + 1] = {
                header = item.label,
                txt = item.description,
                icon = name,
                disabled = startFarm,
                params = {
                    event = "mri_Qfarm:client:StartFarm",
                    args = {
                        role = role,
                        item = item,
                        name = name
                    }
                }
            }
        end
    end

    if (startFarm) then
        local item = GetItem(farmingItem)
        menu[#menu + 1] = {
            header = Lang:t("menus.cancel_farm"),
            icon = "fa-solid fa-ban",
            txt = item.label,
            params = {
                event = "mri_Qfarm:client:StopFarm",
                args = {
                    role = role,
                    name = farmingItem
                }
            }
        }
    end

    menu[#menu + 1] = {
        header = Lang:t('menus.close'),
        txt = "",
        params = {
            event = "qb-menu:client:closeMenu"
        }
    }
    return menu
end

local function LoadFarms()
    for role, z in pairs(Farms) do
        if ((role == PlayerJob.name) or (role == PlayerGang.name)) then
            for _, loc in pairs(z.start.locations) do
                farmZones[#farmZones + 1] = {
                    IsInside = false,
                    zone = BoxZone:Create(loc, z.start.length, z.start.width, {
                        name = ("farm-%s"):format(z.name),
                        minZ = loc.z - 1.0,
                        maxZ = loc.z + 1.0,
                        debugPoly = Config.Debug
                    })
                }
            end
        end
    end

    for _, zone in pairs(farmZones) do
        zone.zone:onPlayerInOut(function(isPointInside)
            zone.isInside = isPointInside
            if isPointInside then
                local jobCfg = Farms[PlayerJob.name]
                local gangCfg = Farms[PlayerGang.name]
                if jobCfg then
                    exports["qb-menu"]:openMenu(GetFarmMenu(zone.zone.name, PlayerJob.name))
                elseif gangCfg then
                    exports["qb-menu"]:openMenu(GetFarmMenu(zone.zone.name, PlayerGang.name))
                end
            else
                exports["qb-menu"]:closeMenu()
            end
        end)
    end
end

CreateThread(function()
    while (true) do
        if (marker) then
            local distance =
                GetDistanceBetweenCoords(GetEntityCoords(PlayerPedId()), marker.x, marker.y, marker.z, true)
            if (distance <= 30) then
                DrawMarker(2, marker.x, marker.y, marker.z + 0.3, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 255, 255,
                    0, 80, 0, 1, 2, 0)
            end
        end
        Wait(0)
    end
end)

RegisterNetEvent("mri_Qfarm:client:StartFarm", function(args)
    StartFarming(args.role, args.item, args.name)
end)

RegisterNetEvent("mri_Qfarm:client:StopFarm", function(args)
    startFarm = false
    tasking = false
    lib.notify({
        type = 'error',
        description = locale('text.cancel_shift')
    })
    for k, _ in pairs(farmPointZones) do
        farmPointZones[k].zone:destroy()
    end
    if (Config.useTTCLibs) then
        ttc.client.cleanBlips("gps", scriptName)
    else
        DeleteBlip(blip)
    end
    marker = nil
    -- TriggerServerEvent("ttc-smallresources:Server:SendWebhook", {
    --     issuer = args.role,
    --     hook = "farm",
    --     color = {
    --         r = 255,
    --         g = 255,
    --         b = 0
    --     },
    --     title = "FARM - CANCELADO",
    --     description = string.format("**Membro:** %s %s\n**Item:** %s", PlayerData.charinfo.firstname,
    --         PlayerData.charinfo.lastname, QBCore.Shared.Items[args.name].label),
    --     content = nil,
    --     fields = nil
    -- })
end)

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        PlayerData = QBCore.Functions.GetPlayerData()
        PlayerJob = PlayerData.job
        PlayerGang = PlayerData.gang
        -- LoadFarms()
        -- if (Config.useTTCLibs) then
        --     ttc.client.cleanBlips("gps", scriptName)
        -- end
        if Config.Debug then
            print(string.format("Job: '%s'", PlayerJob.name))
        end
        if Config.Debug then
            print(string.format("Gang: '%s'", PlayerGang.name))
        end
    end
end)

RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
    -- if (Config.useTTCLibs) then
    --     ttc.client.cleanBlips("gps", scriptName)
    -- end
    PlayerData = QBCore.Functions.GetPlayerData()
    PlayerJob = PlayerData.job
    PlayerGang = PlayerData.gang
    -- LoadFarms()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    local role = nil
    if PlayerGang and PlayerGang.name then
        role = PlayerGang.name
    elseif (PlayerJob and PlayerJob.name) then
        role = PlayerJob.name
    end
    if (role and farmingItem) then
        TriggerEvent("mri_Qfarm:client:StopFarm", {role, farmingItem})
    end
end)

RegisterNetEvent("QBCore:Client:OnJobUpdate", function(JobInfo)
    PlayerJob = JobInfo
    if Config.Debug then
        print(string.format("Job: '%s'", PlayerJob.name))
    end
end)

RegisterNetEvent("QBCore:Client:OnGangUpdate", function(GangInfo)
    PlayerGang = GangInfo
    if Config.Debug then
        print(string.format("Gang: '%s'", PlayerGang.name))
    end
end)