local newFarm = {
    name = nil,
    config = {
        start = {
            location = nil,
            width = nil,
            length = nil
        },
        items = {}
    },
    group = {
        name = nil,
        grade = 0
    }
}

local newAnim = {
    dict = 'amb@prop_human_bum_bin@idle_a',
    anim = 'idle_a',
    inSpeed = 6.0,
    outSpeed = -6.0,
    duration = -1,
    flag = 47,
    rate = 0,
    x = 0,
    y = 0,
    z = 0
}

local newItem = {
    min = nil,
    max = nil,
    randomRoute = false,
    points = {},
    animation = newAnim
}

AddStateBagChangeHandler('FarmsUpdate', 'global', function(bagName, key, data)
    Farms[data.key] = data.value
end)

local function ReloadFarms()
    Farms = GlobalState.Farms or {}
end

local function UpdateFarms()
    -- Aqui iremos chamar a atualização para o servidor
end

local function GetActualPosition(extraText)
    local text = {}
    if extraText then
        table.insert(text, string.format('%s  \n', extraText))
    end
    table.insert(text, locale('actions.choose_location.1'))
    table.insert(text, locale('actions.choose_location.2'))
    local result = Utils.GetPedCoords(table.concat(text))
    if result == 1 then
        return GetEntityCoords(PlayerPedId())
    else
        return result
    end
end

local function Delete(caption, tableObj, key)
    if Utils.ConfirmationDialog(caption) == 'confirm' then
        tableObj[key] = nil
        UpdateFarms()
    end
end

local function DeleteFarm(args)
    Delete(locale('actions.confirmation_description', locale('actions.farm'), Farms[args.key].name), Farms, args.key)
    ManageFarms()
end

local function DeleteItem(args)
    Delete(locale('actions.confirmation_description', locale('actions.item'), Items[args.itemKey].label),
        Farms[args.farmKey].config.items, args.itemKey)
    StepFour({
        key = args.farmKey
    })
end

local function DeletePoint(args)
    Delete(locale('actions.confirmation_description', locale('actions.point'), args.name),
        Farms[args.farmKey].config.items[args.itemKey].points, args.pointKey)

end

local function SaveItem(args)
    local farm = Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]
    if #item.points == 0 then
        lib.notify({
            id = 'SV_ITEM',
            type = 'error',
            description = locale('actions.nopoints')
        })
    else
        lib.notify({
            id = 'SV_ITEM',
            type = 'success',
            description = locale('actions.saved')
        })
    end
    ItemActionMenu(args.farmKey, args.itemKey)
end

local function ChangeFarmLocation(args)
    local location = GetActualPosition()
    if location then
        Farms[args.key].config.start = {
            location = location,
            width = Config.FarmBoxWidth,
            length = Config.FarmBoxLength
        }
        lib.notify({
            type = 'success',
            description = locale('notify.updated')
        })
    end
    ActionMenu(args.key)
end

local function ChangePointLocation(args)
    local location = GetActualPosition()
    if location and location ~= 2 then
        Farms[args.farmKey].config.items[args.itemKey].points[args.pointKey] = location
        lib.notify({
            type = 'success',
            description = locale('notify.updated')
        })
    end
    PointMenu(args)
end

local function TeleportToLocation(args)
    Utils.TpToLoc(Farms[args.key].config.start.location)
    ActionMenu(args.key)
end

local function ChangeLabel(args)
    local input = lib.inputDialog(locale('dialog.change_label', args.value.name), {{
        type = 'input',
        label = 'Novo nome',
        required = true,
        min = 3,
        max = 20
    }})
    if input then
        local newValue = args.value
        newValue.name = input[1]
        Farms[args.key] = newValue
    end
    ActionMenu(args.key)
    lib.notify({
        type = 'sucess',
        description = locale('notify.updated')
    })
end

local function StepOne(title, key)
    local farm = {}
    table.clone(newFarm, farm)
    if key then
        farm = Farms[key]
    end
    local input = lib.inputDialog(title, {{
        type = 'input',
        label = locale('creator.name'),
        description = locale('creator.description_name'),
        placeholder = locale('creator.placeholder_name'),
        default = farm.name,
        required = true
    }, {
        type = 'select',
        label = locale('creator.group'),
        description = locale('creator.description_group'),
        options = Utils.GetBaseGroups(),
        default = farm.group.name,
        required = true,
        searchable = true
    }})

    if input then
        farm.name = input[1]
        farm.group = {
            name = input[2],
            grade = 0
        }
        lib.notify({
            id = 'STEP1',
            type = 'info',
            description = 'Step One'
        })
        if not key then
            key = #Farms + 1
            Farms[key] = farm
        end
        Farms[key] = farm
        return key
    end
end

local function StepTwo(title, key)
    local farm = Farms[key]
    local input = lib.inputDialog(title, {{
        type = 'select',
        label = locale('creator.grade'),
        description = locale('creator.description_grade'),
        options = Utils.GetBaseGroups(true)[farm.group.name].grades,
        default = 0,
        required = true,
        searchable = true
    }})
    if input then
        farm.group.grade = input[1]
        lib.notify({
            id = 'STEP2',
            type = 'info',
            description = 'Step Two'
        })
        Farms[key] = farm
        return true
    end
end

local function ItemStepOne(title, key, item)
    local input = lib.inputDialog(title, {{
        type = 'select',
        label = locale('items.name'),
        description = locale('items.description_name'),
        default = key,
        options = Utils.GetBaseItems(),
        required = true,
        searchable = true
    }, {
        type = 'number',
        label = locale('items.min'),
        description = locale('items.description_min'),
        default = item.min or 0,
        required = true
    }, {
        type = 'number',
        label = locale('items.max'),
        description = locale('items.description_max'),
        default = item.max or 1,
        required = true
    }, {
        type = 'checkbox',
        label = locale('items.random'),
        description = locale('items.description_random'),
        default = item.randomRoute
    }})

    if input then
        lib.notify({
            id = 'STEP1',
            type = 'info',
            description = 'Item Step One'
        })
        item.name = input[1]
        item.min = input[2]
        item.max = input[3]
        item.randomRoute = input[4] or false
        return true, item
    end
end

local function ItemStepTwo(item)
    local input = lib.inputDialog(locale('items.animation'), {{
        type = 'input',
        label = locale('anim.dict'),
        default = item.animation.dict or 'amb@prop_human_bum_bin@idle_a',
        required = true
    }, {
        type = 'input',
        label = locale('anim.anim'),
        default = item.animation.anim or 'idle_a',
        required = true
    }, {
        type = 'number',
        label = locale('anim.inspeed'),
        default = item.animation.inSpeed or 6.0,
        required = true
    }, {
        type = 'number',
        label = locale('anim.outspeed'),
        default = item.animation.outSpeed or -6.0,
        required = true
    }, {
        type = 'number',
        label = locale('anim.duration'),
        default = item.animation.duration or -1,
        required = true
    }, {
        type = 'number',
        label = locale('anim.flag'),
        default = item.animation.flag or 47,
        required = true
    }, {
        type = 'number',
        label = locale('anim.rate'),
        default = item.animation.rate or 0,
        required = true
    }, {
        type = 'number',
        label = locale('anim.x'),
        default = item.animation.x or 0,
        required = true
    }, {
        type = 'number',
        label = locale('anim.y'),
        default = item.animation.y or 0,
        required = true
    }, {
        type = 'number',
        label = locale('anim.z'),
        default = item.animation.z or 0,
        required = true
    }})
    if input then
        lib.notify({
            id = 'STEP2',
            type = 'info',
            description = 'Item Step Two'
        })
        local _anim = item.animation or {}
        _anim.dict = input[1]
        _anim.anim = input[2]
        _anim.inSpeed = input[3]
        _anim.outSpeed = input[4]
        _anim.duration = input[5]
        _anim.flag = input[6]
        _anim.rate = input[7]
        _anim.x = input[8]
        _anim.y = input[9]
        _anim.z = input[10] or false
        item.animation = _anim
        return true, item
    end
end

local function CreateItemSteps(text, farmKey, item, itemKey)
    local _item = item
    if itemKey then
        _item = Farms[farmKey].config.items[itemKey]
    end
    local result, _item = ItemStepOne(text, itemKey, _item)
    if not result then
        return
    end
    result, _item = ItemStepTwo(_item)
    if not result then
        return
    end
    local new = false
    if not itemKey then
        new = true
        itemKey = _item.name
        _item.name = nil
        Farms[farmKey].config.items[itemKey] = _item
    end
    ItemActionMenu(farmKey, itemKey, new)
end

local function CreateItem(args)
    local item = {}
    table.clone(newItem, item)
    local text = locale('menus.new_item')
    if args and args.itemKey then
        local farm = Farms[args.farmKey]
        newItem = farm.config.items[args.itemKey]
        text = locale('menus.edit_item', args.itemKey)
    end
    CreateItemSteps(text, args.farmKey, newItem, args.itemKey)
end

function PointMenu(args)
    local ctx = {
        id = 'point_item',
        menu = 'list_points',
        title = args.name,
        options = {{
            title = locale('actions.delete'),
            icon = 'trash',
            iconColor = ColorScheme.danger,
            onSelect = DeletePoint,
            args = {
                farmKey = args.farmKey,
                itemKey = args.itemKey,
                pointKey = args.pointKey,
                name = args.name
            }
        }, {
            title = locale('actions.change_location'),
            icon = 'location-dot',
            onSelect = ChangePointLocation,
            args = {
                farmKey = args.farmKey,
                itemKey = args.itemKey,
                pointKey = args.pointKey,
                name = args.name
            }
        }, {
            title = locale('actions.teleport'),
            icon = 'location-dot',
            onSelect = TeleportToLocation,
            args = {
                farmKey = args.farmKey,
                itemKey = args.itemKey,
                pointKey = args.pointKey
            }
        }}
    }
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

local function AddPoints(args)
    local keepLoop = true
    local farm = Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]
    while keepLoop do
        Wait(0)
        local result = GetActualPosition(locale('actions.choose_location.3'))
        keepLoop = result ~= 2
        if result ~= 2 then
            item.points[#item.points + 1] = GetEntityCoords(PlayerPedId())
        end
    end
    Farms[args.farmKey].config.items[args.itemKey] = item
    ItemActionMenu(args.farmKey, args.itemKey)
end

local function ListPoints(args)
    local ctx = {
        id = 'list_points',
        menu = 'action_item',
        title = locale('menus.points', Items[args.itemKey].label),
        options = {{
            title = locale('actions.add_point'),
            description = locale('actions.description_add_point'),
            icon = 'square-plus',
            iconAnimation = 'fade',
            arrow = true,
            onSelect = AddPoints,
            args = {
                farmKey = args.farmKey,
                itemKey = args.itemKey
            }
        }}
    }
    local farm = Farms[args.farmKey]
    local item = farm.config.items[args.itemKey]
    for k, v in pairs(item.points) do
        ctx.options[#ctx.options + 1] = {
            title = Utils.GetLocationFormatted(v, k),
            description = string.format('X: %.2f, Y: %.2f, Z: %.2f', v.x, v.y, v.z),
            icon = 'map-pin',
            onSelect = PointMenu,
            args = {
                farmKey = args.farmKey,
                itemKey = args.itemKey,
                pointKey = k,
                name = Utils.GetLocationFormatted(v, k)
            }
        }
    end
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

function ItemActionMenu(farmKey, itemKey, new)
    local farm = Farms[farmKey]
    local items = farm.config.items[itemKey]
    local ctx = {
        id = 'action_item',
        title = Items[itemKey].label,
        menu = 'items_farm',
        options = {{
            title = locale('actions.edit_item'),
            icon = 'file-pen',
            onSelect = CreateItem,
            args = {
                farmKey = farmKey,
                itemKey = itemKey
            }
        }, {
            title = locale('actions.delete'),
            icon = 'trash',
            iconColor = ColorScheme.danger,
            onSelect = DeleteItem,
            args = {
                farmKey = farmKey,
                itemKey = itemKey
            }
        }, {
            title = locale('actions.points'),
            icon = 'location-crosshairs',
            onSelect = ListPoints,
            args = {
                farmKey = farmKey,
                itemKey = itemKey
            }
        }}
    }

    if new then
        ctx.options[#ctx.options + 1] = {
            title = locale('actions.save'),
            icon = 'floppy-disk',
            onSelect = SaveItem,
            args = {
                farmKey = farmKey,
                itemKey = itemKey
            }
        }
    end

    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

local function StepThree(key)
    local farm = Farms[key]
    local text = {locale('actions.choose_location.1'), locale('actions.choose_location.2')}
    if Utils.GetPedCoords(table.concat(text)) == 1 then
        local location = GetEntityCoords(PlayerPedId())
        lib.notify({
            id = 'STEP3',
            type = 'info',
            description = 'Step Three'
        })
        farm.config.start = {
            location = location,
            width = Config.FarmBoxWidth,
            length = Config.FarmBoxLength
        }
        Farms[key] = farm
        return true
    end
end

function StepFour(args)
    local farm = Farms[args.key] or newFarm
    local ctx = {
        id = 'items_farm',
        title = locale('menus.items'),
        menu = 'action_farm',
        description = farm.name,
        options = {{
            title = 'Adicionar item',
            description = 'Adicionar item para criar a rota',
            icon = 'square-plus',
            iconAnimation = 'fade',
            arrow = true,
            onSelect = CreateItem,
            args = {
                farmKey = args.key
            }
        }, {
            title = 'Continuar',
            description = 'Tudo pronto? Próximo passo!',
            icon = 'square-check',
            iconAnimation = 'fade',
            arrow = true,
            onSelect = function()
                ExecuteCommand('createfarm')
            end
        }}
    }
    for k, v in pairs(farm.config.items) do
        ctx.options[#ctx.options + 1] = {
            title = Items[k].label,
            icon = string.format('%s/%s.png', ImageURL, Items[k].name),
            image = string.format('%s/%s.png', ImageURL, Items[k].name),
            metadata = Utils.GetItemMetadata(Items[k]),
            description = Items[k].description,
            onSelect = function()
                ItemActionMenu(args.key, k)
            end
        }
    end
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
    lib.notify({
        id = 'STEP4',
        type = 'info',
        description = 'Step Four'
    })
    return true
end

local function CreateSteps(title, key)
    local _key = StepOne(title, key)
    if not _key then
        ManageFarms()
        return
    end
    if not StepTwo(title, _key) then
        return
    end
    if not key then
        if not StepThree(_key) then
            return
        end
        StepFour({
            key = _key
        }) -- isso é um menu e funciona diferente
    else
        ActionMenu(key)
    end
end

local function CreateFarm(args)
    local key = false
    local dialogText = locale('creator.new_farm')
    if args and args.key then
        local farm = Farms[args.key]
        dialogText = locale('creator.edit_farm', farm.name)
        key = args.key
    end
    CreateSteps(dialogText, key)
end

function ActionMenu(key)
    local farm = Farms[key]
    local ctx = {
        id = 'action_farm',
        title = farm.name:upper(),
        menu = 'menu_farm',
        options = {{
            title = locale('actions.edit'),
            icon = 'file-pen',
            onSelect = CreateFarm,
            args = {
                key = key
            }
        }, {
            title = locale('actions.items'),
            icon = 'rectangle-list',
            onSelect = StepFour,
            args = {
                key = key
            }
        }, {
            title = locale('actions.delete'),
            icon = 'trash',
            iconColor = ColorScheme.danger,
            onSelect = DeleteFarm,
            args = {
                key = key
            }
        }, {
            title = locale('actions.change_location'),
            icon = 'location-dot',
            onSelect = ChangeFarmLocation,
            args = {
                key = key
            }
        }, {
            title = locale('actions.teleport'),
            icon = 'location-dot',
            onSelect = TeleportToLocation,
            args = {
                key = key
            }
        }, {
            title = locale('actions.change_label', farm.name),
            icon = 'pen-to-square',
            onSelect = ChangeLabel,
            args = {
                key = key
            }
        }}
    }
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

local function GetMetadataFromFarm(key)
    local data = {}
    local items = Farms[key].config.items
    for k, v in pairs(items) do
        data[#data + 1] = {
            label = locale('menus.route'),
            value = string.format('%s (%s)', Items[k].label, k)
        }
    end
    return data
end

function ManageFarms()
    Items = exports.ox_inventory:Items()
    local ctx = {
        id = 'menu_farm',
        menu = 'menu_gerencial',
        title = 'Farm',
        options = {{
            title = 'Criar novo farm',
            description = 'Crie um Farm novo.',
            icon = 'square-plus',
            iconAnimation = 'fade',
            arrow = true,
            onSelect = CreateFarm
        }}
    }
    for k, v in pairs(Farms) do
        local groupName = Utils.GetBaseGroups(true)[v.group.name].label
        local description = locale('menus.description_farm', groupName)
        ctx.options[#ctx.options + 1] = {
            title = v.name:upper(),
            icon = 'warehouse',
            description = description,
            metadata = GetMetadataFromFarm(k),
            onSelect = function()
                ActionMenu(k)
            end
        }
    end
    lib.registerContext(ctx)
    lib.showContext(ctx.id)
end

RegisterNetEvent('mri_qfarm:Client:ManageFarms', function()
    ManageFarms()
end)
