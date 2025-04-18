local QBCore = exports["qb-core"]:GetCoreObject()
Farms = GlobalState.Farms or {}
local ox_inventory = exports.ox_inventory
Items = ox_inventory:Items()

local SELECT_DATA = "SELECT * FROM mri_qfarm"
local INSERT_DATA = "INSERT INTO mri_qfarm (farmName, farmConfig, farmGroup) VALUES (?, ?, ?)"
local UPDATE_DATA = "UPDATE mri_qfarm SET farmName = ?, farmConfig = ?, farmGroup = ? WHERE farmId = ?"
local DELETE_DATA = "DELETE FROM mri_qfarm WHERE farmId = ?"

local function isPlayerAuthorized(src)
    if IsPlayerAceAllowed(src, Config.AuthorizationManager) then
        return true
    end
    lib.notify(source, {type = "error", description = locale("error.not_allowed")})
    return false
end

local function itemAdd(source, item, amount)
    if (amount > 0) then
        ox_inventory:AddItem(source, item, amount)
    end
end

local function dispatchEvents(source, response)
    GlobalState:set("Farms", Farms, true)
    Wait(2000)
    TriggerClientEvent("mri_Qfarm:client:LoadFarms", -1)
    if response then
        lib.notify(source, response)
    end
end

local function locateFarm(id)
    for k, v in pairs(Farms) do
        if v.farmId == id then
            return k
        end
    end
end

local function cleanNullPoints(config)
    for name, value in pairs(config.items) do
        local newPoints = {}
        for k, v in pairs(value.points) do
            newPoints[#newPoints + 1] = v
        end
        config.items[name].points = newPoints
    end
    return config
end

lib.callback.register(
    "mri_Qfarm:server:UseItem",
    function(source, item)
        local toolItem = exports.ox_inventory:Search(source, "slots", item.collectItem.name)

        if toolItem then
            for k, v in pairs(toolItem) do
                if v.metadata.durability >= item.collectItem.durability then
                    toolItem = v
                    break
                end
            end
        else
            return
        end

        ox_inventory:SetDurability(source, toolItem.slot, toolItem.metadata.durability - item.collectItem.durability)
        return true
    end
)

lib.callback.register(
    "mri_Qfarm:server:GainStress",
    function(source, item)
        local src = source
        local player = exports.qbx_core:GetPlayer(src)
        if not player.PlayerData.metadata.stress then
            player.PlayerData.metadata.stress = 0
        end
        if item.gainStress.max == 0 then
            return
        end
        local amount = math.random(item.gainStress.min, item.gainStress.max)
        local newStress = player.PlayerData.metadata.stress + amount
        if newStress <= 0 then
            newStress = 0
        elseif newStress > 100 then
            newStress = 100
        end
        player.Functions.SetMetaData("stress", newStress)
        TriggerClientEvent("hud:client:UpdateStress", src, newStress)
        exports.qbx_core:Notify(
            src,
            locale("notify.stress_gain"),
            "inform",
            3000,
            nil,
            nil,
            {"#141517", "#ffffff"},
            "brain",
            "#C53030"
        )
    end
)

-- When a player collects a reward item, check for police alert
lib.callback.register(
    "mri_Qfarm:server:getRewardItem",
    function(source, itemName, farmId)
        if Config.Debug then
            print("debug getRewardItem: ", source, itemName, farmId)
        end
        local src = source
        local cfg = nil

        if Config.Debug then
            print("farms: ", json.encode(Farms))
        end

        for k, v in pairs(Farms) do
            if v.farmId == farmId then
                cfg = v
                break
            end
        end

        local msg = nil
        if not cfg then
            msg = locale("error.farm_not_found", farmId)
            print(msg)
            lib.notify(src, {type = "error", description = msg})
            return
        end

        if (not Items[itemName]) then
            msg = locale("error.item_not_found", itemName)
            print(msg)
            lib.notify(src, {type = "error", description = msg})
            return
        end

        if Config.Debug then
            print("CFG", json.encode(cfg))
        end

        local itemCfg = cfg.config.items[itemName]

        if (not itemCfg) then
            msg = locale("error.item_cfg_not_found", itemName)
            print(msg)
            lib.notify(src, {type = "error", description = msg})
            return
        end

        -- POLICE ALERT FEATURE START - MODIFICADO PARA SUPORTAR ALERTA POR ITEM
        local alertConfig = cfg.config.policeAlert or {}
        local itemAlertConfig = itemCfg.policeAlert or {}

        -- Verifica se o alerta global está ativado OU se o item tem configuração específica
        local itemHasAlert = itemAlertConfig.chance ~= nil

        if (alertConfig.enabled or itemHasAlert) then
            -- Corrigindo a lógica para priorizar corretamente a chance do item
            local chance = alertConfig.chance or 0

            -- Se o item tiver uma configuração de chance específica, use-a
            if itemAlertConfig.chance ~= nil then
                chance = itemAlertConfig.chance
            end

            print("^2[mri_Qfarm] Verificando alerta policial para item: " .. itemName .. "^7")
            print("^2[mri_Qfarm] - Alerta global ativado: " .. (alertConfig.enabled and "Sim" or "Não") .. "^7")
            print("^2[mri_Qfarm] - Chance global: " .. (alertConfig.chance or 0) .. "%^7")
            print("^2[mri_Qfarm] - Item tem configuração específica: " .. (itemHasAlert and "Sim" or "Não") .. "^7")
            print("^2[mri_Qfarm] - Chance do item: " .. (itemAlertConfig.chance ~= nil and itemAlertConfig.chance or "não definida") .. "%^7")
            print("^2[mri_Qfarm] - Chance final utilizada: " .. chance .. "%^7")

            if math.random(1, 100) <= chance then
                -- Usa o tipo específico do item se existir, senão usa o tipo global
                local alertType = itemAlertConfig.type or alertConfig.type or "drugsell"
                -- Trigger police alert
                TriggerEvent("mri_Qfarm:server:PoliceAlert", src, cfg, itemName, {
                    type = alertType,
                    chance = chance,
                    enabled = true
                })
            else
                print("^3[mri_Qfarm] Alerta policial não acionado (chance: " .. chance .. "%)^7")
            end
        else
            print("^3[mri_Qfarm] Alerta policial desativado para esta fazenda e item não tem configuração específica^7")
        end
        -- POLICE ALERT FEATURE END

        local qtd = math.random(itemCfg.min or 0, itemCfg.max or 1)
        if not exports.ox_inventory:CanCarryItem(src, itemName, qtd) then return end

        itemAdd(src, itemName, qtd)
        if (itemCfg["extraItems"]) then
            for name, config in pairs(itemCfg.extraItems) do
                local qtd = math.random(config.min, config.max)
                if not exports.ox_inventory:CanCarryItem(src, itemName, qtd) then return end

                itemAdd(src, name, qtd)
            end
        end
        return true
    end
)

-- Improved police alert event handler
AddEventHandler("mri_Qfarm:server:PoliceAlert", function(src, farm, itemName, alertConfig)
    local alertType = alertConfig.type or "drugsell"
    local coords = GetEntityCoords(GetPlayerPed(src))

    -- Corrigindo o erro com GetStreetNameAtCoord
    local streetName = "Desconhecido" -- Valor padrão caso não consiga obter o nome da rua

    -- Adicionando prints de debug
    print("^2[mri_Qfarm] Alerta policial acionado^7")
    print("^2[mri_Qfarm] - Jogador: " .. src .. "^7")
    print("^2[mri_Qfarm] - Fazenda: " .. farm.name .. "^7")
    print("^2[mri_Qfarm] - Item: " .. itemName .. "^7")
    print("^2[mri_Qfarm] - Tipo de alerta: " .. alertType .. "^7")
    print("^2[mri_Qfarm] - Coordenadas: " .. coords.x .. ", " .. coords.y .. ", " .. coords.z .. "^7")

    local message = locale("farm.alert_message", farm.name)

    -- Get all police officers
    local players = QBCore.Functions.GetQBPlayers()
    local policeCount = 0

    for _, player in pairs(players) do
        if player.PlayerData.job.name == "police" and player.PlayerData.job.onduty then
            policeCount = policeCount + 1
            -- Send notification to police officers
            TriggerClientEvent("mri_Qfarm:client:PoliceAlert", player.PlayerData.source, {
                type = alertType,
                coords = coords,
                streetName = streetName,
                message = message,
                farmName = farm.name,
                itemName = itemName
            })
            print("^2[mri_Qfarm] Alerta enviado para policial: " .. player.PlayerData.source .. "^7")
        end
    end

    print("^2[mri_Qfarm] Total de policiais notificados: " .. policeCount .. "^7")

    if Config.Debug then
        print(("Police alert triggered from farm %s by player %s! Type: %s"):format(farm.name, src, alertType))
    end
end)

lib.callback.register(
    "mri_Qfarm:server:SaveFarm",
    function(source, farm)
        local source = source
        local response = {type = "success", description = locale("actions.saved")}

        if not isPlayerAuthorized(source) then
            return
        end

        if farm.farmId then
            local affectedRows =
                MySQL.Sync.execute(
                UPDATE_DATA,
                {farm.name, json.encode(farm.config), json.encode(farm.group), farm.farmId}
            )
            if affectedRows <= 0 then
                response.type = "error"
                response.description = locale("actions.not_saved")
            end
            Farms[locateFarm(farm.farmId)] = farm
        else
            local farmId =
                MySQL.Sync.insert(INSERT_DATA, {farm.name, json.encode(farm.config), json.encode(farm.group)})
            if farmId <= 0 then
                response.type = "error"
                response.description = locale("actions.not_saved")
            else
                farm.farmId = farmId
                Farms[#Farms + 1] = farm
            end
        end
        dispatchEvents(source, response)
        return true
    end
)

lib.callback.register(
    "mri_Qfarm:server:DeleteFarm",
    function(source, farmId)
        local source = source
        local response = {type = "success", description = locale("actions.deleted")}

        if not isPlayerAuthorized(source) then
            return
        end

        if not farmId then
            TriggerClientEvent("ox_lib:notify", source, response)
            return
        end
        local affectedRows = MySQL.Sync.execute(DELETE_DATA, {farmId})
        if affectedRows <= 0 then
            response.type = "error"
            response.description = locale("actions.delete_error", farmId)
        end
        Farms[locateFarm(farmId)] = nil
        dispatchEvents(source, response)
        return true
    end
)

-- Add this callback to handle farm duplication
lib.callback.register(
    "mri_Qfarm:server:DuplicateFarm",
    function(source, farmId)
        local source = source
        local response = {type = "success", description = locale("actions.duplicated")}

        if not isPlayerAuthorized(source) then
            return
        end

        local farmIndex = locateFarm(farmId)
        if not farmIndex or not Farms[farmIndex] then
            response.type = "error"
            response.description = locale("error.farm_not_found", farmId)
            dispatchEvents(source, response)
            return false
        end

        local originalFarm = Farms[farmIndex]
        local newFarm = {
            name = originalFarm.name .. " (copy)",
            config = json.decode(json.encode(originalFarm.config)), -- Deep copy
            group = json.decode(json.encode(originalFarm.group))    -- Deep copy
        }

        local farmId = MySQL.Sync.insert(INSERT_DATA, {newFarm.name, json.encode(newFarm.config), json.encode(newFarm.group)})
        if farmId <= 0 then
            response.type = "error"
            response.description = locale("actions.not_duplicated")
            dispatchEvents(source, response)
            return false
        else
            newFarm.farmId = farmId
            Farms[#Farms + 1] = newFarm
            dispatchEvents(source, response)
            return true
        end
    end
)

AddEventHandler(
    "onResourceStart",
    function(resource)
        Wait(200)
        if resource == GetCurrentResourceName() then
            local result = MySQL.Sync.fetchAll(SELECT_DATA, {})
            local farms = {}
            if result and #result > 0 then
                for _, row in ipairs(result) do
                    local farm = {
                        farmId = row.farmId,
                        name = row.farmName,
                        config = cleanNullPoints(json.decode(row.farmConfig)),
                        group = json.decode(row.farmGroup)
                    }
                    farms[_] = farm
                end
            end
            Farms = farms
            dispatchEvents(source)
        end
    end
)

if GetResourceState("mri_Qbox") ~= "started" then
    lib.addCommand(
        "managefarms",
        {
            help = locale("creator.description_title"),
            restricted = "group.admin"
        },
        function(source, args, raw)
            lib.callback("mri_Qfarm:manageFarmsMenu", source)
        end
    )
end

lib.callback.register('mri_Qfarm:setItemDurability', function(source, itemName, slot, metadata)
    local items = exports.ox_inventory:Search(source, 'slots', itemName)
    for _, item in pairs(items) do
        if item.slot == slot then
            exports.ox_inventory:SetMetadata(source, slot, metadata)
            return true
        end
    end
    return false
end)
