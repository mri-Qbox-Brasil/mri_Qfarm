-- Farm AFK, sem rotas, parado no mesmo lugar
local ImageURL = "https://cfx-nui-ox_inventory/web/images"

local Config = require("shared/config")
local Utils = lib.require("shared/utils")
local Defaults = require("client/defaults")
local Blips = lib.require("client/interaction/blips")
local Markers = lib.require("client/interaction/markers")
local Text = lib.require("client/interaction/texts")
local Targets = lib.require("client/interaction/targets")
local Zones = lib.require("client/interaction/zones")

local Farms = {}
