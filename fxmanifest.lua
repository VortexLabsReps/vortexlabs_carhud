fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vortexlabs_carhud'
author 'VortexLabs'
description 'VortexLabs Car HUD: speedometer, telemetry, seatbelt, lights, cruise control, engine, nitro and location'
version '1.0.0'

-- No required dependencies: standalone, ESX, QBCore and Qbox are detected automatically.

shared_scripts {
    'config.lua',
    'shared/utils.lua',
    'shared/locale.lua',
    'shared/profiles.lua',
    'shared/crash.lua',
    'shared/settings.lua',
    'shared/admin.lua',
    'shared/geo.lua',
}

client_scripts {
    'bridge/client/framework.lua',
    'bridge/client/fuel.lua',
    'client/core.lua',
    'client/nui.lua',
    'client/admin.lua',
    'client/perf.lua',
    'client/settings.lua',
    'client/telemetry.lua',
    'client/location.lua',
    'client/seatbelt.lua',
    'client/lights.lua',
    'client/cruise.lua',
    'client/engine.lua',
    'client/nitro.lua',
    'client/keys.lua',
    'client/main.lua',
}

server_scripts {
    'bridge/server/framework.lua',
    'server/admin.lua',
    'server/nitro_store.lua',
    'server/nitro.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/app.js',
    'html/app.css',
    'html/vortexlabs-logo.png',
    'html/sounds/*.wav',
    'locales/*.json',
}
