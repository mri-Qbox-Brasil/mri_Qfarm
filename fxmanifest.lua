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
    "@qbx_core/modules/playerdata.lua",
    "shared/*.lua"
}

server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "server/**/*.lua"
}

client_scripts {
    "client/**/*.lua"
}

dependencies {
    "qbx_core",
}

files {
    "locales/*.json"
}
