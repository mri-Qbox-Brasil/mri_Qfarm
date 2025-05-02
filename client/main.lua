local Utils = lib.require("shared/utils")
local Defaults = require("client/defaults")
local Blips = lib.require("client/interaction/blips")
local Markers = lib.require("client/interaction/markers")
local Text = lib.require("client/interaction/texts")
local Targets = lib.require("client/interaction/targets")
local Zones = lib.require("client/interaction/zones")
local Route = lib.require("client/modules/route")
local NoStart = lib.require("client/modules/no_start")

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
    if Defaults.Farms then
        for _, farm in pairs(Defaults.Farms) do
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

local function startAutoFarm(args)
    playerFarm = args.farm
    local itemName = args.itemName
    local farmItem = playerFarm.config.items[itemName]
    loadFarmPoints(itemName, farmItem, playerFarm)
end

local function loadFarms()
    Targets.clear()
    Blips.clear()
    Markers.clear()
    Zones.clear()
    Route.clear()
    NoStart.clear()
    for k, v in pairs(Defaults.Farms) do
        if v.config.nostart then
            NoStart.add(v)
        elseif v.config.start["location"] then
            Route.add(v)
        end
    end
    Route.loadFarms()
    NoStart.loadFarms()
    if Config.Debug then
        print("^2[mri_Qfarm] Farms carregadas com sucesso^7")
    end
end

AddEventHandler(
    "onResourceStart",
    function(resourceName)
        if resourceName == GetCurrentResourceName() then
            Utils.loadPlayerData(QBX.PlayerData)
        end
    end
)

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName == GetCurrentResourceName() then
            Targets.clear()
            Blips.clear()
            Markers.clear()
            Zones.clear()
        end
    end
)

RegisterNetEvent(
    "QBCore:Client:OnPlayerLoaded",
    function()
        Utils.loadPlayerData(QBX.PlayerData)
        loadFarms()
    end
)

RegisterNetEvent(
    "QBCore:Client:OnPlayerUnload",
    function()
        local group = nil
        if Utils.playerGang and Utils.playerGang.name then
            group = Utils.playerGang.name
        elseif (Utils.playerJob and Utils.playerJob.name) then
            group = Utils.playerJob.name
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
        Utils.playerJob = JobInfo
        loadFarms()
    end
)

RegisterNetEvent(
    "QBCore:Client:OnGangUpdate",
    function(GangInfo)
        Utils.playerGang = GangInfo
        loadFarms()
    end
)

RegisterNetEvent(
    "mri_Qfarm:client:LoadFarms",
    function()
        Defaults.Farms = GlobalState.Farms or {}
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
