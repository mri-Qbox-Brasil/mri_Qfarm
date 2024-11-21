Farms = GlobalState.Farms or {}
ColorScheme = GlobalState.UIColors or {}
Items = exports.ox_inventory:Items()
ImageURL = "https://cfx-nui-ox_inventory/web/images"
local Utils = lib.require("client/utils")

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
    coords = {
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

DefaultAnimCmd = "bumbin"

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

DefaultCollectTime = 7000

local function showHelpNotification(text, delay, type, playSound)
    local type = type or 0
    local delay = delay or 5000
    local playSound = playSound or false
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringKeyboardDisplay(text)
    EndTextCommandDisplayHelp(type, false, playSound, delay)
end

local function createBlip(data)
    local b = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
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
    if b and DoesBlipExist(b) then
        RemoveBlip(b)
    end
end

local function emptyTargetZones(tableObj, type)
    if #tableObj > 0 then
        for k, _ in pairs(tableObj) do
            if type == "zone" then
                tableObj[k].zone:destroy()
                if Config.Debug then
                    print(string.format("Removing target: %s: %s", k, tableObj[k]))
                end
            else
                exports.ox_target:removeZone(tableObj[k])
                if Config.Debug then
                    print(string.format("Removing target: %s: %s", k, tableObj[k]))
                end
            end
        end
        table.clear(tableObj)
    else
        if Config.Debug then
            print("Table is empty")
        end
    end
end

local function stopFarm()
    startFarm = false
    tasking = false

    lib.notify(
        {
            type = "error",
            description = locale("text.cancel_shift")
        }
    )

    if Config.UseTarget then
        emptyTargetZones(farmPointTargets, "target")
    else
        emptyTargetZones(farmZones, "zone")
    end

    deleteBlip(blip)
    markerCoords = nil
    currentPoint = 0
    playerFarm = nil
end

local function farmThread()
    CreateThread(
        function()
            while (startFarm) do
                if Config.ShowMarker and markerCoords then
                    local playerLoc = GetEntityCoords(cache.ped)
                    if
                        GetDistanceBetweenCoords(
                            playerLoc.x,
                            playerLoc.y,
                            playerLoc.z,
                            markerCoords.x,
                            markerCoords.y,
                            markerCoords.z,
                            true
                        ) <= 30
                     then
                        DrawMarker(
                            2,
                            markerCoords.x,
                            markerCoords.y,
                            markerCoords.z + 0.3,
                            0.0,
                            0.0,
                            0.0,
                            0.0,
                            0.0,
                            0.0,
                            0.3,
                            0.3,
                            0.3,
                            255,
                            255,
                            0,
                            80,
                            0,
                            1,
                            2,
                            0
                        )
                    end
                end
                if IsControlJustReleased(0, 168) then
                    stopFarm()
                end
                if Config.ShowOSD then
                    showHelpNotification(locale("actions.stop_f7"), 1000, 1)
                end
                Wait(0)
            end
        end
    )
end

local function pickAnim(anim)
    if Config.UseEmoteMenu then
        ExecuteCommand(string.format("e %s", anim))
    else
        lib.requestAnimDict(anim.dict, 5000)
        TaskPlayAnim(
            cache.ped,
            anim.dict,
            anim.anim,
            anim.inSpeed,
            anim.outSpeed,
            anim.duration,
            anim.flag,
            anim.rate,
            anim.x,
            anim.y,
            anim.z
        )
    end
end

local function finishPicking()
    tasking = false
    if Config.UseUseEmoteMenu then
        ExecuteCommand("e c")
    else
        ClearPedTasks(PlayerPedId())
    end
    deleteBlip(blip)
end

local function actionProcess(name, description, duration, done, cancel)
    QBCore.Functions.Progressbar(
        "pick_" .. name,
        description,
        duration,
        false,
        true,
        {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true
        },
        nil,
        nil,
        nil,
        done,
        cancel
    )
end

local function nextTask(shuffle, unlimited)
    if tasking then
        return
    end
    if (shuffle) then
        currentPoint = math.random(1, #farmPoints)
    else
        if unlimited and currentSequence >= #farmPoints then
            currentPoint = 1
        else
            currentPoint = currentSequence + 1
        end
    end
    tasking = true
    markerCoords = {
        x = farmPoints[currentPoint].x,
        y = farmPoints[currentPoint].y,
        z = farmPoints[currentPoint].z
    }
    blipSettings.coords = markerCoords
    blipSettings.text = locale("misc.farm_point")
    blipSettings.sprite = 465
    blip = createBlip(blipSettings)
end

local function openPoint(point, itemName, item)
    lib.hideTextUI()
    if not item["unlimited"] then
        if Config.UseTarget then
            exports.ox_target:removeZone(farmPointTargets[point])
        else
            farmPointZones[point].zone:destroy()
        end
    end
    currentSequence = currentPoint
    currentPoint = -1
    local duration = item.collectTime or DefaultCollectTime
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
    local itemRegister = Items[itemName]
    if item["collectItem"]["name"] and item["collectItem"]["durability"] then
        lib.callback.await("mri_Qfarm:server:UseItem", false, item)
    end
    actionProcess(
        itemName,
        locale("progress.pick_farm", itemRegister.label),
        duration,
        function()
            -- Done
            lib.callback.await("mri_Qfarm:server:getRewardItem", false, itemName, playerFarm.farmId)
            finishPicking()
        end,
        function()
            -- Cancel
            lib.notify(
                {
                    description = locale("task.cancel_task"),
                    type = "error"
                }
            )
            finishPicking()
        end
    )
end

local function checkInteraction(point, item)
    local collectItem = item["collectItem"] or {}
    local collectItemName = collectItem["name"]
    if not playerFarm then
        -- Verifica se o player está farmando agora
        return false
    end

    if not currentPoint == point then
        -- Verifica se o player está na zona correta
        return false
    end

    if IsPedInAnyVehicle(cache.ped, false) then
        -- Verifica se o player esta em um veiculo
        lib.notify(
            {
                id = "farm:error.not_in_vehicle",
                description = locale("error.not_in_vehicle"),
                type = "error"
            }
        )
        return false
    end

    if
        playerFarm.config["vehicle"] and
            not IsVehicleModel(GetVehiclePedIsIn(PlayerPedId(), true), GetHashKey(playerFarm.config["vehicle"]))
     then
        -- Verifica se o player esta no veículo certo
        lib.notify(
            {
                id = "farm:error.incorrect_vehicle",
                description = locale("error.incorrect_vehicle"),
                type = "error"
            }
        )
        return false
    end

    if collectItemName then
        local toolItem = exports.ox_inventory:Search("slots", collectItemName)
        if not toolItem then
            -- Verifica se o player tem o item certo
            lib.notify(
                {
                    id = "farm:error.no_item",
                    description = locale("error.no_item", collectItemName),
                    type = "error"
                }
            )
            return false
        end

        for k, v in pairs(toolItem) do
            if v.metadata.durability >= item.collectItem.durability then
                toolItem = v
                break
            end
        end

        if (toolItem.metadata.durability or 0) < (item["collectItem"]["durability"] or 0) then
            -- Verifica se o item tem durabilidade
            lib.notify(
                {
                    id = "farm:error.low_durability",
                    description = locale("error.low_durability", Items[collectItemName].label),
                    type = "error"
                }
            )
            return false
        end
    end

    return true
end

local function loadFarmZones(itemName, item)
    for point, zone in pairs(item.points) do
        zone = vector3(zone.x, zone.y, zone.z)
        local label = ("farmZone-%s-%s"):format(itemName, point)
        if Config.UseTarget then
            farmPointTargets[point] =
                exports.ox_target:addSphereZone(
                {
                    coords = zone,
                    name = label,
                    options = {
                        name = label,
                        icon = "fa-solid fa-screwdriver-wrench",
                        label = locale("target.label", item.label),
                        canInteract = function()
                            return checkInteraction(point, item)
                        end,
                        onSelect = function()
                            openPoint(point, itemName, item)
                        end
                    }
                }
            )
        else
            farmPointZones[point] = {
                isInside = false,
                zone = BoxZone:Create(
                    zone,
                    0.6,
                    0.6,
                    {
                        name = label,
                        minZ = zone.z - 1.0,
                        maxZ = zone.z + 1.0,
                        debugPoly = Config.Debug
                    }
                )
            }
        end

        if not Config.UseTarget then
            farmPointZones[point].zone:onPlayerInOut(
                function(isPointInside)
                    farmPointZones[point].isInside = isPointInside
                    if farmPointZones[point].isInside then
                        if point == currentPoint then
                            CreateThread(
                                function()
                                    while farmPointZones[point].isInside do
                                        lib.showTextUI(
                                            locale("task.start_task"),
                                            {
                                                position = "right-center"
                                            }
                                        )
                                        if IsControlJustReleased(0, 38) and checkInteraction(point) then
                                            openPoint(point, itemName, item)
                                        end
                                        Wait(1)
                                    end
                                end
                            )
                        end
                    else
                        lib.hideTextUI()
                    end
                end
            )
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
    local amount = -1
    if (not farmItem.unlimited) then
        amount = #farmPoints
    end

    currentSequence = 0
    lib.notify(
        {
            description = locale("text.start_shift", Items[itemName].label),
            type = "info"
        }
    )
    local pickedFarms = 0
    farmThread()
    while startFarm do
        if tasking then
            Wait(5000)
        else
            if amount >= 0 and pickedFarms >= amount then
                startFarm = false
                markerCoords = nil
                lib.notify(
                    {
                        description = locale("text.end_shift"),
                        type = "info"
                    }
                )
            else
                nextTask(farmItem.randomRoute, farmItem.unlimited)
                pickedFarms = pickedFarms + 1
            end
        end
        Wait(5)
    end
end

local function showFarmMenu(farm)
    local ctx = {
        id = "farm_menu",
        title = farm.name,
        icon = "fa-solid fa-briefcase",
        options = {}
    }
    for itemName, _ in pairs(farm.config.items) do
        local item = Items[itemName]
        if not (item == nil) then
            ctx.options[#ctx.options + 1] = {
                title = item.label,
                description = item.description,
                icon = string.format("%s/%s.png", ImageURL, item.name),
                image = string.format("%s/%s.png", ImageURL, item.name),
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

local function roleCheck(PlayerGroupData, requiredGroup, requiredGrade)
    if requiredGroup then
        for i = 1, #requiredGroup do
            if requiredGroup[i] == PlayerGroupData.name then
                return not PlayerGroupData.grade and true or tonumber(requiredGrade) <= PlayerGroupData.grade.level
            end
        end
    end
end

local function checkAndOpen(farm, isPublic)
    if
        isPublic or roleCheck(PlayerJob, farm.group.name, farm.group.grade) or
            roleCheck(PlayerGang, farm.group.name, farm.group.grade)
     then
        showFarmMenu(farm)
    end
end

local function loadFarms()
    emptyTargetZones(farmZones, "zone")
    emptyTargetZones(farmTargets, "target")
    for k, v in pairs(Farms) do
        local isPublic = not v.group["name"] or #v.group["name"] == 0
        if
            isPublic or roleCheck(PlayerJob, v.group.name, v.group.grade) or
                roleCheck(PlayerGang, v.group.name, v.group.grade)
         then
            if v.config.start["location"] then
                local start = v.config.start
                start.location = vector3(start.location.x, start.location.y, start.location.z)
                local zoneName = ("farm-%s"):format("start" .. k)
                if Config.UseTarget then
                    table.insert(
                        farmTargets,
                        exports.ox_target:addSphereZone(
                            {
                                coords = start.location,
                                name = zoneName,
                                options = {
                                    icon = "fa-solid fa-screwdriver-wrench",
                                    label = string.format("Abrir %s", v.name),
                                    onSelect = function()
                                        checkAndOpen(v, isPublic)
                                    end
                                }
                            }
                        )
                    )
                else
                    farmZones[#farmZones + 1] = {
                        IsInside = false,
                        zone = BoxZone:Create(
                            start.location,
                            start.length,
                            start.width,
                            {
                                name = zoneName,
                                minZ = start.location.z - 1.0,
                                maxZ = start.location.z + 1.0,
                                debugPoly = Config.Debug
                            }
                        ),
                        farm = v
                    }
                end
            end
        end
    end

    if not Config.UseTarget then
        for _, zone in pairs(farmZones) do
            zone.zone:onPlayerInOut(
                function(isPointInside)
                    zone.isInside = isPointInside
                    if isPointInside then
                        checkAndOpen(zone.farm)
                    end
                end
            )
        end
    end
end

AddEventHandler(
    "onResourceStart",
    function(resourceName)
        if resourceName == GetCurrentResourceName() then
            PlayerData = QBCore.Functions.GetPlayerData()
            PlayerJob = PlayerData.job
            PlayerGang = PlayerData.gang
        end
    end
)

RegisterNetEvent(
    "QBCore:Client:OnPlayerLoaded",
    function()
        PlayerData = QBCore.Functions.GetPlayerData()
        PlayerJob = PlayerData.job
        PlayerGang = PlayerData.gang
        loadFarms()
    end
)

RegisterNetEvent(
    "QBCore:Client:OnPlayerUnload",
    function()
        local group = nil
        if PlayerGang and PlayerGang.name then
            group = PlayerGang.name
        elseif (PlayerJob and PlayerJob.name) then
            group = PlayerJob.name
        end

        if (group and farmingItem) then
            stopFarm()
        end
    end
)

RegisterNetEvent(
    "QBCore:Client:OnJobUpdate",
    function(JobInfo)
        PlayerJob = JobInfo
        loadFarms()
    end
)

RegisterNetEvent(
    "QBCore:Client:OnGangUpdate",
    function(GangInfo)
        PlayerGang = GangInfo
        loadFarms()
    end
)

RegisterNetEvent(
    "mri_Qfarm:client:LoadFarms",
    function()
        Farms = GlobalState.Farms or {}
        loadFarms()
    end
)
