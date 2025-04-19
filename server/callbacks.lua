local Utils = require("shared/utils")
local Storage = require("server/storage")

local function createFarm(source, farm)
    if not IsPlayerAceAllowed(source, Config.AuthorizationManager) then
        return {type = "error", description = locale("error.not_allowed")}
    end

    local farmId = Storage.createFarm(farm)
    if farmId <= 0 then
        return {type = "error", description = locale("actions.not_saved")}
    end

    return {type = "success", description = locale("actions.saved")}
end

local function updateFarm(source, farm)
    if not farm.farmId then
        return {type = "error", description = locale("error.farm_not_found", farm.farmId)}
    end

    if not IsPlayerAceAllowed(source, Config.AuthorizationManager) then
        return {type = "error", description = locale("error.not_allowed")}
    end

    if not Storage.updateFarm(farm) then
        return {type = "error", description = locale("actions.not_saved")}
    end
    return {type = "success", description = locale("actions.saved")}
end

local function deleteFarm(source, farmId)
    if not farmId then
        return {type = "error", description = locale("error.farm_not_found", farmId)}
    end

    if not IsPlayerAceAllowed(source, Config.AuthorizationManager) then
        return {type = "error", description = locale("error.not_allowed")}
    end

    if not Storage.deleteFarm(farmId) then
        return {type = "error", description = locale("actions.delete_error", farmId)}
    end

    return {type = "success", description = locale("actions.deleted")}
end

local function duplicateFarm(source, farmId)
    if not farmId then
        return {type = "error", description = locale("error.farm_not_found", farmId)}
    end

    if not IsPlayerAceAllowed(source, Config.AuthorizationManager) then
        return {type = "error", description = locale("error.not_allowed")}
    end

    local newFarm = {
        name = Farms[farmId].name .. " (copy)",
        config = json.decode(json.encode(Farms[farmId].config)),
        group = json.decode(json.encode(Farms[farmId].group))
    }

    if not Storage.createFarm(newFarm) then
        return {type = "error", description = locale("actions.not_duplicated")}
    end

    return {type = "success", description = locale("actions.duplicated")}
end

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

lib.callback.register(
    "mri_Qfarm:server:UseItem",
    function(source, item)
        local toolItem = Utils.inventory:Search(source, "slots", item.collectItem.name)

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

        Utils.inventory:SetDurability(source, toolItem.slot, toolItem.metadata.durability - item.collectItem.durability)
        return true
    end
)

lib.callback.register(
    "mri_Qfarm:setItemDurability",
    function(source, itemName, slot, metadata)
        local items = Utils.inventory:Search(source, "slots", itemName)
        for _, item in pairs(items) do
            if item.slot == slot then
                Utils.inventory:SetMetadata(source, slot, metadata)
                return true
            end
        end
        return false
    end
)

lib.callback.register(
    "mri_Qfarm:server:SaveFarm",
    function(source, farm)
        local source = source
        local response = nil
        if farm.farmId then
            response = updateFarm(source, farm)
        else
            response = createFarm(source, farm)
        end
        Utils.dispatchEvents(source, response)
        return true
    end
)

lib.callback.register(
    "mri_Qfarm:server:DeleteFarm",
    function(source, farmId)
        local response = deleteFarm(source, farmId)
        Utils.dispatchEvents(source, response)
        return true
    end
)

lib.callback.register(
    "mri_Qfarm:server:DuplicateFarm",
    function(source, farmId)
        local response = duplicateFarm(source, farmId)
        Utils.dispatchEvents(source, response)
        return true
    end
)
