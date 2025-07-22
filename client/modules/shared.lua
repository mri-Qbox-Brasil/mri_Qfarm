-- Aqui fica tudo que é compartilhado entre os farms
local Utils = lib.require("shared/utils")

local function isInAnyVehicle()
    if IsPedInAnyVehicle(cache.ped, false) then
        Utils.sendNotification(
            {
                id = "farm:error.not_in_vehicle",
                description = locale("error.not_in_vehicle"),
                type = "error"
            }
        )
        Utils.debug("checkInteraction", "isInAnyVehicle is true")
        return true
    end
    Utils.debug("checkInteraction", "isInAnyVehicle is false")
    return false
end

local function wasInFarmVehicle(playerFarm)
    if
        playerFarm.config["vehicle"] and
            IsVehicleModel(GetVehiclePedIsIn(cache.ped, true), GetHashKey(playerFarm.config["vehicle"]))
     then
        Utils.debug("checkInteraction", "wasInFarmVehicle is true")
        return true
    end
    Utils.sendNotification(
        {
            id = "farm:error.incorrect_vehicle",
            description = locale("error.incorrect_vehicle"),
            type = "error"
        }
    )
    Utils.debug("checkInteraction", "wasInFarmVehicle is false")
    return false
end

local function hasCollectItemWithDurability(farmItem)
    local collectItem = farmItem["collectItem"] or {}
    local collectItemName = collectItem["name"] or nil
    local collectItemDurability = collectItem["durability"] or 0

    if collectItemName then
        Utils.debug("checkInteraction", "farm has collectItem")
        local toolItems = Utils.inventory:Search("slots", collectItemName)
        if not toolItems then
            -- Verifica se o player tem o item certo
            Utils.sendNotification(
                {
                    id = "farm:error.no_item",
                    description = locale("error.no_item", collectItemName),
                    type = "error"
                }
            )
            Utils.debug("checkInteraction", "toolItems is nil")
            return false
        end

        if collectItemDurability and collectItemDurability > 0 then
            Utils.debug("checkInteraction", "farm has collectItem with durability")
            local toolItem
            for k, v in pairs(toolItems) do
                if v["metadata"] and v.metadata["durability"] and v.metadata.durability then
                    toolItem = v
                    break
                end
            end

            if toolItem then
                Utils.debug("checkInteraction", "toolItem is not nil")
                if toolItem.metadata.durability < collectItemDurability then
                    -- Verifica se o item tem durabilidade
                    Utils.sendNotification(
                        {
                            id = "farm:error.low_durability",
                            description = locale("error.low_durability", Items[collectItemName].label),
                            type = "error"
                        }
                    )
                    Utils.debug("checkInteraction", "toolItem.metadata.durability is less than collectItemDurability")
                    return false
                end
            else
                -- Verifica se o item configurado está correto
                Utils.sendNotification(
                    {
                        id = "farm:error.invalid_item_type",
                        description = locale("error.invalid_item_type", collectItemName),
                        type = "error"
                    }
                )
                Utils.debug("checkInteraction", "toolItem is nil")
                return false
            end
        end
    end
    return true
end

local function checkInteraction(farmItem, playerFarm)
    if not playerFarm then
        Utils.debug("checkInteraction", "playerFarm is nil")
        return false
    end

    if isInAnyVehicle() then
        return false
    end

    if not wasInFarmVehicle(playerFarm) then
        return false
    end

    if not hasCollectItemWithDurability(farmItem) then
        Utils.debug("checkInteraction", "hasCollectItemWithDurability is false")
        return false
    end

    return true
end

return {
    checkInteraction = checkInteraction
}
