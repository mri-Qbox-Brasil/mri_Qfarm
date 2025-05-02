local ImageURL = "https://cfx-nui-ox_inventory/web/images"
local inventory = exports.ox_inventory
local items = inventory:Items()
local Defaults = require("client/defaults")

local PlayerJob = {}
local PlayerGang = {}

local function debug(msg1, msg2)
    if Config.Debug then
        print(string.format("[%s] %s: %s", GetCurrentResourceName(), msg1, msg2))
    end
end

local function itemAdd(source, item, amount)
    if (amount > 0) then
        inventory:AddItem(source, item, amount)
    end
end

local function findById(id, farms)
    for k, v in pairs(farms) do
        if v.farmId == id then
            return k
        end
    end
end

function sendNotification(data)
    local notifyData = {
        id = data["id"] or nil,
        title = data["title"] or nil,
        description = data["description"] or nil,
        type = data["type"] or "info"
    }
    if (data["source"]) then
        lib.notify(data["source"], notifyData)
    else
        lib.notify(notifyData)
    end
end

local function dispatchEvents(source, response)
    Wait(2000)
    TriggerClientEvent("mri_Qfarm:client:LoadFarms", -1)
    if response then
        sendNotification({source = source, description = response.description, type = response.type})
    end
end

local function getPedCoords()
    lib.hideTextUI()
    local text = {}
    table.insert(text, locale("actions.choose_location.1"))
    table.insert(text, locale("actions.choose_location.2"))
    lib.showTextUI(
        table.concat(text),
        {
            position = "right-center"
        }
    )

    while true do
        Wait(0)
        if IsControlJustReleased(0, 38) then
            lib.hideTextUI()
            return {
                result = "choose",
                coords = GetEntityCoords(cache.ped)
            }
        end
        if IsControlJustReleased(0, 177) then
            lib.hideTextUI()
            return {
                result = "cancel",
                coords = nil
            }
        end
        if IsControlJustPressed(0, 201) then
            lib.hideTextUI()
            return {
                result = "end",
                coords = nil
            }
        end
    end
end

local function tpToLoc(coords)
    if coords then
        DoScreenFadeOut(500)
        Wait(1000)
        SetPedCoordsKeepVehicle(PlayerPedId(), coords.x, coords.y, coords.z)
        DoScreenFadeIn(500)
    end
end

local function confirmationDialog(content)
    return lib.alertDialog(
        {
            header = locale("dialog.confirmation"),
            content = content,
            centered = true,
            cancel = true,
            labels = {
                cancel = locale("actions.cancel"),
                confirm = locale("actions.confirm")
            }
        }
    )
end

local function getLocation(coords)
    local streetName, crossingRoad = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    return GetStreetNameFromHashKey(streetName)
end

local function getLocationFormatted(location, key)
    if key then
        return string.format("[%02d] - %s", key, getLocation(location))
    else
        return getLocation(location)
    end
end

local function getGroupGrades(group)
    local grades = {}
    for k, v in pairs(group.grades) do
        grades[#grades + 1] = {
            value = k,
            label = string.format("%s - %s", k, v.name)
        }
    end
    return grades
end

local function getBaseGroups(named)
    local jobs = exports.qbx_core:GetJobs()
    local gangs = exports.qbx_core:GetGangs()
    local groups = {}
    for k, v in pairs(jobs) do
        if v.type then
            local data = {
                value = k,
                label = v.label,
                grades = getGroupGrades(v)
            }
            if named then
                groups[k] = data
            else
                groups[#groups + 1] = data
            end
        end
    end
    for k, v in pairs(gangs) do
        if not (k == "none") then
            local data = {
                value = k,
                label = v.label,
                grades = getGroupGrades(v)
            }
            if named then
                groups[k] = data
            else
                groups[#groups + 1] = data
            end
        end
    end
    return groups
end

local function getGroupsLabel(groups)
    local baseGroups = getBaseGroups(true)
    local groupName = ""
    for i = 1, #(groups) do
        local group = locale("error.group_not_found", groups[i])
        if baseGroups[groups[i]] then
            group = baseGroups[groups[i]]["label"]
        end
        if groupName == "" then
            groupName = group
        else
            groupName = groupName .. ", " .. group
        end
    end
    groupName = groupName == "" and locale("creator.no_group") or groupName
    return groupName
end

local function getBaseItems()
    local result = {}
    for k, v in pairs(items) do
        result[#result + 1] = {
            value = k,
            label = string.format("%s (%s)", v.label, k)
        }
    end
    return result
end

local function getItemMetadata(item, hideSpawn)
    local result = {}
    if not hideSpawn then
        result[#result + 1] = {
            label = locale("items.spawn"),
            value = item.name
        }
    end
    if item.weight then
        result[#result + 1] = {
            label = locale("items.weight"),
            value = item.weight
        }
    end
    if item.type then
        result[#result + 1] = {
            label = locale("items.type"),
            value = item.type
        }
    end
    return result
end

local function getMetadataFromFarm(key)
    local data = {}
    local items = Defaults.Farms[key].config.items
    for k, v in pairs(items) do
        if Items[k] then
            data[#data + 1] = {
                label = locale("menus.route"),
                value = string.format("%s (%s)", items[k].label, k)
            }
        end
    end
    if #data <= 0 then
        return {
            {
                label = locale("menus.route"),
                value = locale("menus.no_route")
            }
        }
    end
    return data
end

local function getDefaultAnim(useEmoteMenu)
    if not useEmoteMenu then
        return Defaults.Anim
    end
    return Defaults.AnimCmd
end

local function isPublic(farm)
    return not farm.group["name"] or #farm.group["name"] == 0
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

local function loadPlayerData(playerData)
    PlayerJob = playerData.job
    PlayerGang = playerData.gang
end

local function checkPerms(farm)
    return isPublic(farm) or roleCheck(PlayerJob, farm.group.name, farm.group.grade) or
        roleCheck(PlayerGang, farm.group.name, farm.group.grade)
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

return {
    items = items,
    inventory = inventory,
    debug = debug,
    playerJob = PlayerJob,
    playerGang = PlayerGang,
    isPlayerAuthorized = isPlayerAuthorized,
    itemAdd = itemAdd,
    findById = findById,
    sendNotification = sendNotification,
    dispatchEvents = dispatchEvents,
    getPedCoords = getPedCoords,
    getBaseGroups = getBaseGroups,
    getGroupGrades = getGroupGrades,
    getGroupsLabel = getGroupsLabel,
    getBaseItems = getBaseItems,
    getItemMetadata = getItemMetadata,
    getMetadataFromFarm = getMetadataFromFarm,
    getLocation = getLocation,
    getLocationFormatted = getLocationFormatted,
    getDefaultAnim = getDefaultAnim,
    isPublic = isPublic,
    roleCheck = roleCheck,
    tpToLoc = tpToLoc,
    confirmationDialog = confirmationDialog,
    loadPlayerData = loadPlayerData,
    checkPerms = checkPerms,
    pickAnim = pickAnim,
    actionProcess = actionProcess
}
