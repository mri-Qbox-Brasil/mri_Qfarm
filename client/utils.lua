local Utils = {}

function Utils.GetPedCoords(uitext)
    lib.hideTextUI()
    lib.showTextUI(uitext, {
        position = 'right-center'
    })

    while true do
        Wait(0)
        if IsControlJustReleased(0, 38) then
            lib.hideTextUI()
            return 1
        end
        if IsControlJustReleased(0, 177) then
            lib.hideTextUI()
            return 0
        end
        if IsControlJustPressed(0, 201) then
            lib.hideTextUI()
            return 2
        end
    end
end

function Utils.TpToLoc(coords)
    DoScreenFadeOut(500)
    Wait(1000)
    SetPedCoordsKeepVehicle(PlayerPedId(), coords.x, coords.y, coords.z)
    DoScreenFadeIn(500)
end

function Utils.ConfirmationDialog(content)
    return lib.alertDialog({
        header = locale('dialog.confirmation'),
        content = content,
        centered = true,
        cancel = true,
        labels = {
            cancel = locale('actions.cancel'),
            confirm = locale('actions.confirm')
        }
    })
end

function Utils.GetLocation(coords)
    local streetName, crossingRoad = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    return GetStreetNameFromHashKey(streetName)
end

function Utils.GetLocationFormatted(location, key)
    if key then
        return string.format('[%02d] - %s', key, Utils.GetLocation(location))
    else
        return Utils.GetLocation(location)
    end
end

function Utils.GetGroupGrades(group)
    local grades = {}
    for k, v in pairs(group.grades) do
        grades[#grades + 1] = {
            value = k,
            label = string.format('%s - %s', k, v.name)
        }
    end
    return grades
end

function Utils.GetBaseGroups(named)
    local jobs = exports.qbx_core:GetJobs()
    local gangs = exports.qbx_core:GetGangs()
    local groups = {}
    for k, v in pairs(jobs) do
        if v.type then
            local data = {
                value = k,
                label = v.label,
                grades = Utils.GetGroupGrades(v)
            }
            if named then
                groups[k] = data
            else
                groups[#groups + 1] = data
            end
        end
    end
    for k, v in pairs(gangs) do
        local data = {
            value = k,
            label = v.label,
            grades = Utils.GetGroupGrades(v)
        }
        if named then
            groups[k] = data
        else
            groups[#groups + 1] = data
        end
    end
    return groups
end

function Utils.GetBaseItems()
    local items = {}
    for k, v in pairs(exports.ox_inventory:Items()) do
        items[#items + 1] = {
            value = k,
            label = string.format('%s (%s)', v.label, k)
        }
    end
    return items
end

function Utils.GetItemMetadata(item)
    return {{
        label = locale('items.spawn'),
        value = item.name
    }, {
        label = locale('items.weight'),
        value = item.weight
    }, {
        label = locale('items.type'),
        value = item.type or locale('items.notype')
    }}
end

return Utils
