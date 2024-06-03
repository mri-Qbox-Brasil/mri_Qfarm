local FarmZones = {}
local FarmItems = {}

function UpdateFarmZone(key, value)
    FarmZones[key] = value
    GlobalState:set('FarmZonesUpdate', {
        key = key,
        value = value
    }, true)
end

local TestZones = {
    [1] = {
        name = "Farm 1",
        config = {
            start = {
                location = vector3(-1869.88, 2056.65, 135.45),
                width = 0.6,
                length = 0.6
            },
            items = {
                steel = {
                    min = 3,
                    max = 7,
                    randomRoute = false,
                    points = {vector3(-2521.08, 2310.43, 33.22), vector3(-2512.07, 3619.26, 13.84)},
                    animation = {
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
                },
            }
        },
        group = {
            name = "police",
            grade = 0
        }
    }
}

local TestItems = {
    farm_id = 1,
    item = 'plastic',
    item_label = 'Plastic',
    time = 30,
    amount = 1
}

AddEventHandler('onServerResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        if not Config.Debug then
            FarmZones = MySQL.query.await("SELECT * FROM mri_farms", {}) or {}
            FarmItems = MySQL.query.await("SELECT * FROM mri_farm_items", {}) or {}
        else
            FarmZones = TestZones
            FarmItems = TestItems
        end
        GlobalState:set('FarmZones', FarmZones, true)
    end
end)
