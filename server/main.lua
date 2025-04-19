local QBCore = exports["qb-core"]:GetCoreObject()
local Utils = require ("shared/utils")
local Storage = require ("server/storage")
local Farms = GlobalState.Farms or {}

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

        Utils.itemAdd(src, itemName, qtd)
        if (itemCfg["extraItems"]) then
            for name, config in pairs(itemCfg.extraItems) do
                local qtd = math.random(config.min, config.max)
                if not exports.ox_inventory:CanCarryItem(src, itemName, qtd) then return end

                Utils.itemAdd(src, name, qtd)
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

AddEventHandler(
    "onResourceStart",
    function(resource)
        Wait(200)
        if resource == GetCurrentResourceName() then
            Storage:loadFarms()
            Utils.dispatchEvents(source)
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
