local Farms = GlobalState.Farms or {}
local ImageURL = "https://cfx-nui-ox_inventory/web/images"

local Utils = lib.require("shared/utils")
local Defaults = require("client/defaults")
local Blips = lib.require("client/interaction/blips")
local Text = lib.require("client/interaction/texts")
local Targets = lib.require("client/interaction/targets")
local Zones = lib.require("client/interaction/zones")

local PlayerData = nil
local PlayerJob = nil
local PlayerGang = nil

local tasking = false
local currentPoint = 0
local currentSequence = 0
local blip = 0

local startFarm = false

local farmingItemName = nil
local farmingItem = nil
local playerFarm = nil

local farmElements = {}
local farmPointElements = {}
local defaultBlipColor = 5

local function stopFarm()
    startFarm = false
    tasking = false

    Utils.sendNotification(
        {
            type = "error",
            description = locale("text.cancel_shift")
        }
    )

    Targets.clear(farmPointElements)
    Blips.clear()
    currentPoint = 0
    playerFarm = nil
    farmingItemName = nil
    farmingItem = nil
end

local function farmThread()
    CreateThread(
        function()
            while (startFarm) do
                if Config.ShowMarker then
                    local playerLoc = GetEntityCoords(cache.ped)
                    if
                        currentPoint > 0 and
                            GetDistanceBetweenCoords(
                                playerLoc.x,
                                playerLoc.y,
                                playerLoc.z,
                                farmingItem.points[currentPoint].x,
                                farmingItem.points[currentPoint].y,
                                farmingItem.points[currentPoint].z,
                                true
                            ) <= 30
                     then
                        DrawMarker(
                            2,
                            farmingItem.points[currentPoint].x,
                            farmingItem.points[currentPoint].y,
                            farmingItem.points[currentPoint].z + 0.3,
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
    if Config.UseEmoteMenu then
        ExecuteCommand("e c")
    else
        ClearPedTasks(PlayerPedId())
    end
    deleteBlip(blip)
end

local function actionProcess(description, duration)
    return lib.progressBar(
        {
            duration = duration,
            label = description,
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
                combat = true
            }
        }
    )
end

local function nextTask(farmItem)
    if tasking then
        return
    end
    if (farmItem.randomRoute) then
        currentPoint = math.random(1, #(farmItem.points))
    else
        if farmItem.unlimited and currentSequence >= #(farmItem.points) then
            currentPoint = 1
        else
            currentPoint = currentSequence + 1
        end
    end
    tasking = true
    blipSettings.coords =
        vec3(farmItem.points[currentPoint].x, farmItem.points[currentPoint].y, farmItem.points[currentPoint].z)
    blipSettings.text = locale("misc.farm_point")
    blipSettings.sprite = 465
    blip = createBlip(blipSettings)
end

local function openPoint(point, itemName, item, farm)
    if Config.Debug then
        print(point, itemName, json.encode(item), json.encode(farm))
    end
    lib.hideTextUI()
    if not item["unlimited"] then
        if Config.UseTarget then
            exports.ox_target:removeZone(farmPointElements[point])
        else
            farmPointElements[point].zone:destroy()
        end
    end
    currentSequence = currentPoint
    currentPoint = -1
    local duration = item.collectTime or DefaultCollectTime
    local animation = nil
    if (item["animation"]) then
        animation = item.animation
    else
        if Config.UseEmoteMenu then
            animation = DefaultAnimCmd
        else
            animation = DefaultAnim
            animation["duration"] = duration
        end
    end
    pickAnim(animation)
    local itemRegister = Utils.items[itemName]
    local collectItem = item["collectItem"] or {}
    if collectItem["name"] and collectItem["durability"] then
        lib.callback.await("mri_Qfarm:server:UseItem", false, item)
    end
    if (item["gainStress"] and item["gainStress"]["max"]) or 0 > 0 then
        lib.callback.await("mri_Qfarm:server:GainStress", false, item)
    end
    if actionProcess(locale("progress.pick_farm", itemRegister.label), duration) then
        -- Done
        if not farm or not farm.config.nostart then
            lib.callback.await("mri_Qfarm:server:getRewardItem", false, itemName, playerFarm.farmId)
            print("^3[mri_Qfarm] Coleta concluída para: " .. playerFarm.name .. "^7")

            -- Adicionar print de debug para verificar a configuração de alerta
            if playerFarm.config.policeAlert then
                print("^2[mri_Qfarm] Configuração de alerta policial: ^7")
                print("^2[mri_Qfarm] - Ativado: " .. (playerFarm.config.policeAlert.enabled and "Sim" or "Não") .. "^7")
                print("^2[mri_Qfarm] - Chance: " .. (playerFarm.config.policeAlert.chance or 0) .. "%^7")
                print("^2[mri_Qfarm] - Tipo: " .. (playerFarm.config.policeAlert.type or "drugsell") .. "^7")

                -- Adicionar informação sobre a configuração específica do item
                local itemConfig = playerFarm.config.items[itemName]
                if itemConfig and itemConfig.policeAlert then
                    print("^2[mri_Qfarm] Configuração de alerta específica do item: ^7")
                    print(
                        "^2[mri_Qfarm] - Chance do item: " ..
                            (itemConfig.policeAlert.chance ~= nil and itemConfig.policeAlert.chance or "não definida") ..
                                "%^7"
                    )
                    print("^2[mri_Qfarm] - Tipo do item: " .. (itemConfig.policeAlert.type or "não definido") .. "^7")
                end
            else
                print("^1[mri_Qfarm] Configuração de alerta policial não encontrada^7")
            end
        end

        finishPicking()
        if farm and farm.config.nostart and farm.config.afk then
            openPoint(point, itemName, item, farm)
        end
    else
        -- Cancel
        Utils.sendNotification(
            {
                description = locale("task.cancel_task"),
                type = "error"
            }
        )
        finishPicking()
    end
end

local function cleanupDebugBlips()
    if Farms then
        for _, farm in pairs(Farms) do
            if farm.config and farm.config.items then
                for _, item in pairs(farm.config.items) do
                    -- Clean up blips
                    if item.debugBlips then
                        for _, blip in ipairs(item.debugBlips) do
                            if DoesBlipExist(blip) then
                                RemoveBlip(blip)
                            end
                        end
                        item.debugBlips = nil
                    end

                    -- Clean up polyzones
                    if item.debugZones then
                        for _, zone in ipairs(item.debugZones) do
                            zone:remove()
                        end
                        item.debugZones = nil
                    end
                end
            end
        end
    end
end

local function checkInteraction(point, item)
    local collectItem = item["collectItem"] or {}
    local collectItemName = collectItem["name"]
    local collectItemDurability = collectItem["durability"]

    if not playerFarm then
        return false
    end

    if not (currentPoint == point) then
        Utils.sendNotification(
            {
                id = "farm:error.wrong_point",
                title = locale("error.wrong_point_title"),
                description = locale("error.wrong_point_message"),
                type = "error"
            }
        )
        return false
    end

    if IsPedInAnyVehicle(cache.ped, false) then
        Utils.sendNotification(
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
        Utils.sendNotification(
            {
                id = "farm:error.incorrect_vehicle",
                description = locale("error.incorrect_vehicle"),
                type = "error"
            }
        )
        return false
    end

    if collectItemName then
        local toolItems = exports.ox_inventory:Search("slots", collectItemName)
        if not toolItems or #toolItems == 0 then
            Utils.sendNotification(
                {
                    id = "farm:error.no_item",
                    description = locale("error.no_item", collectItemName),
                    type = "error"
                }
            )
            return false
        end

        local requiredDurability = collectItemDurability or 1
        local toolItem = nil

        for _, item in pairs(toolItems) do
            local slot = item.slot

            -- Se não tiver metadata, ou não tiver durability, solicita ao servidor que defina
            if not item.metadata or item.metadata.durability == nil then
                item.metadata = item.metadata or {}
                item.metadata.durability = 100

                local success =
                    lib.callback.await("mri_Qfarm:setItemDurability", false, collectItemName, slot, item.metadata)
                if not success then
                    Utils.sendNotification(
                        {
                            id = "farm:error.metadata_fail",
                            description = "Erro ao aplicar metadados no item.",
                            type = "error"
                        }
                    )
                    return false
                end
            end

            if item.metadata.durability >= requiredDurability then
                toolItem = item
                break
            end
        end

        if not toolItem then
            Utils.sendNotification(
                {
                    id = "farm:error.low_durability",
                    description = locale("error.low_durability", Utils.items[collectItemName].label),
                    type = "error"
                }
            )
            return false
        end
    end

    return true
end

local function loadFarmPoints(itemName, item, farm)
    for point, zone in pairs(item.points) do
        zone = vector3(zone.x, zone.y, zone.z)
        local label = ("farmZone-%s-%s"):format(itemName, point)
        if Config.UseTarget then
            farmPointElements[point] =
                exports.ox_target:addSphereZone(
                {
                    coords = zone,
                    name = label,
                    options = {
                        name = label,
                        icon = "fa-solid fa-screwdriver-wrench",
                        label = locale("target.label", item.label),
                        canInteract = function()
                            if farm and farm.config and farm.config.nostart then
                                return true
                            end
                            return checkInteraction(point, item)
                        end,
                        onSelect = function()
                            openPoint(point, itemName, item, farm)
                        end
                    }
                }
            )
        else
            farmPointElements[point] = {
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
            farmPointElements[point].zone:onPlayerInOut(
                function(isPointInside)
                    farmPointElements[point].isInside = isPointInside
                    if farmPointElements[point].isInside then
                        if point == currentPoint then
                            CreateThread(
                                function()
                                    while farmPointElements[point].isInside do
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

local function startAutoFarm(args)
    playerFarm = args.farm
    local itemName = args.itemName
    local farmItem = playerFarm.config.items[itemName]
    loadFarmPoints(itemName, farmItem, playerFarm)
end

local function startFarming(args)
    playerFarm = args.farm
    local itemName = args.itemName
    local farmItem = playerFarm.config.items[itemName]
    loadFarmPoints(itemName, farmItem)
    startFarm = true
    farmingItemName = itemName
    farmingItem = farmItem
    local amount = -1
    if (not farmItem.unlimited) then
        amount = #(farmItem.points)
    end

    currentSequence = 0
    Utils.sendNotification(
        {
            description = locale("text.start_shift", farmItem["customName"] or Utils.items[itemName].label),
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
                Utils.sendNotification(
                    {
                        description = locale("text.end_shift"),
                        type = "info"
                    }
                )
            else
                nextTask(farmItem)
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
    for itemName, v in pairs(farm.config.items) do
        local item = Utils.items[itemName]
        if not (item == nil) then
            ctx.options[#ctx.options + 1] = {
                title = v["customName"] and v["customName"] ~= "" and v["customName"] or item.label,
                description = item.description,
                icon = string.format("%s/%s.png", ImageURL, item.name),
                image = string.format("%s/%s.png", ImageURL, item.name),
                metadata = Utils.getItemMetadata(item, true),
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
        local item = Utils.items[farmingItemName]
        ctx.options[#ctx.options + 1] = {
            title = locale("menus.cancel_farm"),
            icon = "fa-solid fa-ban",
            description = item.label,
            onSelect = stopFarm,
            args = {
                farm = farm,
                itemName = farmingItemName
            }
        }
    end
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
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
    Targets.clear()
    Bilps.clear()
    Markers.clear()
    Zones.clear()
    for k, v in pairs(Farms) do
        local isPublic = Utils.isPublic(v)
        if
            isPublic or Utils.roleCheck(PlayerJob, v.group.name, v.group.grade) or
                Utils.roleCheck(PlayerGang, v.group.name, v.group.grade)
         then
            if v.config.start["location"] then
                local start = v.config.start
                start.location = vector3(start.location.x, start.location.y, start.location.z)
                local zoneName = ("farm-%s"):format("start" .. k)
                if Config.UseTarget then
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
                                        checkAndOpen(v, isPublic)
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
                                    checkAndOpen(v, isPublic)
                                end
                            }
                        }
                    )
                end
            end

            if v.config.nostart then
                local farm = v

                for itemName, _ in pairs(farm.config.items) do
                    local item = Utils.items[itemName]
                    if not (item == nil) then
                        startAutoFarm(
                            {
                                farm = farm,
                                itemName = itemName
                            }
                        )
                    end
                end
            end
        end
    end
end

AddEventHandler(
    "onResourceStart",
    function(resourceName)
        if resourceName == GetCurrentResourceName() then
            PlayerData = QBX.PlayerData
            PlayerJob = PlayerData.job
            PlayerGang = PlayerData.gang
        end
    end
)

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName == GetCurrentResourceName() then
            cleanupDebugBlips()
        end
    end
)

RegisterNetEvent(
    "QBCore:Client:OnPlayerLoaded",
    function()
        PlayerData = QBX.PlayerData
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

        if (group and farmingItemName) then
            stopFarm()
        end
        cleanupDebugBlips()
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

-- Add this event handler to receive police alerts from the server
RegisterNetEvent(
    "mri_Qfarm:client:PoliceAlert",
    function(data)
        print("^2[mri_Qfarm] Evento de alerta policial recebido^7")
        print("^2[mri_Qfarm] - Item que acionou o alerta: " .. data.itemName .. "^7")

        if not PlayerData or PlayerData.job.name ~= "police" or not PlayerData.job.onduty then
            print("^1[mri_Qfarm] Alerta ignorado: jogador não é policial ou não está em serviço^7")
            return
        end

        print("^2[mri_Qfarm] Criando blip para alerta policial^7")
        print("^2[mri_Qfarm] - Tipo: " .. data.type .. "^7")
        print("^2[mri_Qfarm] - Localização: " .. data.streetName .. "^7")
        print("^2[mri_Qfarm] - Mensagem: " .. data.message .. "^7")
        print("^2[mri_Qfarm] - Fazenda: " .. data.farmName .. "^7")

        -- Create a blip at the location
        local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
        SetBlipSprite(blip, 161) -- You can change this to another sprite
        SetBlipScale(blip, 1.0)
        SetBlipColour(blip, 1) -- Red color
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Atividade Suspeita")
        EndTextCommandSetBlipName(blip)

        -- Make the blip flash
        SetBlipFlashes(blip, true)

        -- Trigger the appropriate ps-dispatch alert based on the type
        if exports["ps-dispatch"] then
            print("^2[mri_Qfarm] Acionando ps-dispatch com tipo: " .. data.type .. "^7")
            if data.type == "drugsell" then
                exports["ps-dispatch"]:DrugSale()
            elseif data.type == "susactivity" then
                exports["ps-dispatch"]:SuspiciousActivity()
            elseif data.type == "houserobbery" then
                exports["ps-dispatch"]:HouseRobbery()
            elseif data.type == "storerobbery" then
                exports["ps-dispatch"]:StoreRobbery()
            else
                -- Fallback para alerta personalizado
                exports["ps-dispatch"]:CustomAlert(
                    {
                        message = data.message,
                        dispatchCode = "10-31",
                        priority = 2
                    }
                )
            end
        else
            print("^1[mri_Qfarm] ps-dispatch não encontrado^7")
        end

        -- Send notification to the police officer
        Utils.sendNotification(
            {
                title = "Alerta Policial",
                description = "Atividade suspeita detectada em " .. data.streetName,
                type = "inform"
            }
        )

        -- Remove the blip after some time
        print("^2[mri_Qfarm] Blip será removido em 60 segundos^7")
        SetTimeout(
            60000,
            function()
                RemoveBlip(blip)
                print("^2[mri_Qfarm] Blip removido^7")
            end
        )
    end
)
