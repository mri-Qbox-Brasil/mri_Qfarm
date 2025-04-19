local Farms = GlobalState.Farms or {}
local ColorScheme = GlobalState.UIColors

local blip = {
    coords = {
        x = 0,
        y = 0,
        z = 0
    },
    sprite = 465,
    color = 5,
    scale = 1.0,
    shortRange = false,
    route = true,
    text = locale("misc.farm_point")
}

local marker = {
    type = 2,
    coords = {
        x = 0,
        y = 0,
        z = 0
    },
    direction = {
        x = 0,
        y = 0,
        z = 0
    },
    rotation = {
        x = 0,
        y = 0,
        z = 0
    },
    color = {
        r = 255,
        g = 255,
        b = 0,
        a = 255
    },
    scale = {
        x = 0.3,
        y = 0.3,
        z = 0.3
    },
    bobUpAndDown = false,
    faceCamera = false,
    rotationOrder = 2,
    rotate = false,
    textureDict = nil,
    textureName = nil,
    drawOnEnts = false,
}

local animCmd = "bumbin"

local anim = {
    dict = "amb@prop_human_bum_bin@idle_a",
    anim = "idle_a",
    inSpeed = 6.0,
    outSpeed = -6.0,
    duration = 2000,
    flag = 1,
    rate = 0,
    x = 0,
    y = 0,
    z = 0
}

local collectTime = 7000

local function new(item)
    return json.decode(json.encode(item))
end

return {
    Blip = blip,
    Marker = marker,
    AnimCmd = animCmd,
    Anim = anim,
    CollectTime = collectTime,
    Farms = Farms,
    ColorScheme = ColorScheme,
    New = new,
}
