fx_version "cerulean"
game "gta5"
lua54 "yes"
use_experimental_fxv2_oal "yes"

description "Responsável por criar e executar as rotas de farm do servidor"
author "MRI QBOX Team"
version "MRIQBOX_VERSION"

ox_lib "locale"

shared_scripts {
    "@ox_lib/init.lua",
    "shared/*.lua"
}

server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "server/*.lua"
}

client_scripts {
    "@PolyZone/client.lua",
    "@PolyZone/BoxZone.lua",
    "client/*.lua"
}

dependencies {
    "qbx_core",
    "PolyZone",
    "ox_lib",
    "oxmysql",
}

files {
    "locales/*.json"
}
